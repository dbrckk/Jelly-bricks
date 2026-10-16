extends Node3D
## Separate, playable 3D candy-brick stacking studio.
## Godot 4.6 Compatibility: authored gel meshes, no paid assets, no GPU physics.
## A deterministic support rule makes stacks stable and undoable on Android.
const GEL = preload("res://scripts/gel_mesh.gd")
const SHADER = preload("res://shaders/jelly.gdshader")
const SAVE_PATH := "user://jelly-stack-v1.json"
const GRID := 6
const STEP := .74
const MAX_LAYERS := 9
const MAX_BRICKS := 32
const COLORS := ["#f44668", "#286cf1", "#34c768", "#ffcb51", "#f8904d"]
const LENGTHS := [1, 2, 3]

var host # Root game script; dynamic access to its puzzle/audio API
var active: bool = false
var bricks: Array[Dictionary] = []
var occupancy: Dictionary = {}
var selected_color: int = 1
var selected_length: int = 1
var selected_turns: int = 0
var selected_cell: Vector2i = Vector2i(2, 1)
var preview_node: Node3D
var preview_target: Vector3
var scene_root: Node3D
var mesh_cache: Dictionary = {}
var hud: CanvasLayer
var top_controls: VBoxContainer
var bottom_controls: VBoxContainer
var title_label: Label
var status_label: Label
var color_buttons: Array[Button] = []
var length_buttons: Array[Button] = []
var active_touch_index: int = -1
var mouse_held: bool = false
var reset_confirmation: ConfirmationDialog

func _ready() -> void:
    name = "FreeStackStudio"
    _build_scene()
    _build_hud()
    _restore_or_seed()
    _rebuild()
    set_active(false)

func set_active(enabled: bool) -> void:
    active = enabled
    visible = enabled
    hud.visible = enabled
    if enabled:
        _refresh_preview()
        _refresh_labels()
    else:
        active_touch_index = -1
        mouse_held = false

func _process(delta: float) -> void:
    if not active or preview_node == null or not preview_node.visible:
        return
    var t: float = 1.0 - exp(-minf(delta, .1) * 20.0)
    preview_node.position = preview_node.position.lerp(preview_target, t)

func _build_scene() -> void:
    scene_root = Node3D.new()
    scene_root.name = "CandyStackStage"
    add_child(scene_root)
    var plinth := MeshInstance3D.new()
    plinth.name = "SatinPlinth"
    # Full square footprint beneath the 6x6 authored stacking area;
    # previous cylindrical plinth left permitted corner cells floating.
    var geometry := BoxMesh.new()
    geometry.size = Vector3(6.24, .16, 6.24)
    plinth.mesh = geometry
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#f2f3f6")
    material.roughness = .75
    material.metallic = .0
    plinth.material_override = material
    plinth.position.y = -.38
    scene_root.add_child(plinth)

func _make_button(text_value: String, tint: Color) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(84, 56)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", Color.WHITE)
    var style := StyleBoxFlat.new()
    style.bg_color = tint
    style.set_corner_radius_all(16)
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    button.add_theme_stylebox_override("normal", style)
    var pressed_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
    pressed_style.bg_color = tint.darkened(.18)
    button.add_theme_stylebox_override("pressed", pressed_style)
    return button

func _make_label(value: String, size_px: int, tint: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size_px)
    label.add_theme_color_override("font_color", tint)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return label

func _build_hud() -> void:
    hud = CanvasLayer.new()
    hud.layer = 8
    add_child(hud)
    var surface := Control.new()
    surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(surface)

    top_controls = VBoxContainer.new()
    top_controls.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top_controls.offset_left = 20
    top_controls.offset_right = -20
    top_controls.offset_top = 26
    top_controls.offset_bottom = 190
    top_controls.add_theme_constant_override("separation", 9)
    surface.add_child(top_controls)

    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", 12)
    top_controls.add_child(nav)
    var back := _make_button("‹ Puzzles", Color("#465a72"))
    back.pressed.connect(func(): host._leave_stack_mode())
    nav.add_child(back)
    var heading := _make_label("J E L L Y   S T U D I O", 23, Color("#34465e"))
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nav.add_child(heading)
    title_label = _make_label("Empilage libre", 19, Color("#4b6178"))
    top_controls.add_child(title_label)

    bottom_controls = VBoxContainer.new()
    bottom_controls.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_controls.offset_left = 18
    bottom_controls.offset_right = -18
    bottom_controls.offset_bottom = -22
    bottom_controls.offset_top = -320
    bottom_controls.add_theme_constant_override("separation", 8)
    surface.add_child(bottom_controls)
    status_label = _make_label("Glisse la brique, relâche pour poser", 18, Color("#486178"))
    bottom_controls.add_child(status_label)

    var colors_row := HBoxContainer.new()
    colors_row.alignment = BoxContainer.ALIGNMENT_CENTER
    colors_row.add_theme_constant_override("separation", 10)
    bottom_controls.add_child(colors_row)
    for idx in range(COLORS.size()):
        var color_button := _make_button("●", Color(COLORS[idx]))
        color_button.custom_minimum_size = Vector2(62, 48)
        color_button.add_theme_font_size_override("font_size", 25)
        color_button.pressed.connect(_choose_color.bind(idx))
        colors_row.add_child(color_button)
        color_buttons.append(color_button)

    var length_row := HBoxContainer.new()
    length_row.add_theme_constant_override("separation", 8)
    bottom_controls.add_child(length_row)
    for idx in range(LENGTHS.size()):
        var length_button := _make_button(
            ["Petit", "Moyen", "Long"][idx], Color("#637b94"))
        length_button.custom_minimum_size.y = 45
        length_button.pressed.connect(_choose_length.bind(idx))
        length_row.add_child(length_button)
        length_buttons.append(length_button)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    bottom_controls.add_child(actions)
    var rotate := _make_button("↻ Tourner", Color("#66569a"))
    rotate.pressed.connect(_rotate)
    actions.add_child(rotate)
    var drop := _make_button("↓ Poser", Color("#248c81"))
    drop.pressed.connect(_commit)
    actions.add_child(drop)
    var undo := _make_button("↶ Annuler", Color("#516b83"))
    undo.pressed.connect(_undo)
    actions.add_child(undo)
    var reset := _make_button("Effacer", Color("#9e5666"))
    reset.pressed.connect(func(): reset_confirmation.popup_centered())
    actions.add_child(reset)

    reset_confirmation = ConfirmationDialog.new()
    reset_confirmation.title = "Réinitialiser l'atelier ?"
    reset_confirmation.dialog_text = "Cela effacera toutes les briques de l'atelier.\nLes 21 puzzles ne seront pas affectés."
    reset_confirmation.ok_button_text = "Effacer"
    reset_confirmation.confirmed.connect(_reset)
    add_child(reset_confirmation)
    _update_selection()

func _update_selection() -> void:
    for idx in range(color_buttons.size()):
        color_buttons[idx].text = "✓" if idx == selected_color else "●"
    for idx in range(length_buttons.size()):
        length_buttons[idx].modulate = Color.WHITE if idx == selected_length else Color("#bdc8d5")

func _choose_color(idx: int) -> void:
    selected_color = clampi(idx, 0, COLORS.size() - 1)
    _update_selection()
    _refresh_preview()
    host._play_feedback("select")

func _choose_length(idx: int) -> void:
    selected_length = clampi(idx, 0, LENGTHS.size() - 1)
    _update_selection()
    _refresh_preview()
    host._play_feedback("select")

func _rotate() -> void:
    selected_turns = (selected_turns + 1) % 4
    _refresh_preview()
    host._play_feedback("rotate", 9)

func _shape_cells(length_index: int, turns: int) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    var length: int = LENGTHS[clampi(length_index, 0, LENGTHS.size() - 1)]
    for i in range(length):
        if posmod(turns, 2) == 0:
            result.append(Vector2i(0, i))
        else:
            result.append(Vector2i(i, 0))
    return result

func _occupied_cells(entry: Dictionary) -> Array[Vector2i]:
    var footprint: Array[Vector2i] = []
    for offset in _shape_cells(int(entry["length"]), int(entry["turns"])):
        footprint.append(Vector2i(int(entry["row"]), int(entry["col"])) + offset)
    return footprint

func _rebuild_occupancy() -> void:
    occupancy.clear()
    for entry in bricks:
        for pos in _occupied_cells(entry):
            occupancy[Vector3i(pos.x, pos.y, int(entry["layer"]))] = true

## Deterministic stack height. At least half of the footprint must be
## supported by the layer below: shorter blocks can rest on longer blocks.
func _drop_candidate(row: int, col: int, length_index: int, turns: int) -> Dictionary:
    var offsets := _shape_cells(length_index, turns)
    var world_cells: Array[Vector2i] = []
    var layer := 0
    for offset in offsets:
        var pos := Vector2i(row, col) + offset
        if pos.x < 0 or pos.y < 0 or pos.x >= GRID or pos.y >= GRID:
            return {"ok": false, "reason": "Hors du socle"}
        world_cells.append(pos)
        for existing_layer in range(MAX_LAYERS):
            if occupancy.has(Vector3i(pos.x, pos.y, existing_layer)):
                layer = maxi(layer, existing_layer + 1)
    if layer >= MAX_LAYERS:
        return {"ok": false, "reason": "Pile trop haute"}
    if layer > 0:
        var support := 0
        for pos in world_cells:
            if occupancy.has(Vector3i(pos.x, pos.y, layer - 1)):
                support += 1
        if support < ceili(float(world_cells.size()) * .5):
            return {"ok": false, "reason": "Appui insuffisant"}
    return {"ok": true, "layer": layer}

func _entry(row: int, col: int, length_index: int,
        turns: int, color_idx: int, layer: int) -> Dictionary:
    return {"row": row, "col": col, "length": length_index,
        "turns": turns, "color": color_idx, "layer": layer}

func _build_piece(entry: Dictionary, translucent: bool) -> Node3D:
    var root_piece := Node3D.new()
    root_piece.name = "StudioBrick"
    var length_index: int = int(entry["length"])
    var turns: int = int(entry["turns"])
    var color_idx: int = int(entry["color"])
    var cells := _shape_cells(length_index, turns)
    var mesh_key := str(length_index) + ":" + str(posmod(turns, 2))
    if not mesh_cache.has(mesh_key):
        mesh_cache[mesh_key] = GEL.build(cells)
    var material := ShaderMaterial.new()
    material.shader = SHADER
    material.set_shader_parameter("candy_tint", Color(COLORS[color_idx]))
    material.set_shader_parameter("gel_opacity", .43 if translucent else .97)
    material.set_shader_parameter("sheen", .18 if translucent else .51)
    var body := MeshInstance3D.new()
    body.name = "GelBody"
    body.mesh = mesh_cache[mesh_key]
    body.material_override = material
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root_piece.add_child(body)

    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = host.stud_mesh
    instances.instance_count = cells.size() * 4
    var idx := 0
    for cell in cells:
        for dx in [-.235, .235]:
            for dz in [-.235, .235]:
                instances.set_instance_transform(idx,
                    Transform3D(Basis.IDENTITY, Vector3(
                        float(cell.y) + .5 + dx, 0.0,
                        float(cell.x) + .5 + dz)))
                idx += 1
    var studs := MultiMeshInstance3D.new()
    studs.name = "GelStuds"
    studs.multimesh = instances
    studs.material_override = material
    studs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root_piece.add_child(studs)
    return root_piece

func _world_position(entry: Dictionary) -> Vector3:
    return Vector3(float(entry["col"]) - float(GRID) * .5,
        .10 + float(entry["layer"]) * STEP,
        float(entry["row"]) - float(GRID) * .5)

func _rebuild() -> void:
    for child in scene_root.get_children():
        if child.name == "StudioBrick":
            scene_root.remove_child(child)
            child.queue_free()
    _rebuild_occupancy()
    for entry in bricks:
        var piece := _build_piece(entry, false)
        piece.position = _world_position(entry)
        scene_root.add_child(piece)
    _refresh_preview()
    _refresh_labels()

func _refresh_preview() -> void:
    if preview_node != null:
        remove_child(preview_node)
        preview_node.queue_free()
        preview_node = null
    if not active:
        return
    var result := _drop_candidate(selected_cell.x, selected_cell.y,
        selected_length, selected_turns)
    var entry := _entry(selected_cell.x, selected_cell.y,
        selected_length, selected_turns, selected_color,
        int(result.get("layer", 0)))
    preview_node = _build_piece(entry, true)
    preview_node.name = "StudioPreview"
    if not result.get("ok", false):
        var paint: ShaderMaterial = preview_node.get_node("GelBody").material_override
        paint.set_shader_parameter("candy_tint", Color("#ff6f88"))
    add_child(preview_node)
    preview_target = _world_position(entry) + Vector3(0, .14, 0)
    preview_node.position = preview_target
    preview_node.visible = true
    _refresh_labels()

func _refresh_labels(message: String = "") -> void:
    if title_label != null:
        var height := 0
        for entry in bricks:
            height = maxi(height, int(entry["layer"]) + 1)
        title_label.text = "%d briques    ·    %d niveaux de hauteur" % [bricks.size(), height]
    if status_label == null:
        return
    if not message.is_empty():
        status_label.text = message
    else:
        var candidate := _drop_candidate(selected_cell.x, selected_cell.y,
            selected_length, selected_turns)
        status_label.text = "Glisse pour empiler · relâche pour poser" if \
            candidate.get("ok", false) else String(candidate.get("reason", ""))

func _commit() -> void:
    if bricks.size() >= MAX_BRICKS:
        _refresh_labels("Atelier plein (32 briques)")
        host._play_feedback("reject", 10)
        return
    var candidate := _drop_candidate(selected_cell.x, selected_cell.y,
        selected_length, selected_turns)
    if not candidate.get("ok", false):
        _refresh_labels(String(candidate.get("reason", "Pose impossible")))
        host._play_feedback("reject", 10)
        return
    var entry := _entry(selected_cell.x, selected_cell.y, selected_length,
        selected_turns, selected_color, int(candidate["layer"]))
    bricks.append(entry)
    _rebuild_occupancy()
    # Keep existing pieces and animate only the new brick. Rebuild only
    # on undo/reload; no frame-by-frame creation while dragging.
    var node := _build_piece(entry, false)
    node.position = _world_position(entry) + Vector3(0, .85, 0)
    scene_root.add_child(node)
    var settle := create_tween()
    settle.set_parallel(true)
    settle.tween_property(node, "position", _world_position(entry), .52) \
        .set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
    node.scale = Vector3(.96, 1.16, .96)
    node.rotation.z = .075
    settle.tween_property(node, "scale", Vector3.ONE, .67) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    settle.tween_property(node, "rotation", Vector3.ZERO, .76) \
        .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
    host._play_feedback("place", 23)
    _save()
    _refresh_preview()
    _refresh_labels("Brique posée · continue la pile")

func _undo() -> void:
    if bricks.is_empty():
        return
    bricks.pop_back()
    _rebuild()
    _save()
    host._play_feedback("undo", 9)
    _refresh_labels("Dernière brique retirée")

func _reset() -> void:
    bricks.clear()
    _rebuild()
    _save()
    _refresh_labels("Atelier vide · commence une nouvelle pile")

func _load_entries(raw: Variant) -> bool:
    if not raw is Array or raw.size() > MAX_BRICKS:
        return false
    var verified: Array[Dictionary] = []
    bricks.clear()
    occupancy.clear()
    for item in raw:
        if not item is Dictionary:
            bricks.clear()
            occupancy.clear()
            return false
        for field in ["row", "col", "length", "turns", "color", "layer"]:
            if not item.has(field) or not (item[field] is int):
                bricks.clear()
                occupancy.clear()
                return false
        if item["length"] < 0 or item["length"] >= LENGTHS.size() \
                or item["turns"] < 0 or item["turns"] > 3 \
                or item["color"] < 0 or item["color"] >= COLORS.size():
            bricks.clear()
            occupancy.clear()
            return false
        var pose := _drop_candidate(item["row"], item["col"],
            item["length"], item["turns"])
        if not pose.get("ok", false) or pose["layer"] != item["layer"]:
            bricks.clear()
            occupancy.clear()
            return false
        verified.append(item.duplicate(true))
        bricks.append(item.duplicate(true))
        _rebuild_occupancy()
    bricks = verified
    return true

func _restore_or_seed() -> void:
    # Recover an interrupted/corrupted primary file using the last verified
    # generation before falling back to the authored starter sculpture.
    for source in [SAVE_PATH, SAVE_PATH + ".bak"]:
        if not FileAccess.file_exists(source):
            continue
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
        if raw is Dictionary and raw.get("schema", -1) == 1 \
                and _load_entries(raw.get("bricks", [])):
            return
    _seed_showcase()

## Starter pile: multiple heights and loose colorful bricks introduce the
## core interaction immediately. Reset still creates a completely blank stage.
func _seed_showcase() -> void:
    bricks.clear()
    occupancy.clear()
    var sample: Array = [
        [2, 1, 2, 0, 0], # Long coral base
        [3, 1, 1, 0, 2], # Green brick beside it
        [1, 3, 0, 0, 4], # Orange loose brick
        [2, 2, 0, 0, 3], # Short amber brick supported by the base
        [2, 1, 1, 0, 1], # Blue bridge above the amber
        [2, 1, 0, 0, 0]  # Coral cap on the bridge
    ]
    for spec in sample:
        var candidate := _drop_candidate(spec[0], spec[1],
            spec[2], spec[3])
        if not candidate.get("ok", false):
            push_error("Starter showcase has invalid structural support")
            bricks.clear()
            occupancy.clear()
            return
        bricks.append(_entry(spec[0], spec[1], spec[2],
            spec[3], spec[4], int(candidate["layer"])))
        _rebuild_occupancy()

func _save() -> void:
    var temporary := SAVE_PATH + ".tmp"
    var f := FileAccess.open(temporary, FileAccess.WRITE)
    if f == null:
        push_warning("Cannot stage studio stack progress")
        return
    f.store_string(JSON.stringify({"schema": 1, "bricks": bricks}))
    f.flush()
    f.close()
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
    if DirAccess.rename_absolute(temporary, SAVE_PATH) != OK:
        push_warning("Could not commit studio stack progress")

func _usable_area(screen: Vector2) -> bool:
    var viewport := get_viewport().get_visible_rect().size
    return screen.x >= 0 and screen.y >= 0 \
        and screen.x <= viewport.x and screen.y <= viewport.y \
        and screen.y > top_controls.get_global_rect().end.y + 8.0 \
        and screen.y < bottom_controls.get_global_rect().position.y - 8.0

func _point_to_cell(screen: Vector2) -> Vector2i:
    var origin: Vector3 = host.camera.project_ray_origin(screen)
    var direction: Vector3 = host.camera.project_ray_normal(screen)
    if absf(direction.y) < .001:
        return Vector2i(-1, -1)
    var t: float = -origin.y / direction.y
    if t < 0:
        return Vector2i(-1, -1)
    var hit := origin + direction * t
    return Vector2i(int(floor(hit.z + float(GRID) * .5)),
        int(floor(hit.x + float(GRID) * .5)))

func _track(screen: Vector2, commit: bool) -> void:
    if not _usable_area(screen):
        return
    var hit := _point_to_cell(screen)
    if hit.x < 0 or hit.y < 0 or hit.x >= GRID or hit.y >= GRID:
        return
    if hit != selected_cell:
        selected_cell = hit
        _refresh_preview()
    if commit:
        _commit()

func handle_input(event: InputEvent) -> void:
    if not active:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if active_touch_index == -1 and _usable_area(event.position):
                active_touch_index = event.index
                _track(event.position, false)
        elif event.index == active_touch_index:
            if not event.canceled:
                _track(event.position, true)
            active_touch_index = -1
    elif event is InputEventScreenDrag and event.index == active_touch_index:
        _track(event.position, false)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            mouse_held = _usable_area(event.position) and active_touch_index == -1
            if mouse_held:
                _track(event.position, false)
        else:
            if mouse_held and active_touch_index == -1:
                _track(event.position, true)
            mouse_held = false
    elif event is InputEventMouseMotion and mouse_held and active_touch_index == -1:
        _track(event.position, false)
