extends "res://prototypes/single_brick/physics_stack.gd"
## Touch-first Android showroom built on the actual rigid-body Jelly prototype.
## It never changes the shipping game scene or package ID.
const INK := Color("#f7f9ff")
const MUTED := Color("#b8c4e1")
const ACCENT := Color("#8cf5bb")
const PANEL := Color(0.048, 0.079, 0.155, 0.91)
const PROFILES := [0.62, 1.0, 1.48]
const NAMES := ["DOUX", "NORMAL", "INTENSE"]
var hud: CanvasLayer
var metrics: Label
var stage_label: Label
var pause_button: Button
var mode_buttons: Array[Button] = []
var current_profile: int = 1
var refresh_elapsed: float = 0.0

func _ready() -> void:
    super._ready()
    _create_hud()
    _highlight_profile()
    _update_metrics()

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.corner_radius_top_left = 18
    style.corner_radius_top_right = 18
    style.corner_radius_bottom_left = 18
    style.corner_radius_bottom_right = 18
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.55, 0.71, 0.91, 0.33)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _label(content: String, size: int, tint: Color) -> Label:
    var l := Label.new()
    l.text = content
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", tint)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l

func _button(content: String) -> Button:
    var b := Button.new()
    b.text = content
    b.custom_minimum_size.y = 56
    b.add_theme_font_size_override("font_size", 21)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.focus_mode = Control.FOCUS_NONE
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#223554")
    normal.set_corner_radius_all(12)
    normal.set_content_margin_all(7)
    var highlighted := normal.duplicate() as StyleBoxFlat
    highlighted.bg_color = Color("#395574")
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#406d70")
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", highlighted)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_color_override("font_color", INK)
    return b

func _create_hud() -> void:
    hud = CanvasLayer.new()
    hud.name = "MobileExperimentControls"
    hud.layer = 20
    add_child(hud)

    # The transparent overlay does NOT swallow touches aimed at the scene.
    # Only opaque top/bottom panels intercept input and their buttons.
    var overlay := Control.new()
    overlay.name = "InteractionOverlay"
    overlay.anchor_right = 1.0
    overlay.anchor_bottom = 1.0
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(overlay)

    var header := PanelContainer.new()
    header.name = "StatusPanel"
    header.anchor_right = 1.0
    header.offset_left = 16.0
    header.offset_top = 18.0
    header.offset_right = -16.0
    header.offset_bottom = 171.0
    header.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(header)
    var upper := VBoxContainer.new()
    upper.add_theme_constant_override("separation", 5)
    header.add_child(upper)
    upper.add_child(_label("JELLY BRICKS  /  LABORATOIRE", 25, INK))
    upper.add_child(_label("Prototype physique interactif", 18, MUTED))
    metrics = _label("", 20, ACCENT)
    metrics.name = "LivePhysicsMetrics"
    upper.add_child(metrics)
    stage_label = _label("Appuyer sur RELANCER pour commencer", 17, MUTED)
    stage_label.name = "SimulationState"
    upper.add_child(stage_label)

    var panel := PanelContainer.new()
    panel.name = "PhysicsControls"
    panel.anchor_top = 1.0
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = 16.0
    panel.offset_top = -254.0
    panel.offset_right = -16.0
    panel.offset_bottom = -14.0
    panel.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(panel)
    var controls := VBoxContainer.new()
    controls.add_theme_constant_override("separation", 9)
    panel.add_child(controls)
    controls.add_child(_label("INTENSITE DE L'IMPACT", 19, MUTED))
    var options := HBoxContainer.new()
    options.add_theme_constant_override("separation", 9)
    controls.add_child(options)
    for i in range(PROFILES.size()):
        var button := _button(NAMES[i])
        button.name = "ImpactPreset%d" % i
        button.pressed.connect(_select_profile.bind(i))
        options.add_child(button)
        mode_buttons.append(button)

    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 9)
    controls.add_child(buttons)
    var replay := _button("RELANCER")
    replay.name = "ReplayImpact"
    replay.pressed.connect(_replay_pressed)
    buttons.add_child(replay)
    pause_button = _button("PAUSE")
    pause_button.name = "PauseImpact"
    pause_button.pressed.connect(_pause_pressed)
    buttons.add_child(pause_button)
    var reset := _button("REPOS")
    reset.name = "ResetImpact"
    reset.pressed.connect(_reset_pressed)
    buttons.add_child(reset)
    controls.add_child(_label("Glisser : tourner  |  Toucher le décor : rejouer",
        17, MUTED))

func _highlight_profile() -> void:
    for i in range(mode_buttons.size()):
        var button: Button = mode_buttons[i]
        var is_selected := i == current_profile
        button.add_theme_color_override("font_color",
            Color("#0e2841") if is_selected else INK)
        var style := StyleBoxFlat.new()
        style.bg_color = ACCENT if is_selected else Color("#223554")
        style.set_corner_radius_all(12)
        style.set_content_margin_all(7)
        button.add_theme_stylebox_override("normal", style)
        button.add_theme_stylebox_override("hover", style)

func _select_profile(i: int) -> void:
    current_profile = clampi(i, 0, PROFILES.size() - 1)
    select_impact_multiplier(PROFILES[current_profile])
    _highlight_profile()
    _replay_pressed()

func _replay_pressed() -> void:
    replay_stack()
    if pause_button != null:
        pause_button.text = "PAUSE"
    _update_metrics()

func _pause_pressed() -> void:
    if not is_simulating:
        return
    set_lab_paused(not paused_by_user)
    pause_button.text = "REPRENDRE" if paused_by_user else "PAUSE"
    _update_metrics()

func _reset_pressed() -> void:
    reset_stack()
    pause_button.text = "PAUSE"
    _update_metrics()

func _update_metrics() -> void:
    if metrics == null:
        return
    var fps := Engine.get_frames_per_second()
    metrics.text = "CONTACTS  %d    ANGLE  %.0f°    FPS  %d" % [
        interbrick_contacts, peak_tilt_degrees, fps]
    if paused_by_user:
        stage_label.text = "Simulation en pause"
    elif not is_simulating:
        stage_label.text = "Au repos · choisir une intensité"
    else:
        stage_label.text = "Chute physique en cours · %s" % NAMES[current_profile]

func _process(delta: float) -> void:
    super._process(delta)
    refresh_elapsed += maxf(0.0, delta)
    if refresh_elapsed >= 0.25:
        refresh_elapsed = 0.0
        _update_metrics()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_simulating:
        # Avoid a giant stale physics impulse after an Android app switch.
        set_lab_paused(true)
        if pause_button != null:
            pause_button.text = "REPRENDRE"
        _update_metrics()
