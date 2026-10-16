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
const GEL_MESH = preload("res://scripts/gel_mesh.gd")
const CANDY_AUDIO = preload("res://scripts/candy_audio.gd")
const JELLY_VFX = preload("res://scripts/jelly_vfx.gd")
const SAVE_TRANSFER = preload("res://scripts/save_transfer.gd")
const SAVE_FILE := "user://jelly-native-progress.json"
const BACKUP_SAVE_FILE := SAVE_FILE + ".bak"
const TEMP_SAVE_FILE := SAVE_FILE + ".tmp"
const PRE_IMPORT_SAVE_FILE := SAVE_FILE + ".before-import.bak"

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
var candy_fx: Node3D
var background: ColorRect
var model_grid: GridContainer
var model_title: Label
var stage_label: Label
var status_label: Label
var moves_label: Label
var select_label: Label
var tray: HBoxContainer
var tray_scroll: ScrollContainer
var overlay: Control
var top_panel: VBoxContainer
var bottom_panel: VBoxContainer
var undo_button: Button
var next_button: Button
var feedback_button: Button
var feedback_enabled: bool = true
var audio_bank: Dictionary = {}
var audio_voices: Array[AudioStreamPlayer] = []
var audio_voice_cursor: int = 0
var toast_tween: Tween
var last_placement: Dictionary = {}
var has_undo_snapshot: bool = false
var undo_history: Array[Dictionary] = []
var touch_started_on_board: bool = false
var active_touch_index: int = -1
var mouse_started_on_board: bool = false
var rotated_cells_cache: Dictionary = {}
var shape_mesh_cache: Dictionary = {}
var stage_resource_cache: Dictionary = {}
var stud_mesh: ArrayMesh
var contact_shadow_material: ShaderMaterial
var preview_cell: Vector2i = Vector2i(-1, -1)
var preview_target: Vector3 = Vector3.ZERO
var win_tween: Tween
var resume_session: Dictionary = {}
var saved_sessions: Dictionary = {}
var export_picker: FileDialog
var import_picker: FileDialog
var import_confirmation: ConfirmationDialog
var pending_export: String = ""
var pending_import: Dictionary = {}

func _ready() -> void:
    _read_levels()
    _build_environment()
    _build_audio()
    _build_interface()
    _load_progress()
    _update_feedback_button()
    _open_level(current_level, true)

## A short eased transition gives the translucent piece physical weight
## without allocating a tween for each Android touch-motion event.
func _process(delta: float) -> void:
    if ghost == null or ghost.get_child_count() == 0:
        return
    var floating_piece: Node3D = ghost.get_child(0) as Node3D
    if not floating_piece.visible:
        return
    var blend: float = 1.0 - exp(-minf(delta, .1) * 26.0)
    if floating_piece.position.distance_squared_to(preview_target) > .00001:
        floating_piece.position = floating_piece.position.lerp(
            preview_target, blend)

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
    # Soft product-photography studio, not the former dark game backdrop.
    env.background_color = Color("#f7f8fb")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#eff4ff")
    env.ambient_light_energy = 0.96
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)

    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.current = true
    add_child(camera)

    # Seamless matte photo-studio floor behind the product. A single static
    # mesh regardless of puzzle dimensions; no realtime shadow maps.
    var studio_floor := MeshInstance3D.new()
    studio_floor.name = "StudioCyclorama"
    var studio_plane := PlaneMesh.new()
    studio_plane.size = Vector2(70, 70)
    studio_floor.mesh = studio_plane
    var studio_paint := StandardMaterial3D.new()
    studio_paint.albedo_color = Color("#f9fafc")
    studio_paint.roughness = .94
    studio_floor.material_override = studio_paint
    studio_floor.position.y = -.56
    studio_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(studio_floor)

    _add_directional(Color("#fff8f1"), 1.65, Vector3(-4.0, 10.0, 6.0))
    _add_directional(Color("#c2e5ff"), 0.54, Vector3(5.0, 6.0, -4.0))
    # Only one cool studio rim; fake contact shadows cost no shadow maps.
    _add_omni(Color("#dbefff"), 0.46, Vector3(2.5, 4.5, 1.2))

    stud_mesh = GEL_MESH.build_stud()
    contact_shadow_material = ShaderMaterial.new()
    contact_shadow_material.shader = preload("res://shaders/contact_shadow.gdshader")
    board = Node3D.new()
    board.name = "JellyBoard"
    add_child(board)
    ghost = Node3D.new()
    ghost.name = "PlacementPreview"
    add_child(ghost)
    # Keep pooled effects outside board: rebuilding or scaling the puzzle
    # never accidentally duplicates or stretches running particles.
    candy_fx = JELLY_VFX.new()
    candy_fx.name = "CandyEffects"
    add_child(candy_fx)

## Three pooled voices allow a candy landing to overlap a subsequent tap.
## Clips are built once, not per touch frame, and never require microphone access.
func _build_audio() -> void:
    for kind in CANDY_AUDIO.EVENTS:
        audio_bank[kind] = CANDY_AUDIO.make_clip(kind)
    for i in range(3):
        var voice := AudioStreamPlayer.new()
        voice.volume_db = -7.0
        voice.name = "CandyVoice%d" % i
        add_child(voice)
        audio_voices.append(voice)

func _play_feedback(kind: String, vibration_ms: int = 0) -> void:
    if not feedback_enabled:
        return
    if audio_bank.has(kind) and not audio_voices.is_empty():
        var voice: AudioStreamPlayer = audio_voices[audio_voice_cursor % audio_voices.size()]
        audio_voice_cursor += 1
        voice.stream = audio_bank[kind]
        voice.play()
    if vibration_ms > 0 and OS.has_feature("mobile"):
        Input.vibrate_handheld(vibration_ms, 0.25)

func _update_feedback_button() -> void:
    if feedback_button != null:
        feedback_button.text = "FX : ON" if feedback_enabled else "FX : OFF"
        feedback_button.tooltip_text = "Activer ou couper les sons et vibrations"

func _toggle_feedback() -> void:
    feedback_enabled = not feedback_enabled
    _update_feedback_button()
    _save_progress()
    if feedback_enabled:
        _play_feedback("select")

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
    if corner >= 10:
        box.shadow_color = Color(0.0, 0.0, .07, .25)
        box.shadow_size = 5
        box.shadow_offset = Vector2(0, 3)
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
    top_panel = top
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.offset_left = 18
    top.offset_right = -18
    top.offset_top = 24
    top.offset_bottom = 315
    top.add_theme_constant_override("separation", 8)
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(top)

    var brand := _label("J E L L Y   B R I C K S", 26, Color("#34455f"))
    top.add_child(brand)
    stage_label = _label("01 / 21", 19, Color("#5c6f84"))
    top.add_child(stage_label)
    model_title = _label("Reproduis le modèle", 22, Color("#35475e"))
    top.add_child(model_title)

    var model_panel := PanelContainer.new()
    model_panel.add_theme_stylebox_override("panel",
        _flat_style(Color("#ffffff"), 18, Color("#e0e7ef")))
    model_panel.custom_minimum_size = Vector2(0, 162)
    top.add_child(model_panel)
    var center := CenterContainer.new()
    model_panel.add_child(center)
    model_grid = GridContainer.new()
    model_grid.add_theme_constant_override("h_separation", 3)
    model_grid.add_theme_constant_override("v_separation", 3)
    center.add_child(model_grid)

    var bottom := VBoxContainer.new()
    bottom_panel = bottom
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.offset_left = 16
    bottom.offset_right = -16
    bottom.offset_bottom = -22
    bottom.offset_top = -305
    bottom.add_theme_constant_override("separation", 11)
    bottom.mouse_filter = Control.MOUSE_FILTER_PASS
    overlay.add_child(bottom)

    status_label = _label("Choisis une forme et touche le plateau", 20, Color("#38536c"))
    bottom.add_child(status_label)
    tray_scroll = ScrollContainer.new()
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
    var hint := _button("? Indice", Color("#325779"))
    hint.pressed.connect(_show_hint)
    controls.add_child(hint)
    var bottom_actions := HBoxContainer.new()
    bottom_actions.add_theme_constant_override("separation", 10)
    bottom.add_child(bottom_actions)
    next_button = _button("Suivant ›", Color("#138f95"))
    next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next_button.pressed.connect(func(): _open_level(min(unlocked, current_level + 1)))
    bottom_actions.add_child(next_button)
    feedback_button = _button("FX : ON", Color("#273f69"))
    feedback_button.custom_minimum_size = Vector2(124, 54)
    feedback_button.add_theme_font_size_override("font_size", 18)
    feedback_button.pressed.connect(_toggle_feedback)
    bottom_actions.add_child(feedback_button)
    moves_label = _label("0 mouvement", 17, Color("#667b8b"))
    bottom.add_child(moves_label)
    # Keep the board interactive: no additional toolbar rows on portrait.
    var export_button := _button("Exporter", Color("#325779"))
    export_button.custom_minimum_size = Vector2(112, 54)
    export_button.add_theme_font_size_override("font_size", 17)
    export_button.tooltip_text = "Sauvegarder la progression dans un fichier"
    export_button.pressed.connect(_export_backup)
    bottom_actions.add_child(export_button)
    var import_button := _button("Importer", Color("#325779"))
    import_button.custom_minimum_size = Vector2(112, 54)
    import_button.add_theme_font_size_override("font_size", 17)
    import_button.tooltip_text = "Restaurer une sauvegarde de progression"
    import_button.pressed.connect(_import_backup)
    bottom_actions.add_child(import_button)
    _build_transfer_dialogs()

## Godot 4.6 uses Android Storage Access Framework for ACCESS_FILESYSTEM
## native dialogs (Android 10+). The content:// URI is passed directly
## to FileAccess. No global file permission, external SDK or network access.
func _build_transfer_dialogs() -> void:
    export_picker = FileDialog.new()
    export_picker.access = FileDialog.ACCESS_FILESYSTEM
    export_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    export_picker.use_native_dialog = true
    export_picker.current_file = "jelly-bricks-backup.json"
    export_picker.add_filter("*.json", "Sauvegardes Jelly Bricks", "application/json")
    export_picker.file_selected.connect(_write_export)
    add_child(export_picker)

    import_picker = FileDialog.new()
    import_picker.access = FileDialog.ACCESS_FILESYSTEM
    import_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    import_picker.use_native_dialog = true
    import_picker.add_filter("*.json", "Sauvegardes Jelly Bricks", "application/json")
    import_picker.file_selected.connect(_prepare_import)
    add_child(import_picker)

    import_confirmation = ConfirmationDialog.new()
    import_confirmation.title = "Restaurer Jelly Bricks"
    import_confirmation.ok_button_text = "Remplacer"
    import_confirmation.confirmed.connect(_confirm_import)
    add_child(import_confirmation)

func _export_backup() -> void:
    _save_progress()
    var data: Dictionary = _read_progress_data()
    var validation: Dictionary = SAVE_TRANSFER.validate_progress(data, levels)
    if not validation.get("ok", false):
        status_label.text = "Export impossible : " + String(validation.get("reason", "données invalides"))
        return
    pending_export = SAVE_TRANSFER.encode(validation["progress"])
    export_picker.popup_file_dialog()

func _write_export(path: String) -> void:
    if pending_export.is_empty():
        return
    var out := FileAccess.open(path, FileAccess.WRITE)
    if out == null:
        status_label.text = "Échec export : stockage non accessible"
        return
    out.store_string(pending_export)
    out.flush()
    var status: Error = out.get_error()
    out.close()
    if status != OK:
        status_label.text = "Échec export : écriture interrompue"
        return
    pending_export = ""
    status_label.text = "Sauvegarde exportée · garde le fichier hors de l'application"

func _import_backup() -> void:
    pending_import.clear()
    import_picker.popup_file_dialog()

func _prepare_import(path: String) -> void:
    pending_import.clear()
    var source := FileAccess.open(path, FileAccess.READ)
    if source == null:
        status_label.text = "Import impossible : fichier inaccessible"
        return
    # Read a bounded number of bytes even for Android content-provider URIs.
    var bytes: PackedByteArray = source.get_buffer(SAVE_TRANSFER.MAX_BYTES + 1)
    source.close()
    if bytes.size() > SAVE_TRANSFER.MAX_BYTES:
        status_label.text = "Import refusé : fichier trop volumineux"
        return
    var parsed: Dictionary = SAVE_TRANSFER.decode(bytes.get_string_from_utf8(), levels)
    if not parsed.get("ok", false):
        status_label.text = "Import refusé : " + String(parsed.get("reason", "format invalide"))
        return
    pending_import = parsed["progress"]
    import_confirmation.dialog_text = ("Cette sauvegarde contient %d niveaux débloqués et %d parties.\n"
        + "Restaurer remplacera la progression locale actuelle.\n"
        + "Une copie de l’ancienne partie sera conservée.") % [
        int(pending_import["unlocked"]) + 1, pending_import["sessions"].size()]
    import_confirmation.popup_centered(Vector2i(560, 270))

func _confirm_import() -> void:
    if pending_import.is_empty():
        return
    if not _install_backup(pending_import):
        status_label.text = "Import échoué · progression actuelle conservée"
        return
    pending_import.clear()
    status_label.text = "Sauvegarde restaurée · progression et niveaux retrouvés"

## Transactional import: create backup first, write staging JSON, and only
## switch active progress if the replacement was committed successfully.
func _install_backup(progress: Dictionary) -> bool:
    var validated: Dictionary = SAVE_TRANSFER.validate_progress(progress, levels)
    if not validated.get("ok", false):
        return false
    _save_progress()
    if FileAccess.file_exists(SAVE_FILE):
        var existing: Dictionary = _read_json_dictionary(SAVE_FILE)
        if not existing.has("unlocked") or DirAccess.copy_absolute(
                SAVE_FILE, PRE_IMPORT_SAVE_FILE) != OK:
            return false
    var temp := FileAccess.open(TEMP_SAVE_FILE, FileAccess.WRITE)
    if temp == null:
        return false
    temp.store_string(JSON.stringify(validated["progress"]))
    temp.flush()
    var write_error: Error = temp.get_error()
    temp.close()
    if write_error != OK:
        DirAccess.remove_absolute(TEMP_SAVE_FILE)
        return false
    if DirAccess.rename_absolute(TEMP_SAVE_FILE, SAVE_FILE) != OK:
        DirAccess.remove_absolute(TEMP_SAVE_FILE)
        return false
    # _load_progress is also used on startup; avoid combining imported and
    # previously loaded session dictionaries during this in-process restore.
    saved_sessions.clear()
    resume_session.clear()
    _load_progress()
    _update_feedback_button()
    _open_level(current_level, true)
    return true

## A malformed JSON save is an expected crash-recovery condition, not
## a Godot engine exception. JSON.parse() reports status without log spam.
func _read_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var decoder := JSON.new()
    if decoder.parse(FileAccess.get_file_as_string(path)) != OK:
        return {}
    if decoder.data is Dictionary:
        return decoder.data
    return {}

## Read a complete save; transparently recover the last valid generation.
func _read_progress_data() -> Dictionary:
    for path in [SAVE_FILE, BACKUP_SAVE_FILE]:
        var decoded: Dictionary = _read_json_dictionary(path)
        var unlock_value: Variant = decoded.get("unlocked", null)
        if unlock_value is float or unlock_value is int:
            return decoded
    return {}

func _load_progress() -> void:
    saved_sessions.clear()
    resume_session.clear()
    var data: Dictionary = _read_progress_data()
    if data.is_empty():
        return
    unlocked = clampi(int(data.get("unlocked", 0)), 0, max(0, levels.size() - 1))
    current_level = clampi(int(data.get("level", 0)), 0, unlocked)
    feedback_enabled = bool(data.get("feedback_enabled", true))
    var raw_sessions: Variant = data.get("sessions", {})
    if raw_sessions is Dictionary:
        for level_key in raw_sessions:
            var key: String = String(level_key)
            if key.is_valid_int() and int(key) >= 0 \
                    and int(key) < levels.size() and raw_sessions[level_key] is Dictionary:
                saved_sessions[key] = raw_sessions[level_key]
    # Compatibility with v0.9.7: it contained only one active session.
    if saved_sessions.is_empty() and data.get("session", {}) is Dictionary:
        saved_sessions[str(current_level)] = data["session"]
    resume_session = saved_sessions.get(str(current_level), {})

func _session_snapshot() -> Dictionary:
    return {
        "level": current_level,
        "placements": placements.duplicate(true),
        "undo_history": undo_history.duplicate(true),
        "selected_id": selected_id,
        "selected_turns": selected_turns,
        "moves": moves
    }

func _save_progress() -> void:
    if levels.is_empty():
        return
    var session: Dictionary = _session_snapshot()
    saved_sessions[str(current_level)] = session
    var data := {
        "format": 2,
        "unlocked": unlocked,
        "level": current_level,
        "feedback_enabled": feedback_enabled,
        "session": session, # old app compatibility
        "sessions": saved_sessions
    }
    # Write and flush first. An interrupted write never truncates the real
    # save; rename replaces it only when the new JSON is complete.
    var file := FileAccess.open(TEMP_SAVE_FILE, FileAccess.WRITE)
    if file == null:
        push_warning("Unable to write Jelly Bricks save staging file")
        return
    file.store_string(JSON.stringify(data))
    file.flush()
    file.close()
    # Keep only a structurally valid previous generation as a backup.
    if FileAccess.file_exists(SAVE_FILE):
        var previous: Dictionary = _read_json_dictionary(SAVE_FILE)
        if previous.has("unlocked"):
            var backup_error: Error = DirAccess.copy_absolute(
                SAVE_FILE, BACKUP_SAVE_FILE)
            if backup_error != OK:
                push_warning("Unable to refresh Jelly Bricks progress backup")
    var swap_error: Error = DirAccess.rename_absolute(
        TEMP_SAVE_FILE, SAVE_FILE)
    if swap_error != OK:
        push_error("Unable to commit Jelly Bricks progress: " + str(swap_error))

## Saved sessions never bypass the puzzle geometry or alter the board until
## every piece and undo entry has passed the same bounds/collision validation.
func _validate_saved_placements(raw: Variant) -> Dictionary:
    if not raw is Dictionary or raw.size() > pieces.size():
        return {"ok": false}
    var clean: Dictionary = {}
    var taken: Dictionary = {}
    for raw_id in raw:
        if not raw_id is String or not pieces.has(raw_id):
            return {"ok": false}
        var pose: Variant = raw[raw_id]
        if not pose is Dictionary:
            return {"ok": false}
        for field in ["row", "col", "turns"]:
            if not pose.has(field):
                return {"ok": false}
            var value: Variant = pose[field]
            if not (value is int or value is float):
                return {"ok": false}
            if float(int(value)) != float(value):
                return {"ok": false}
        var row: int = int(pose["row"])
        var col: int = int(pose["col"])
        var turns: int = int(pose["turns"])
        if row < 0 or col < 0 or row >= size or col >= size \
                or turns < 0 or turns > 3:
            return {"ok": false}
        for cell in _rotate_cells(pieces[raw_id], turns):
            var world: Vector2i = Vector2i(row, col) + cell
            if not wanted.has(world) or taken.has(world):
                return {"ok": false}
            taken[world] = true
        clean[raw_id] = {"row": row, "col": col, "turns": turns}
    return {"ok": true, "placements": clean}

## A new Android process restores the selected brick, orientation and 64
## undo states. Older saves simply start an empty puzzle on the same level.
func _restore_session() -> void:
    var stored: Dictionary = resume_session
    resume_session = {}
    if stored.get("level", -1) != current_level:
        return
    var decoded: Dictionary = _validate_saved_placements(stored.get("placements", {}))
    if not decoded.get("ok", false):
        return
    var raw_history: Variant = stored.get("undo_history", [])
    if not raw_history is Array or raw_history.size() > 64:
        return
    var clean_history: Array[Dictionary] = []
    for snapshot in raw_history:
        var entry: Dictionary = _validate_saved_placements(snapshot)
        if not entry.get("ok", false):
            return
        clean_history.append(entry["placements"])
    var turns_value: Variant = stored.get("selected_turns", 0)
    var moves_value: Variant = stored.get("moves", 0)
    if not (turns_value is int or turns_value is float) \
            or not (moves_value is int or moves_value is float):
        return
    if float(int(turns_value)) != float(turns_value) \
            or float(int(moves_value)) != float(moves_value):
        return
    if int(turns_value) < 0 or int(turns_value) > 3 \
            or int(moves_value) < 0 or int(moves_value) > 1000000:
        return
    placements = decoded["placements"]
    undo_history = clean_history
    last_placement = undo_history.back().duplicate(true) if not undo_history.is_empty() else {}
    has_undo_snapshot = not undo_history.is_empty()
    moves = maxi(int(moves_value), placements.size())
    var restored_id: String = String(stored.get("selected_id", selected_id))
    if pieces.has(restored_id):
        selected_id = restored_id
    selected_turns = int(turns_value)
    _rebuild_placements()
    completed = _board_matches_model()

func _open_level(index: int, resume: bool = false) -> void:
    if levels.is_empty():
        return
    if not pieces.is_empty() and index != current_level:
        _save_progress()
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
    undo_history.clear()
    has_undo_snapshot = false
    touch_started_on_board = false
    active_touch_index = -1
    mouse_started_on_board = false
    preview_cell = Vector2i(-1, -1)
    candy_fx.reset()
    if win_tween != null and win_tween.is_valid():
        win_tween.kill()
    board.scale = Vector3.ONE
    shape_mesh_cache.clear()
    rotated_cells_cache.clear()
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
    # Maintain a full-board composition across 4..7-cell puzzles and
    # portrait aspect ratios; leave breathing room around deep 3D bricks.
    camera.size = float(size) * 2.70
    camera.position = Vector3(size * .15, size * .83, size * 1.34)
    camera.look_at(Vector3.ZERO)
    stage_label.text = "NIVEAU %02d / %02d    ·    %s" % [
        current_level + 1, levels.size(), String(level["name"])]
    _draw_reference()
    _build_stage()
    if resume or saved_sessions.has(str(current_level)):
        resume_session = saved_sessions.get(str(current_level), resume_session)
        _restore_session()
    _draw_tray()
    _refresh_text()
    if completed:
        status_label.text = "BRAVO ! Modèle reconstitué ✦"
        next_button.disabled = current_level + 1 >= levels.size()
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
            var colored := PALETTE.has(symbol)
            var tint: Color = Color(PALETTE[symbol]) if colored else Color("#111c35")
            var style := _flat_style(tint.lightened(.08) if colored else tint, 7)
            if colored:
                style.border_color = tint.lightened(.35)
                style.set_border_width_all(1)
            box.add_theme_stylebox_override("panel", style)
            box.mouse_filter = Control.MOUSE_FILTER_IGNORE
            model_grid.add_child(box)

## Repeated floor tiles use shared GPU resources, not one material and
## mesh allocation for every board square on every stage transition.
func _box_mesh(dimensions: Vector3, tint: Color,
        roughness: float = 0.55, glow: float = 0.0) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    var key := str(dimensions) + ":" + tint.to_html() + ":" + str(roughness) + ":" + str(glow)
    if not stage_resource_cache.has(key):
        var geometry := BoxMesh.new()
        geometry.size = dimensions
        var material := StandardMaterial3D.new()
        material.albedo_color = tint
        material.metallic = 0.15
        material.roughness = roughness
        if glow > 0.0:
            material.emission_enabled = true
            material.emission = tint
            material.emission_energy_multiplier = glow
        stage_resource_cache[key] = {"mesh": geometry, "material": material}
    var cached: Dictionary = stage_resource_cache[key]
    item.mesh = cached["mesh"]
    item.material_override = cached["material"]
    return item

## One GPU draw batch for ALL floor cells and one for ALL target marks.
## The Compatibility renderer does not automatically instance MeshInstance3D.
## MultiMesh + per-instance vertex colors avoid ~100 static draw submissions
## on 7x7 puzzles without changing the authored candy color palette.
func _add_stage_batch(batch_name: String, dimensions: Vector3,
        positions: Array[Vector3], tints: Array[Color],
        roughness: float) -> MultiMeshInstance3D:
    assert(positions.size() == tints.size())
    var node := MultiMeshInstance3D.new()
    node.name = batch_name
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if positions.is_empty():
        board.add_child(node)
        return node
    var cache_key := "instanced:" + str(dimensions) + ":" + str(roughness)
    if not stage_resource_cache.has(cache_key):
        var geometry := BoxMesh.new()
        geometry.size = dimensions
        var paint := StandardMaterial3D.new()
        paint.albedo_color = Color.WHITE
        paint.vertex_color_use_as_albedo = true
        paint.metallic = 0.15
        paint.roughness = roughness
        stage_resource_cache[cache_key] = {
            "mesh": geometry, "material": paint
        }
    var shared: Dictionary = stage_resource_cache[cache_key]
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = shared["mesh"]
    batch.instance_count = positions.size()
    for idx in range(positions.size()):
        batch.set_instance_transform(idx, Transform3D(Basis.IDENTITY, positions[idx]))
        batch.set_instance_color(idx, tints[idx])
    node.multimesh = batch
    node.material_override = shared["material"]
    board.add_child(node)
    return node

func _build_stage() -> void:
    for child in board.get_children():
        # Detach old batches immediately, preventing a one-frame double render
        # and name collisions when the player switches levels rapidly.
        board.remove_child(child)
        child.queue_free()
    for child in ghost.get_children():
        ghost.remove_child(child)
        child.queue_free()
    # Layered floating candy-board silhouette. All trim is static and shared,
    # avoiding post-processing, extra shaders and real-time shadows on mobile.
    var foot := _box_mesh(Vector3(size + .76, .14, size + .76),
        Color("#e0e4e9"), .72)
    foot.position.y = -.38
    board.add_child(foot)
    var rim := _box_mesh(Vector3(size + .55, .22, size + .55),
        Color("#f0f2f6"), .24)
    rim.position.y = -.24
    board.add_child(rim)
    var platform := _box_mesh(Vector3(size + .28, .21, size + .28),
        Color("#ffffff"), .52)
    platform.position.y = -.115
    board.add_child(platform)
    # Thin four-sided soft glow separates the board from the dark scene.
    var trim_color := Color("#d8e5ee")
    for side in [-1.0, 1.0]:
        var long_rail := _box_mesh(Vector3(size + .34, .065, .054),
            trim_color, .12, .60)
        long_rail.position = Vector3(0, .002, side * (float(size) * .5 + .14))
        board.add_child(long_rail)
        var short_rail := _box_mesh(Vector3(.054, .065, size + .34),
            trim_color, .12, .60)
        short_rail.position = Vector3(side * (float(size) * .5 + .14), .002, 0)
        board.add_child(short_rail)
    # Keep two instanced meshes regardless of grid size: the broad satin
    # floor uses a dimmer candy color, target dots use a brighter tint.
    # Both retain individual colors even though they share material/mesh.
    var floor_positions: Array[Vector3] = []
    var floor_tints: Array[Color] = []
    var target_positions: Array[Vector3] = []
    var target_tints: Array[Color] = []
    for r in range(size):
        for c in range(size):
            var at := Vector2i(r, c)
            var position := Vector3(c + .5 - size / 2.0,
                .022, r + .5 - size / 2.0)
            var target_color := Color("#edf0f5")
            if wanted.has(at):
                target_color = Color(PALETTE[wanted[at]]).lerp(Color.WHITE, .78)
                target_positions.append(position + Vector3(0, .025, 0))
                target_tints.append(Color(PALETTE[wanted[at]]).lerp(Color.WHITE, .18))
            floor_positions.append(position)
            floor_tints.append(target_color)
    _add_stage_batch("FloorBatch", Vector3(.936, .016, .936),
        floor_positions, floor_tints, .55)
    _add_stage_batch("TargetBatch", Vector3(.29, .029, .29),
        target_positions, target_tints, .27)
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
    # Beveled contiguous body with a shared smooth-shaded outline.
    # All exposed corners, enclosed holes and islands use one cached mesh.
    return GEL_MESH.build(cells)

func _piece_node(id: String, cells: Array, placement: Vector2i,
        turns: int, preview: bool = false) -> Node3D:
    var shape := Node3D.new()
    shape.name = "Piece_" + id
    shape.position = Vector3(placement.y - size/2.0, .034,
        placement.x - size/2.0)
    var rotated := _pose_cells(id, turns)
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
    material.set_shader_parameter("sheen", 0.17 if preview else 0.48)
    material.set_shader_parameter("gel_opacity", 0.42 if preview else 0.95)
    if preview:
        material.set_shader_parameter("candy_tint",
            _preview_tint(id, placement, turns))
        shape.position.y = .48
    mesh.material_override = material
    shape.add_child(mesh)
    # Candy studs share one smooth beveled mesh and one shader material.
    # Four studs per occupied cell, submitted as one MultiMesh per piece.
    var stud_batch := MultiMesh.new()
    stud_batch.transform_format = MultiMesh.TRANSFORM_3D
    stud_batch.mesh = stud_mesh
    stud_batch.instance_count = rotated.size() * 4
    var index := 0
    for cell in rotated:
        for dx in [-.235, .235]:
            for dz in [-.235, .235]:
                var transform := Transform3D(Basis(),
                    Vector3(float(cell.y) + .5 + dx, 0.0,
                        float(cell.x) + .5 + dz))
                stud_batch.set_instance_transform(index, transform)
                index += 1
    var studs := MultiMeshInstance3D.new()
    studs.name = "SoftGelStuds"
    studs.multimesh = stud_batch
    studs.material_override = material
    shape.add_child(studs)
    if not preview:
        # Cheap contact shading beneath the brick, no Android shadow map.
        var max_row := 0
        var max_col := 0
        for cell in rotated:
            max_row = maxi(max_row, cell.x + 1)
            max_col = maxi(max_col, cell.y + 1)
        var shadow := MeshInstance3D.new()
        shadow.name = "SoftContactShadow"
        var patch := PlaneMesh.new()
        patch.size = Vector2(float(max_col) + .28, float(max_row) + .28)
        shadow.mesh = patch
        shadow.material_override = contact_shadow_material
        shadow.position = Vector3(float(max_col) * .5, .038,
            float(max_row) * .5)
        shape.add_child(shadow)
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

## Placement previews and live gestures ask for rotated outlines many times
## per frame. Cache these tiny immutable arrays only for the current level.
func _pose_cells(id: String, turns: int) -> Array:
    if not pieces.has(id):
        return []
    var key := id + ":" + str(posmod(turns, 4))
    if not rotated_cells_cache.has(key):
        rotated_cells_cache[key] = _rotate_cells(pieces[id], turns)
    return rotated_cells_cache[key]

func _can_place(id: String, pos: Vector2i, turns: int) -> bool:
    if not pieces.has(id):
        return false
    for cell in _pose_cells(id, turns):
        var world: Vector2i = pos + cell
        if not wanted.has(world):
            return false
        if occupied.has(world) and occupied[world] != id:
            return false
    return true

## A geometric fit is not necessarily a match with the reference.
## Keep wrong moves possible as a puzzle mechanic, but never mark them green.
## Pose-only comparison also works during rebuilding, independent from
## the order in which placed pieces repopulate the occupied map.
func _pose_matches_model(id: String, pos: Vector2i, turns: int) -> bool:
    if not pieces.has(id):
        return false
    for cell in _pose_cells(id, turns):
        if wanted.get(pos + cell, "") != id:
            return false
    return true

func _matches_model(id: String, pos: Vector2i, turns: int) -> bool:
    return _can_place(id, pos, turns) and _pose_matches_model(id, pos, turns)

func _preview_tint(id: String, pos: Vector2i, turns: int) -> Color:
    if not _can_place(id, pos, turns):
        return Color("#ff537e") # invalid geometry: rose
    if _pose_matches_model(id, pos, turns):
        return Color("#76ffd4") # fully correct: mint
    return Color("#ffc46a") # possible but not matching: amber

## A release near the authored target should snap to the correct design
## instead of selecting the first merely geometric fit. Never teleport more
## than one grid cell. Preview and final release use this exact function.
func _snap_placement(id: String, position: Vector2i, turns: int) -> Vector2i:
    if not pieces.has(id):
        return Vector2i(-1, -1)
    var offsets := [Vector2i.ZERO, Vector2i(0, -1), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(1, 0)]
    var first_fitting := Vector2i(-1, -1)
    for offset in offsets:
        var candidate: Vector2i = position + offset
        if candidate.x < 0 or candidate.y < 0:
            continue
        if not _can_place(id, candidate, turns):
            continue
        if _pose_matches_model(id, candidate, turns):
            return candidate
        if first_fitting.x < 0:
            first_fitting = candidate
    return first_fitting

func _select_next_available() -> void:
    var ids: Array = pieces.keys()
    ids.sort()
    for candidate in ids:
        var id := String(candidate)
        if not placements.has(id):
            selected_id = id
            selected_turns = 0
            return

func _try_place(id: String, position: Vector2i) -> void:
    if completed or not pieces.has(id):
        return
    var chosen := _snap_placement(id, position, selected_turns)
    var placed_turns := selected_turns
    if chosen.x < 0:
        status_label.text = "Emplacement impossible · tourne ou annule"
        _play_feedback("reject", 12)
        return
    if placements.has(id):
        var old_pose: Dictionary = placements[id]
        if int(old_pose["row"]) == chosen.x and int(old_pose["col"]) == chosen.y \
                and int(old_pose["turns"]) == placed_turns:
            status_label.text = "Cette brique est déjà à cet emplacement"
            return
    undo_history.append(placements.duplicate(true))
    if undo_history.size() > 64:
        undo_history.pop_front()
    last_placement = undo_history.back().duplicate(true)
    has_undo_snapshot = true
    placements[id] = {"row": chosen.x, "col": chosen.y, "turns": selected_turns}
    moves += 1
    _rebuild_placements(id)
    _select_next_available()
    _draw_tray()
    _refresh_text()
    var correctly_placed: bool = _matches_model(id, chosen, placed_turns)
    candy_fx.landing(Vector3(chosen.y - size / 2.0, .035,
        chosen.x - size / 2.0), Color(PALETTE[id]), correctly_placed)
    if not correctly_placed:
        status_label.text = "Placement possible, mais différent du modèle · annule ou déplace"
        _play_feedback("wrong", 15)
    else:
        _play_feedback("place", 23)
    _check_win()
    _save_progress()

func _rebuild_placements(new_id: String = "") -> void:
    for child in board.get_children():
        if child.name.begins_with("Piece_"):
            # A moved/undone jelly volume must disappear in this frame.
            # queue_free() alone leaves both copies visible until frame end
            # and causes temporary Piece_A2 names on repeated placements.
            board.remove_child(child)
            child.queue_free()
    occupied.clear()
    for id in placements:
        var pose: Dictionary = placements[id]
        var at := Vector2i(int(pose["row"]), int(pose["col"]))
        var turns := int(pose["turns"])
        for cell in _pose_cells(id, turns):
            occupied[at + cell] = id
        var piece := _piece_node(id, pieces[id], at, turns)
        var candy_material: ShaderMaterial = piece.get_child(0).material_override
        candy_material.set_shader_parameter("mismatch",
            0.0 if _pose_matches_model(id, at, turns) else 1.0)
        board.add_child(piece)
        if id == new_id:
            var landing_material: ShaderMaterial = piece.get_child(0).material_override
            var animator := create_tween()
            # A short, weighted damped wobble: the studded brick settles
            # rather than looking like a rigid cube instantly materialising.
            # The original target pose remains authoritative for all rules.
            var weight: float = 1.0 / sqrt(float(maxi(1, pieces[id].size())))
            piece.scale = Vector3(1.06, .70, 1.06)
            piece.rotation = Vector3(.052 * weight, 0.0, -.095 * weight)
            landing_material.set_shader_parameter("impact", .9)
            animator.set_parallel(true)
            animator.tween_property(piece, "scale", Vector3.ONE, .60).set_trans(
                Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
            animator.tween_property(piece, "rotation", Vector3.ZERO, .76).set_trans(
                Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
            animator.tween_property(landing_material, "shader_parameter/impact",
                0.0, .56).set_trans(Tween.TRANS_CUBIC)

## Update one mesh instance while dragging; avoid allocating a new
## node/material on every screen drag event (mobile GPU churn).
func _draw_preview(pos: Vector2i) -> void:
    if pos.x < 0 or pos.y < 0 or completed or selected_id.is_empty():
        preview_cell = Vector2i(-1, -1)
        if ghost.get_child_count() > 0:
            ghost.get_child(0).visible = false
        return
    preview_cell = pos
    var snapped := _snap_placement(selected_id, pos, selected_turns)
    var actual := snapped if snapped.x >= 0 else pos
    var preview_node: Node3D = null
    if ghost.get_child_count() > 0:
        preview_node = ghost.get_child(0) as Node3D
    if preview_node == null or preview_node.name != "Piece_" + selected_id \
            or int(preview_node.get_meta("turns", -1)) != selected_turns:
        for child in ghost.get_children():
            ghost.remove_child(child)
            child.queue_free()
        preview_node = _piece_node(selected_id, pieces[selected_id],
            actual, selected_turns, true)
        preview_node.set_meta("turns", selected_turns)
        ghost.add_child(preview_node)
    preview_node.visible = true
    preview_target = Vector3(actual.y - size / 2.0, .48,
        actual.x - size / 2.0)
    var mat: ShaderMaterial = preview_node.get_child(0).material_override
    mat.set_shader_parameter("candy_tint",
        _preview_tint(selected_id, actual, selected_turns))

func _draw_tray() -> void:
    for child in tray.get_children():
        child.queue_free()
    var ids: Array = pieces.keys()
    ids.sort()
    for candidate in ids:
        var id := String(candidate)
        var tint := Color(PALETTE[id])
        var btn := _button("", tint.darkened(
            .39 if not placements.has(id) else .72))
        btn.custom_minimum_size = Vector2(79, 73)
        if id == selected_id:
            btn.add_theme_stylebox_override("normal", _flat_style(
                tint.darkened(.28), 16, Color("#fdfaff")))
        var miniature := Control.new()
        miniature.name = "ShapeThumbnail"
        miniature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        miniature.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(miniature)
        var cells: Array = pieces[id]
        var widest := 0
        var highest := 0
        for cell in cells:
            widest = maxi(widest, cell.y + 1)
            highest = maxi(highest, cell.x + 1)
        var unit := minf(12.5, minf(58.0 / float(maxi(widest, 1)),
            43.0 / float(maxi(highest, 1))))
        var start_x := (79.0 - float(widest) * unit) * .5
        var start_y := (58.0 - float(highest) * unit) * .5 + 5.0
        for cell in cells:
            var tile := Panel.new()
            tile.position = Vector2(start_x + float(cell.y) * unit,
                start_y + float(cell.x) * unit)
            tile.size = Vector2(unit - .8, unit - .8)
            var style := _flat_style(tint.lightened(.18), 3,
                tint.lightened(.52))
            style.set_border_width_all(1)
            tile.add_theme_stylebox_override("panel", style)
            tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
            miniature.add_child(tile)
        var caption := _label(id, 13, Color(1, 1, 1, .92))
        caption.position = Vector2(58, 2)
        caption.size = Vector2(17, 19)
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        miniature.add_child(caption)
        btn.set_meta("piece_id", id)
        btn.pressed.connect(func(): _select_piece(id))
        tray.add_child(btn)
    # Scroll after GUI layout. Resolve a live button at call time to avoid
    # invoking ensure_control_visible on controls queued for deletion.
    call_deferred("_scroll_to_selected")

func _scroll_to_selected() -> void:
    for child in tray.get_children():
        if child.is_queued_for_deletion():
            continue
        if String(child.get_meta("piece_id", "")) == selected_id:
            tray_scroll.ensure_control_visible(child)
            return

func _select_piece(id: String) -> void:
    _play_feedback("select")
    selected_id = id
    selected_turns = int(placements[id]["turns"]) if placements.has(id) else 0
    _draw_tray()
    _refresh_text()
    if preview_cell.x >= 0:
        _draw_preview(preview_cell)
    _save_progress()
    _save_progress()

func _rotate_piece() -> void:
    if completed or selected_id.is_empty():
        return
    selected_turns = (selected_turns + 1) % 4
    _play_feedback("rotate", 9)
    if preview_cell.x >= 0:
        _draw_preview(preview_cell)
    status_label.text = "Rotation : %d° · touche une case" % (selected_turns * 90)
    _save_progress()
    _save_progress()

func _undo() -> void:
    if undo_history.is_empty():
        return
    _play_feedback("undo", 10)
    var restored: Dictionary = undo_history.pop_back()
    var undone_id := selected_id
    for key in placements:
        var id := String(key)
        if not restored.has(id) or restored[id] != placements[id]:
            undone_id = id
            break
    placements = restored.duplicate(true)
    last_placement = undo_history.back().duplicate(true) if not undo_history.is_empty() else {}
    has_undo_snapshot = not undo_history.is_empty()
    if pieces.has(undone_id):
        selected_id = undone_id
        selected_turns = int(placements[undone_id]["turns"]) if placements.has(undone_id) else 0
    completed = false
    moves += 1
    _rebuild_placements()
    _draw_preview(Vector2i(-1, -1))
    _draw_tray()
    _refresh_text()
    _save_progress()

## Non-destructive hint: locate a valid unplaced target shape.
func _show_hint() -> void:
    if completed:
        return
    var rows: Array = levels[current_level]["rows"]
    var ids: Array = pieces.keys()
    ids.sort()
    for candidate in ids:
        var id := String(candidate)
        if placements.has(id):
            continue
        var origin := Vector2i(size, size)
        for r in range(size):
            for c in range(size):
                if String(rows[r]).substr(c, 1) == id:
                    origin.x = mini(origin.x, r)
                    origin.y = mini(origin.y, c)
        if _can_place(id, origin, 0):
            _play_feedback("hint")
            selected_id = id
            selected_turns = 0
            _draw_tray()
            _draw_preview(origin)
            status_label.text = "Indice : place la forme %s sur le fantôme vert" % id
            _save_progress()
            return
    status_label.text = "Annule ou déplace une brique pour libérer la place"

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

func _board_matches_model() -> bool:
    if occupied.size() != wanted.size():
        return false
    for cell in wanted:
        if occupied.get(cell, "") != wanted[cell]:
            return false
    return true

func _check_win() -> void:
    if not _board_matches_model():
        return
    completed = true
    candy_fx.victory()
    _play_feedback("win", 65)
    if current_level + 1 < levels.size():
        unlocked = maxi(unlocked, current_level + 1)
    _save_progress()
    status_label.text = "BRAVO ! Modèle reconstitué ✦"
    next_button.disabled = current_level + 1 >= levels.size()
    if win_tween != null and win_tween.is_valid():
        win_tween.kill()
    win_tween = create_tween()
    win_tween.tween_property(board, "scale", Vector3(1.045, 1.045, 1.045),
        .20).set_trans(Tween.TRANS_BACK)
    win_tween.tween_property(board, "scale", Vector3.ONE, .32).set_trans(
        Tween.TRANS_ELASTIC)
    # Board cells are intentionally not regenerated: the completed level remains visible.

## A touch is committed only when released, never at finger-down.
## Otherwise the preview would lag behind and dragging could place early.
## Only the finger that started the gesture can drag or release it.
## Secondary fingers must not place jelly or dismiss the first finger's
## preview. Android OS touch cancellations never commit a placement.
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if active_touch_index < 0 and not completed \
                    and _inside_board_input_area(event.position):
                active_touch_index = event.index
                touch_started_on_board = true
                _handle_board_position(event.position, false)
        elif event.index == active_touch_index:
            if touch_started_on_board and not event.canceled:
                _handle_board_position(event.position, true)
            touch_started_on_board = false
            active_touch_index = -1
            _draw_preview(Vector2i(-1, -1))
    elif event is InputEventScreenDrag:
        if touch_started_on_board and event.index == active_touch_index:
            _handle_board_position(event.position, false)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            mouse_started_on_board = active_touch_index < 0 \
                and _inside_board_input_area(event.position)
            if mouse_started_on_board:
                _handle_board_position(event.position, false)
        else:
            if mouse_started_on_board and active_touch_index < 0:
                _handle_board_position(event.position, true)
            mouse_started_on_board = false
            if active_touch_index < 0:
                _draw_preview(Vector2i(-1, -1))
    elif event is InputEventMouseMotion and mouse_started_on_board \
            and active_touch_index < 0:
        _handle_board_position(event.position, false)

func _inside_board_input_area(screen: Vector2) -> bool:
    var viewport_size := get_viewport().get_visible_rect().size
    if screen.x < 0.0 or screen.x > viewport_size.x \
            or screen.y < 0.0 or screen.y > viewport_size.y:
        return false
    # Derive boundaries from actual responsive HUD layout, not percentages
    # of an assumed 720x1280 handset. Reject overlap on small screens.
    if top_panel != null and bottom_panel != null:
        var upper: float = top_panel.get_global_rect().end.y + 5.0
        var lower: float = bottom_panel.get_global_rect().position.y - 5.0
        return lower > upper and screen.y >= upper and screen.y <= lower
    return false


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
