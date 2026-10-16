extends Node3D
## Native Android 3D rebuild of Jelly Bricks. Built for Godot 4.6 Compatibility.
## No external asset, CDN, account, purchase, Unity editor or service needed.

const PALETTE := {
    "A": "#ff537f", "B": "#50acff", "C": "#51e9c2",
    "D": "#ffcd60", "E": "#aa84ff", "F": "#ff87d1",
    "G": "#ffa360", "H": "#55dedb", "I": "#98c6ff",
    "J": "#c787f8", "K": "#f87567"
}
const GEL_SHADER = preload("res://shaders/jelly.gdshader")
const SAVE_FILE := "user://jelly-native-progress.json"

var levels: Array = []
var current_level: int = 0
var unlocked: int = 0
var pieces: Dictionary = {}
var placements: Dictionary = {}
var selected_id: String = ""
var selected_turns: int = 0
var size: int = 4
var occupied: Dictionary = {}
var wanted: Dictionary = {}
var moves: int = 0
var completed: bool = false

var camera: Camera3D
var board: Node3D
var ghost: Node3D
var background: ColorRect
var model_grid: GridContainer
var model_title: Label
var stage_label: Label
var status_label: Label
var moves_label: Label
var select_label: Label
var tray: HBoxContainer
var overlay: Control
var undo_button: Button
var next_button: Button
var toast_tween: Tween
var last_placement: Dictionary = {}
var has_undo_snapshot: bool = false
var touch_started_on_board: bool = false
var mouse_started_on_board: bool = false
var shape_mesh_cache: Dictionary = {}

func _ready() -> void:
    _read_levels()
    _build_environment()
    _build_interface()
    _load_progress()
    _open_level(current_level)

func _read_levels() -> void:
    var data = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/levels.json"))
    if not data is Dictionary or not data.has("levels"):
        push_error("Impossible de lire les niveaux Jelly Bricks.")
        return
    levels = data["levels"]

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#101a38")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#90a4e8")
    env.ambient_light_energy = 0.85
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)

    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.current = true
    add_child(camera)

    _add_directional(Color("#fff2e8"), 1.8, Vector3(-4.0, 9.0, 5.0))
    _add_directional(Color("#73d7ff"), 0.9, Vector3(5.0, 5.0, -3.5))
    _add_omni(Color("#ffa8d7"), 1.15, Vector3(-3.0, 3.0, -1.5))
    _add_omni(Color("#9ceeff"), 1.05, Vector3(3.5, 4.0, 2.0))

    board = Node3D.new()
    board.name = "JellyBoard"
    add_child(board)
    ghost = Node3D.new()
    ghost.name = "PlacementPreview"
    add_child(ghost)

func _add_directional(color: Color, energy: float, pos: Vector3) -> void:
    var light := DirectionalLight3D.new()
    light.light_color = color
    light.light_energy = energy
    light.shadow_enabled = false
    add_child(light)
    light.position = pos
    light.look_at(Vector3.ZERO)

func _add_omni(color: Color, energy: float, pos: Vector3) -> void:
    var light := OmniLight3D.new()
    light.light_color = color
    light.light_energy = energy
    light.omni_range = 14
    light.shadow_enabled = false
    add_child(light)
    light.position = pos

func _flat_style(color: Color, corner: int = 17, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.set_corner_radius_all(corner)
    box.border_color = border
    box.set_border_width_all(2 if border.a > 0.0 else 0)
    box.content_margin_left = 10
    box.content_margin_right = 10
    box.content_margin_top = 8
    box.content_margin_bottom = 8
    return box

func _label(text_value: String, font_size: int = 25, color: Color = Color.WHITE) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return label

func _button(text_value: String, color: Color = Color("#21365f")) -> Button:
    var btn := Button.new()
    btn.text = text_value
    btn.custom_minimum_size = Vector2(100, 62)
    btn.add_theme_font_size_override("font_size", 23)
    btn.add_theme_color_override("font_color", Color.WHITE)
    btn.add_theme_stylebox_override("normal", _flat_style(color, 14))
    btn.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.15), 14))
    btn.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.18), 14))
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    return btn

func _build_interface() -> void:
    var backdrop := CanvasLayer.new()
    backdrop.layer = -1
    add_child(backdrop)
    background = ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # The CanvasLayer renders above the entire 3D scene. An opaque backdrop
    # here would cover the jelly board on every Android device.
    background.color = Color(0.031, 0.055, 0.13, 0.0)
    background.visible = false
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.add_child(background)

    var ui := CanvasLayer.new()
    ui.layer = 2
    add_child(ui)
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(overlay)

    var top := VBoxContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 18
    top.offset_right = -18
    top.offset_top = 24
    top.offset_bottom = 315
    top.add_theme_constant_override("separation", 8)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(top)

    var brand := _label("J E L L Y   B R I C K S", 26, Color("#f6d6fc"))
    top.add_child(brand)
    stage_label = _label("01 / 21", 19, Color("#96c9fa"))
    top.add_child(stage_label)
    model_title = _label("Reproduis le modèle", 22, Color("#f4ebff"))
    top.add_child(model_title)

    var model_panel := PanelContainer.new()
    model_panel.add_theme_stylebox_override("panel",
        _flat_style(Color(0.09, 0.14, 0.27, 0.93), 18, Color("#40587f")))
    model_panel.custom_minimum_size = Vector2(0, 162)
    top.add_child(model_panel)
    var center := CenterContainer.new()
    model_panel.add_child(center)
    model_grid = GridContainer.new()
    model_grid.add_theme_constant_override("h_separation", 3)
    model_grid.add_theme_constant_override("v_separation", 3)
    center.add_child(model_grid)

    var bottom := VBoxContainer.new()
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 16
    bottom.offset_right = -16
    bottom.offset_bottom = -22
    bottom.offset_top = -305
    bottom.add_theme_constant_override("separation", 11)
    bottom.mouse_filter = Control.MOUSE_FILTER_PASS
    overlay.add_child(bottom)

    status_label = _label("Choisis une forme et touche le plateau", 20, Color("#aad9ef"))
    bottom.add_child(status_label)
    var tray_scroll := ScrollContainer.new()
    tray_scroll.custom_minimum_size = Vector2(0, 79)
    tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    bottom.add_child(tray_scroll)
    tray = HBoxContainer.new()
    tray.add_theme_constant_override("separation", 10)
    tray_scroll.add_child(tray)
    var controls := HBoxContainer.new()
    controls.alignment = BoxContainer.ALIGNMENT_CENTER
    controls.add_theme_constant_override("separation", 10)
    bottom.add_child(controls)
    var back := _button("‹ Niveau", Color("#273f69"))
    back.pressed.connect(func(): _open_level(max(0, current_level - 1)))
    controls.add_child(back)
    var turn := _button("↻ Tourner", Color("#6545a0"))
    turn.pressed.connect(_rotate_piece)
    controls.add_child(turn)
    undo_button = _button("↶ Annuler", Color("#273f69"))
    undo_button.pressed.connect(_undo)
    controls.add_child(undo_button)
    next_button = _button("Suivant ›", Color("#138f95"))
    next_button.pressed.connect(func(): _open_level(min(unlocked, current_level + 1)))
    bottom.add_child(next_button)
    moves_label = _label("0 mouvement", 17, Color("#a4b8dc"))
    bottom.add_child(moves_label)

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_FILE):
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
    if data is Dictionary:
        unlocked = clampi(int(data.get("unlocked", 0)), 0, max(0, levels.size() - 1))
        current_level = clampi(int(data.get("level", 0)), 0, unlocked)

func _save_progress() -> void:
    var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify({
            "unlocked": unlocked, "level": current_level
        }))

func _open_level(index: int) -> void:
    if levels.is_empty():
        return
    current_level = clampi(index, 0, min(unlocked, levels.size() - 1))
    var level: Dictionary = levels[current_level]
    size = int(level["size"])
    completed = false
    moves = 0
    pieces.clear()
    occupied.clear()
    wanted.clear()
    placements.clear()
    last_placement.clear()
    has_undo_snapshot = false
    touch_started_on_board = false
    mouse_started_on_board = false
    shape_mesh_cache.clear()
    var rows: Array = level["rows"]
    for r in range(size):
        var row_string := String(rows[r])
        for c in range(size):
            var symbol := row_string.substr(c, 1)
            if symbol == ".":
                continue
            wanted[Vector2i(r, c)] = symbol
            if not pieces.has(symbol):
                pieces[symbol] = []
            pieces[symbol].append(Vector2i(r, c))
    for id in pieces.keys():
        var cells: Array = pieces[id]
        var first_r := size
        var first_c := size
        for cell in cells:
            first_r = mini(first_r, cell.x)
            first_c = mini(first_c, cell.y)
        var local_cells: Array = []
        for cell in cells:
            local_cells.append(Vector2i(cell.x - first_r, cell.y - first_c))
        pieces[id] = local_cells
    var ids: Array = pieces.keys()
    ids.sort()
    selected_id = String(ids[0]) if not ids.is_empty() else ""
    selected_turns = 0
    camera.size = float(size) * 2.3
    camera.position = Vector3(0, size * 1.05, size * 1.04)
    camera.look_at(Vector3.ZERO)
    stage_label.text = "NIVEAU %02d / %02d    ·    %s" % [
        current_level + 1, levels.size(), String(level["name"])]
    _draw_reference()
    _build_stage()
    _draw_tray()
    _refresh_text()
    _save_progress()

func _draw_reference() -> void:
    for child in model_grid.get_children():
        child.queue_free()
    model_grid.columns = size
    var rows: Array = levels[current_level]["rows"]
    var pixel := 22 if size >= 6 else 29
    for r in range(size):
        var row_string := String(rows[r])
        for c in range(size):
            var symbol := row_string.substr(c, 1)
            var box := Panel.new()
            box.custom_minimum_size = Vector2(pixel, pixel)
            var tint: Color = Color(PALETTE[symbol]) if PALETTE.has(symbol) else Color("#152441")
            box.add_theme_stylebox_override("panel", _flat_style(tint, 7))
            box.mouse_filter = Control.MOUSE_FILTER_IGNORE
            model_grid.add_child(box)

func _box_mesh(dimensions: Vector3, tint: Color, roughness: float = 0.55) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    var geometry := BoxMesh.new()
    geometry.size = dimensions
    item.mesh = geometry
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.15
    material.roughness = roughness
    item.material_override = material
    return item

func _build_stage() -> void:
    for child in board.get_children():
        child.queue_free()
    for child in ghost.get_children():
        child.queue_free()
    var rim := _box_mesh(Vector3(size + 0.55, 0.25, size + 0.55),
        Color("#507aab"), .23)
    rim.position.y = -0.22
    board.add_child(rim)
    var platform := _box_mesh(Vector3(size + .28, .25, size + .28),
        Color("#1a2d55"), .43)
    platform.position.y = -0.12
    board.add_child(platform)
    for r in range(size):
        for c in range(size):
            var square := _box_mesh(Vector3(.935, .016, .935),
                Color("#22375b") if wanted.has(Vector2i(r,c)) else Color("#15243d"), .81)
            square.position = Vector3(c + .5 - size / 2.0,
                .022, r + .5 - size / 2.0)
            board.add_child(square)
    for r in range(size):
        for c in range(size):
            if wanted.has(Vector2i(r, c)):
                var marker := _box_mesh(Vector3(.23, .028, .23),
                    Color(PALETTE[wanted[Vector2i(r, c)]]).darkened(.42), .30)
                marker.position = Vector3(c + .5 - size / 2.0,
                    .046, r + .5 - size / 2.0)
                board.add_child(marker)
    _rebuild_placements()
    _draw_preview(Vector2i(-10, -10))

func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    _add_triangle(st, a, b, c)
    _add_triangle(st, a, c, d)

func _shape_geometry(cells: Array) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var filled := {}
    for cell in cells:
        filled[cell] = true
    for cell in cells:
        var r: int = cell.x
        var c: int = cell.y
        var x0 := float(c)
        var x1 := x0 + 1.0
        var z0 := float(r)
        var z1 := z0 + 1.0
        _quad(st, Vector3(x0, .39, z0), Vector3(x0, .39, z1),
            Vector3(x1, .39, z1), Vector3(x1, .39, z0))
        var edges := [
            [Vector2(x0,z0),Vector2(x1,z0),Vector2i(r-1,c),Vector2(0,-1)],
            [Vector2(x1,z0),Vector2(x1,z1),Vector2i(r,c+1),Vector2(1,0)],
            [Vector2(x1,z1),Vector2(x0,z1),Vector2i(r+1,c),Vector2(0,1)],
            [Vector2(x0,z1),Vector2(x0,z0),Vector2i(r,c-1),Vector2(-1,0)]
        ]
        for e in edges:
            if filled.has(e[2]):
                continue
            var start: Vector2 = e[0]
            var finish: Vector2 = e[1]
            var normal: Vector2 = e[3]
            var a := Vector3(start.x, .39, start.y)
            var b := Vector3(finish.x, .39, finish.y)
            var off := Vector3(normal.x * .065, 0, normal.y * .065)
            var ctop := a + off + Vector3(0, -.10, 0)
            var dtop := b + off + Vector3(0, -.10, 0)
            _quad(st, a, b, dtop, ctop)
            var cbottom := ctop + Vector3(0, -.24, 0)
            var dbottom := dtop + Vector3(0, -.24, 0)
            _quad(st, ctop, dtop, dbottom, cbottom)
            _quad(st, cbottom, dbottom, b + Vector3(0, -.37, 0),
                a + Vector3(0, -.37, 0))
    st.generate_normals()
    return st.commit()

func _piece_node(id: String, cells: Array, placement: Vector2i,
        turns: int, preview: bool = false) -> Node3D:
    var shape := Node3D.new()
    shape.name = "Piece_" + id
    shape.position = Vector3(placement.y - size/2.0, .09,
        placement.x - size/2.0)
    var rotated := _rotate_cells(cells, turns)
    var mesh := MeshInstance3D.new()
    var mesh_key := id + ":" + str(posmod(turns, 4))
    if not shape_mesh_cache.has(mesh_key):
        shape_mesh_cache[mesh_key] = _shape_geometry(rotated)
    mesh.mesh = shape_mesh_cache[mesh_key]
    var material := ShaderMaterial.new()
    material.shader = GEL_SHADER
    var tint := Color(PALETTE[id])
    material.set_shader_parameter("candy_tint", tint)
    material.set_shader_parameter("detail", 1.0)
    if preview:
        material.set_shader_parameter("candy_tint",
            Color("#76ffd4") if _can_place(id, placement, turns) else Color("#ff6a9a"))
        shape.position.y = .48
    mesh.material_override = material
    shape.add_child(mesh)
    return shape

func _rotate_cells(cells: Array, turns: int) -> Array:
    var rotated: Array = cells.duplicate()
    for i in range(posmod(turns, 4)):
        var next: Array = []
        for p in rotated:
            next.append(Vector2i(p.y, -p.x))
        rotated = next
        var low_row := 999
        var low_col := 999
        for p in rotated:
            low_row = mini(low_row, p.x)
            low_col = mini(low_col, p.y)
        for k in range(rotated.size()):
            rotated[k] -= Vector2i(low_row, low_col)
    return rotated

func _can_place(id: String, pos: Vector2i, turns: int) -> bool:
    if not pieces.has(id):
        return false
    for cell in _rotate_cells(pieces[id], turns):
        var world: Vector2i = pos + cell
        if not wanted.has(world):
            return false
        if occupied.has(world) and occupied[world] != id:
            return false
    return true

func _try_place(id: String, position: Vector2i) -> void:
    if completed or not pieces.has(id):
        return
    var candidates := [position,
        position + Vector2i(0,-1), position + Vector2i(-1,0),
        position + Vector2i(0,1), position + Vector2i(1,0)]
    var chosen := Vector2i(-1,-1)
    for candidate in candidates:
        if _can_place(id, candidate, selected_turns):
            chosen = candidate
            break
    if chosen.x < 0:
        status_label.text = "Emplacement impossible · essaie de tourner"
        return
    last_placement = placements.duplicate(true)
    has_undo_snapshot = true
    placements[id] = {"row": chosen.x, "col": chosen.y, "turns": selected_turns}
    moves += 1
    _rebuild_placements(id)
    _draw_tray()
    _refresh_text()
    _check_win()

func _rebuild_placements(new_id: String = "") -> void:
    for child in board.get_children():
        if child.name.begins_with("Piece_"):
            child.queue_free()
    occupied.clear()
    for id in placements:
        var pose: Dictionary = placements[id]
        var at := Vector2i(int(pose["row"]), int(pose["col"]))
        var turns := int(pose["turns"])
        for cell in _rotate_cells(pieces[id], turns):
            occupied[at + cell] = id
        var piece := _piece_node(id, pieces[id], at, turns)
        board.add_child(piece)
        if id == new_id:
            var landing_material: ShaderMaterial = piece.get_child(0).material_override
            var animator := create_tween()
            piece.scale = Vector3(1.08, .65, 1.08)
            landing_material.set_shader_parameter("impact", .9)
            animator.set_parallel(true)
            animator.tween_property(piece, "scale", Vector3.ONE, .54).set_trans(
                Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
            animator.tween_property(landing_material, "shader_parameter/impact",
                0.0, .54).set_trans(Tween.TRANS_CUBIC)

func _draw_preview(pos: Vector2i) -> void:
    for child in ghost.get_children():
        child.queue_free()
    if pos.x < 0 or pos.y < 0 or completed or selected_id.is_empty():
        return
    var ghost_piece := _piece_node(selected_id, pieces[selected_id],
        pos, selected_turns, true)
    ghost.add_child(ghost_piece)

func _draw_tray() -> void:
    for child in tray.get_children():
        child.queue_free()
    var ids: Array = pieces.keys()
    ids.sort()
    for candidate in ids:
        var id := String(candidate)
        var btn := _button(id, Color(PALETTE[id]).darkened(
            0.39 if not placements.has(id) else 0.71))
        btn.custom_minimum_size.x = 79
        if id == selected_id:
            btn.add_theme_stylebox_override("normal", _flat_style(
                Color(PALETTE[id]).darkened(.18), 17, Color.WHITE))
        btn.pressed.connect(func(): _select_piece(id))
        tray.add_child(btn)

func _select_piece(id: String) -> void:
    selected_id = id
    selected_turns = int(placements[id]["turns"]) if placements.has(id) else 0
    _draw_tray()
    _refresh_text()

func _rotate_piece() -> void:
    if completed or selected_id.is_empty():
        return
    selected_turns = (selected_turns + 1) % 4
    status_label.text = "Rotation : %d° · touche une case" % (selected_turns * 90)

func _undo() -> void:
    if not has_undo_snapshot:
        return
    placements = last_placement.duplicate(true)
    last_placement.clear()
    has_undo_snapshot = false
    moves += 1
    _rebuild_placements()
    _draw_tray()
    _refresh_text()

func _refresh_text() -> void:
    var correct := 0
    for cell in wanted:
        if occupied.has(cell) and occupied[cell] == wanted[cell]:
            correct += 1
    status_label.text = "Assemblage %d / %d · brique %s" % [
        correct, wanted.size(), selected_id]
    moves_label.text = "%d coups   ·   %d formes" % [moves, pieces.size()]
    next_button.disabled = current_level >= unlocked or current_level >= levels.size() - 1
    undo_button.disabled = not has_undo_snapshot

func _check_win() -> void:
    if occupied.size() != wanted.size():
        return
    for cell in wanted:
        if not occupied.has(cell) or occupied[cell] != wanted[cell]:
            return
    completed = true
    if current_level + 1 < levels.size():
        unlocked = maxi(unlocked, current_level + 1)
    _save_progress()
    status_label.text = "BRAVO ! Modèle reconstitué ✦"
    next_button.disabled = current_level + 1 >= levels.size()
    var celebration := create_tween()
    celebration.tween_property(board, "scale", Vector3(1.045, 1.045, 1.045),
        .20).set_trans(Tween.TRANS_BACK)
    celebration.tween_property(board, "scale", Vector3.ONE, .32).set_trans(
        Tween.TRANS_ELASTIC)
    # Board cells are intentionally not regenerated: the completed level remains visible.

## A touch is committed only when released, never at finger-down.
## Otherwise the preview would lag behind and dragging could place early.
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_started_on_board = _inside_board_input_area(event.position)
            if touch_started_on_board:
                _handle_board_position(event.position, false)
        else:
            if touch_started_on_board:
                _handle_board_position(event.position, true)
            touch_started_on_board = false
            _draw_preview(Vector2i(-1, -1))
    elif event is InputEventScreenDrag and touch_started_on_board:
        _handle_board_position(event.position, false)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            mouse_started_on_board = _inside_board_input_area(event.position)
            if mouse_started_on_board:
                _handle_board_position(event.position, false)
        else:
            if mouse_started_on_board:
                _handle_board_position(event.position, true)
            mouse_started_on_board = false
            _draw_preview(Vector2i(-1, -1))
    elif event is InputEventMouseMotion and mouse_started_on_board:
        _handle_board_position(event.position, false)

func _inside_board_input_area(screen: Vector2) -> bool:
    var viewport_size := get_viewport().get_visible_rect().size
    return screen.y >= 315.0 * viewport_size.y / 1280.0 \
        and screen.y <= viewport_size.y * .80


func _handle_board_position(screen: Vector2, commit: bool) -> void:
    if completed:
        return
    # UI prevents interaction in title/preview and toolbar areas.
    if not _inside_board_input_area(screen):
        _draw_preview(Vector2i(-1, -1))
        return
    var origin := camera.project_ray_origin(screen)
    var direction := camera.project_ray_normal(screen)
    if absf(direction.y) < .001:
        return
    var distance := (-origin.y) / direction.y
    if distance < 0:
        return
    var hit := origin + direction * distance
    var col := int(floor(hit.x + float(size) / 2.0))
    var row := int(floor(hit.z + float(size) / 2.0))
    if row < 0 or col < 0 or row >= size or col >= size:
        _draw_preview(Vector2i(-1,-1))
        return
    var pos := Vector2i(row, col)
    if commit:
        _try_place(selected_id, pos)
        _draw_preview(Vector2i(-1,-1))
    else:
        _draw_preview(pos)
