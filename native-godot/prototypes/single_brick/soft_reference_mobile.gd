extends "res://prototypes/single_brick/soft_reference.gd"
## Standalone Android REVIEW app: exactly one dense red 2x1 studio brick.
## Not the shipped game or Physics Lab. All three buttons select genuine
## Godot shader/mesh states; no Blender render is displayed in the app.
const PANEL := Color(0.06, 0.09, 0.15, 0.88)
var mobile_hud: CanvasLayer
var pose_label: Label
var pose_index: int = 0
const POSES := ["rest", "compression", "rebound"]

func _ready() -> void:
    super._ready()
    name = "Red2x1MobileReference"
    mobile_hud = CanvasLayer.new()
    mobile_hud.layer = 20
    add_child(mobile_hud)
    var overlay := Control.new()
    overlay.name = "ReviewOverlay"
    overlay.anchor_right = 1.0
    overlay.anchor_bottom = 1.0
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    mobile_hud.add_child(overlay)
    var title_panel := PanelContainer.new()
    title_panel.name = "Header"
    title_panel.anchor_right = 1.0
    title_panel.offset_left = 20.0
    title_panel.offset_top = 24.0
    title_panel.offset_right = -20.0
    title_panel.offset_bottom = 160.0
    title_panel.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(title_panel)
    var top := VBoxContainer.new()
    top.add_theme_constant_override("separation", 5)
    title_panel.add_child(top)
    top.add_child(_label("JELLY BRICKS   /   REF. GEL 2x1", 25, Color.WHITE))
    pose_label = _label("Brique rouge 3D - au repos", 21, Color("#c0f1d7"))
    pose_label.name = "CurrentPose"
    top.add_child(pose_label)
    top.add_child(_label("Glisser pour tourner la camera", 17, Color("#b5c3df")))
    var buttons_panel := PanelContainer.new()
    buttons_panel.name = "ReviewControls"
    buttons_panel.anchor_top = 1.0
    buttons_panel.anchor_right = 1.0
    buttons_panel.anchor_bottom = 1.0
    buttons_panel.offset_left = 20.0
    buttons_panel.offset_right = -20.0
    buttons_panel.offset_top = -166.0
    buttons_panel.offset_bottom = -18.0
    buttons_panel.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(buttons_panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    buttons_panel.add_child(column)
    column.add_child(_label("ETUDE VISUELLE - 3 ETATS", 18, Color("#c7d6ee")))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 9)
    row.name = "PoseButtons"
    column.add_child(row)
    for i in range(POSES.size()):
        var label: String = ["REPOS", "IMPACT", "REBOND"][i]
        var button := Button.new()
        button.name = "Pose%d" % i
        button.text = label
        button.custom_minimum_size = Vector2(0.0, 64.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size", 22)
        button.pressed.connect(_select_pose.bind(i))
        row.add_child(button)

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.set_corner_radius_all(16)
    style.set_content_margin_all(12)
    return style

func _label(message: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = message
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _select_pose(i: int) -> void:
    pose_index = clampi(i, 0, POSES.size() - 1)
    sample_reference(POSES[pose_index])
    pose_label.text = [
        "Brique rouge 3D - au repos",
        "Compression elastique",
        "Depassement lors du rebond"][pose_index]

func _unhandled_input(event: InputEvent) -> void:
    # The inherited one-brick tap restarts an old scripted trajectory.
    # This review app changes only among the three validated static poses.
    if event is InputEventScreenDrag:
        orbit += event.relative.x * 0.003
        _update_camera()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(
            MOUSE_BUTTON_LEFT):
        orbit += event.relative.x * 0.003
        _update_camera()
    elif event is InputEventScreenTouch and event.pressed:
        _select_pose((pose_index + 1) % POSES.size())
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _select_pose((pose_index + 1) % POSES.size())
