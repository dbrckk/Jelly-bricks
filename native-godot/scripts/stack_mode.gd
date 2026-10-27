extends Node3D
## Separate, playable 3D candy-brick stacking studio.
## Godot 4.6 Compatibility: authored gel meshes, no paid assets, no GPU physics.
## A deterministic support rule makes stacks stable and undoable on Android.
const GEL = preload("res://scripts/gel_mesh.gd")
const SHADER = preload("res://shaders/jelly.gdshader")
const SAVE_TRANSFER = preload("res://scripts/save_transfer.gd")
const FIGURES = preload("res://scripts/figure_challenges.gd")
const SAVE_PATH := "user://jelly-stack-v1.json"
const GRID := 6
# The 0.55 step with a 0.21-deep underside socket seats the next molded
# shell only 0.045 units above the lower crown (formerly 0.095). The
# supporting tenon still has 0.017 units of headroom under the socket roof.
# The deterministic occupancy stays unchanged: only the rendered poses move.
const STEP := .55
const MAX_LAYERS := 9
const MAX_BRICKS := 32
# An actual shadow atlas is worth its GPU cost only on small photo scenes.
# Construction gameplay and large towers keep fixed-cost fake contacts.
const MAX_GALLERY_SHADOW_BRICKS := 14
# At most 18 extra lacquer body passes per frame on OpenGL ES.
# The base Jelly shader remains glossy on all 32 bricks; prioritize the
# newest/topmost bricks where the player's eye focuses. The 12-brick
# reference tower is always fully coated.
const MAX_GALLERY_COATED_BRICKS := 18
# Video reference palette: ruby red, saturated cobalt, spring green,
# golden yellow and orange-red. The earlier pastel-pink and mint-green
# materials looked like soft soap rather than strongly dyed gelatin.
# Calibrated against actual RGB samples in the supplied 2824.mp4
# glossy/reference upper pane and Mesa screenshot of the same color families.
# The compatibility shader darkens saturated front walls substantially:
# favor pure emerald/royal pigments rather than pink/teal pastel input.
const COLORS := ["#fa2d22", "#3951eb", "#12f128", "#ffca40", "#ff5930"]
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
var preview_signature: String = ""
# One short GPU jelly impulse when a finger drags the placement preview.
# Only the moving ghost receives per-frame uniform updates; all 32 resting
# bricks remain on the cheap idle shader path.
var preview_motion_energy: float = 0.0
# Local X/Z impulse from actual cell movement, clamped for fast swipes.
# This is visual inertia only: occupancy and the saved target never move.
var preview_drag_bend: Vector2 = Vector2.ZERO
var preview_target: Vector3
var brick_nodes: Array[Node3D] = []
# Single shared authored stud mesh; all 32 studio bricks still use
# MultiMesh batching rather than allocating individual cylinders.
var studio_stud_mesh: ArrayMesh
var motion_tweens: Array[Tween] = []
var contact_material: ShaderMaterial
var caustic_batch: MultiMeshInstance3D
# No transmitted floor glow until a newly placed brick really lands.
# -1 means every persisted ground brick is already at rest.
var pending_caustic_index: int = -1
var gallery_coat: ShaderMaterial
var gallery_shadow_material: StandardMaterial3D
var gallery_shadow_key: DirectionalLight3D
var photo_layer: CanvasLayer
var photo_mode: bool = false
var photo_paused: bool = false
var photo_pause_button: Button
# Give players time to inspect their chosen camera angle after a gesture.
const PHOTO_GESTURE_COOLDOWN := 2.5
var photo_resume_wait: float = 0.0
var gallery_demo_button: Button
var gallery_demo_root: Node3D
var gallery_demo_active: bool = false
# Preserve the user's exact orbit and pinch zoom when opening the
# front-facing reference display. The demo has its own editorial angle.
var gallery_user_angle: float = 0.0
var gallery_user_zoom: float = 1.0
var gallery_demo_entries: Array[Dictionary] = []
var gallery_demo_nodes: Array[Node3D] = []
# Phase of the reference tower's coherent gel-like sway. The loose floor
# pieces remain fixed, and no user save or occupancy cell is ever moved.
var gallery_sway_time: float = 0.0
# Optional cinematic falling-brick replay, on twelve temporary reference
# nodes ONLY. The real editor bricks, occupancy and save never participate.
# An analytic timeline keeps the cost bounded and reproducible on Android.
var gallery_fall_button: Button
var gallery_fall_active: bool = false
var gallery_fall_finished: bool = false
var gallery_fall_time: float = 0.0
const GALLERY_FALL_DURATION := 3.1
var photo_angle: float = .0
var photo_zoom: float = 1.0
var photo_touch_points: Dictionary = {}
var photo_pinch_span: float = 0.0
var photo_mouse_drag: bool = false
var photo_floor_before: float = -.56
var scene_root: Node3D
var mesh_cache: Dictionary = {}
# Flat contact patches have only six possible footprints. Share their
# GPU mesh resources across all pieces instead of allocating one per brick.
var contact_mesh_cache: Dictionary = {}
var hud: CanvasLayer
var top_controls: VBoxContainer
var bottom_controls: VBoxContainer
var title_label: Label
var status_label: Label
var color_buttons: Array[Button] = []
var length_buttons: Array[Button] = []
var active_touch_index: int = -1
# The first finger owns a drag, but a second contact turns the gesture
# into an abandoned multitouch gesture, never an accidental Jelly drop.
var play_touch_contacts: Dictionary = {}
var play_multitouch_blocked: bool = false
var mouse_held: bool = false
var reset_confirmation: ConfirmationDialog
var camera_mode: int = 0
var camera_button: Button
var figure_active: bool = false
var figure_index: int = 0
var figure_progress: Dictionary = {}
var figure_target_label: Label
var figure_button: Button
var figure_next_button: Button
var figure_model_dialog: AcceptDialog
var figure_model_text: RichTextLabel
var figure_model_button: Button
var figure_mini_row: HBoxContainer
var figure_mini_cells: Array[ColorRect] = []
var figure_selector: OptionButton
var figure_cleared: bool = false
var figure_victory_dialog: AcceptDialog
var figure_share_text: String = ""

func _ready() -> void:
    name = "FreeStackStudio"
    _build_scene()
    _build_hud()
    figure_progress = FIGURES.load_progress()
    _restore_or_seed()
    _rebuild()
    set_active(false)

func set_active(enabled: bool) -> void:
    active = enabled
    visible = enabled
    if not enabled and photo_mode:
        # Switching back to puzzles must never leave the player construction
        # hidden behind a temporary Gallery example.
        _clear_gallery_demo()
        _set_photo_environment(false)
        photo_mode = false
        _set_gallery_coat(false)
        _clear_photo_gestures()
    hud.visible = enabled and not photo_mode
    photo_layer.visible = enabled and photo_mode
    if enabled:
        _apply_camera()
        _refresh_preview()
        _refresh_labels()
    else:
        _reset_preview_inertia()
        active_touch_index = -1
        play_touch_contacts.clear()
        play_multitouch_blocked = false
        mouse_held = false

func _process(delta: float) -> void:
    if not active:
        return
    if photo_mode:
        # Freeze means no per-frame camera transform, orbit, or decorative
        # studio animation. Touch/pinch handlers still update the camera
        # directly, so inspection of a paused sculpture remains interactive.
        if photo_paused:
            return
        # The reference's soft tower sways very slightly under its own
        # elasticity, without changing physics, stack validation, or saves.
        # Pause freezes both the camera and the actual 3D demo geometry.
        if gallery_demo_active and not photo_paused \
                and photo_touch_points.is_empty() and not photo_mouse_drag:
            if gallery_fall_active:
                _animate_gallery_fall(minf(maxf(delta, 0.0), .25))
            elif not gallery_fall_finished:
                _animate_gallery_sway(minf(maxf(delta, 0.0), .25))
        # Use elapsed time instead of silently slowing the orbit on 15 FPS
        # Android devices. Bound exceptional frame stalls, not normal frames.
        if not photo_paused and photo_touch_points.is_empty() and not photo_mouse_drag:
            # Consume the cooldown using actual elapsed time, then orbit only
            # for the frame's remainder. Never jump on slower Android frames.
            var remaining: float = maxf(0.0, delta)
            if photo_resume_wait > 0.0:
                var idle_elapsed: float = minf(remaining, photo_resume_wait)
                photo_resume_wait -= idle_elapsed
                remaining -= idle_elapsed
            if remaining > 0.0:
                photo_angle = fposmod(photo_angle + minf(remaining, .25) * .14, TAU)
        _update_photo_camera()
        return
    if preview_node != null and preview_node.visible:
        var step: float = minf(maxf(delta, 0.0), .1)
        var t: float = 1.0 - exp(-step * 20.0)
        preview_node.position = preview_node.position.lerp(preview_target, t)
        if preview_motion_energy > 0.0 or preview_drag_bend.length_squared() > .000001:
            var ghost_paint: ShaderMaterial = preview_node.get_node(
                "GelBody").material_override
            if preview_motion_energy > 0.0:
                # Damped liquid inertia: multiplicative decay remains
                # stable at 30/60/120 FPS and across short Android stalls.
                # GDQuest's pinned Godot liquid demo inspired the damping
                # approach; the implementation and shader remain ours.
                preview_motion_energy *= exp(-step * 5.5)
                if preview_motion_energy < .008:
                    preview_motion_energy = 0.0
                ghost_paint.set_shader_parameter("gel_spring",
                    preview_motion_energy)
            if preview_drag_bend.length_squared() > .000001:
                preview_drag_bend *= exp(-step * 9.0)
                if preview_drag_bend.length_squared() < .00005:
                    preview_drag_bend = Vector2.ZERO
                ghost_paint.set_shader_parameter("studio_drag",
                    preview_drag_bend)

func _build_scene() -> void:
    studio_stud_mesh = GEL.build_studio_stud()
    contact_material = ShaderMaterial.new()
    contact_material.shader = preload("res://shaders/contact_shadow.gdshader")
    contact_material.set_shader_parameter("strength", .35)
    gallery_coat = ShaderMaterial.new()
    gallery_coat.shader = preload("res://shaders/studio_clearcoat.gdshader")
    gallery_shadow_material = StandardMaterial3D.new()
    gallery_shadow_material.albedo_color = Color.WHITE
    gallery_shadow_material.roughness = .95
    scene_root = Node3D.new()
    scene_root.name = "CandyStackStage"
    add_child(scene_root)
    # Colored transmission from ground-contact jelly: a single shared
    # MultiMesh for all ground pieces, with per-instance colors. The pool
    # stays alive when the tower is rebuilt, reset or moved into Gallery.
    var caustic_instances := MultiMesh.new()
    caustic_instances.transform_format = MultiMesh.TRANSFORM_3D
    caustic_instances.use_colors = true
    var caustic_quad := PlaneMesh.new()
    caustic_quad.size = Vector2.ONE
    caustic_instances.mesh = caustic_quad
    caustic_instances.instance_count = 0
    caustic_batch = MultiMeshInstance3D.new()
    caustic_batch.name = "CandyLightTransmission"
    caustic_batch.multimesh = caustic_instances
    var caustic_paint := ShaderMaterial.new()
    caustic_paint.shader = preload("res://shaders/studio_caustics.gdshader")
    # Match subdued construction light and richer photographic caustics.
    # There is still only ONE persistent instanced light-transmission draw.
    caustic_paint.set_shader_parameter("transmission_energy", .74)
    caustic_batch.material_override = caustic_paint
    caustic_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene_root.add_child(caustic_batch)
    # One real directional shadow pass, hidden outside the Gallery.
    # The gallery shadow casters share existing rounded brick meshes.
    # No rigid body or CPU ray tracing; physically grounded, soft contacts.
    gallery_shadow_key = DirectionalLight3D.new()
    gallery_shadow_key.name = "GalleryShadowKey"
    gallery_shadow_key.light_color = Color("#fff5eb")
    gallery_shadow_key.light_energy = .40
    gallery_shadow_key.shadow_enabled = true
    gallery_shadow_key.position = Vector3(-7.0, 12.0, 8.0)
    scene_root.add_child(gallery_shadow_key)
    gallery_shadow_key.look_at(Vector3(0.0, 1.5, 0.0))
    gallery_shadow_key.visible = false
    var plinth := MeshInstance3D.new()
    plinth.name = "SatinPlinth"
    # Full square footprint beneath the 6x6 authored stacking area;
    # previous cylindrical plinth left permitted corner cells floating.
    var geometry := BoxMesh.new()
    geometry.size = Vector3(6.24, .16, 6.24)
    plinth.mesh = geometry
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#eef0f4")
    material.roughness = .75
    material.metallic = .0
    plinth.material_override = material
    plinth.position.y = -.38
    plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene_root.add_child(plinth)
    # One persistent small pedestal edge and one feathered contact pool
    # ground the whole sculpture. No new runtime shadows per animation.
    var base_edge := MeshInstance3D.new()
    base_edge.name = "SatinPlinthEdge"
    var trim_mesh := BoxMesh.new()
    trim_mesh.size = Vector3(6.35, .12, 6.35)
    base_edge.mesh = trim_mesh
    var trim_paint := StandardMaterial3D.new()
    trim_paint.albedo_color = Color("#e3e8ef")
    trim_paint.roughness = .82
    base_edge.material_override = trim_paint
    base_edge.position.y = -.50
    base_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene_root.add_child(base_edge)

    var ground := MeshInstance3D.new()
    ground.name = "StudioGroundContact"
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(8.5, 8.5)
    ground.mesh = ground_mesh
    var ground_shade := ShaderMaterial.new()
    ground_shade.shader = preload("res://shaders/contact_shadow.gdshader")
    ground_shade.set_shader_parameter("strength", .24)
    ground.material_override = ground_shade
    ground.position.y = -.545
    ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene_root.add_child(ground)

func _make_button(text_value: String, tint: Color) -> Button:
    var button := Button.new()
    button.text = text_value
    button.set_meta("jelly_base_tint", tint)
    button.custom_minimum_size = Vector2(84, 56)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", Color.WHITE)
    var style := StyleBoxFlat.new()
    style.bg_color = tint
    style.set_corner_radius_all(16)
    style.border_color = tint.lightened(.17)
    style.set_border_width_all(1)
    style.shadow_color = Color(.09, .16, .27, .16)
    style.shadow_size = 3
    style.content_margin_left = 8
    style.content_margin_right = 8
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    button.add_theme_stylebox_override("normal", style)
    var pressed_style: StyleBoxFlat = style.duplicate() as StyleBoxFlat
    pressed_style.bg_color = tint.darkened(.18)
    pressed_style.shadow_size = 1
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
    var heading := _make_label("J E L L Y   S T U D I O · v%s" %
        host.APP_VERSION, 19, Color("#34465e"))
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nav.add_child(heading)
    title_label = _make_label("Empilage libre", 19, Color("#4b6178"))
    top_controls.add_child(title_label)
    figure_target_label = _make_label("", 15, Color("#415d79"))
    top_controls.add_child(figure_target_label)
    var figure_actions := HBoxContainer.new()
    figure_actions.add_theme_constant_override("separation", 8)
    top_controls.add_child(figure_actions)
    figure_button = _make_button("Défis · 20 figures", Color("#6b5fa6"))
    figure_button.pressed.connect(_toggle_figures)
    figure_actions.add_child(figure_button)
    figure_next_button = _make_button("Valider", Color("#218f7c"))
    figure_next_button.pressed.connect(_validate_figure)
    figure_actions.add_child(figure_next_button)
    figure_next_button.visible = false
    figure_model_button = _make_button("Modèle", Color("#506d92"))
    figure_model_button.pressed.connect(_show_figure_model)
    figure_actions.add_child(figure_model_button)
    figure_model_button.visible = false
    # Permanent mini-model: players no longer have to memorize a 6×6
    # picture hidden inside a modal before every placement.
    figure_mini_row = HBoxContainer.new()
    figure_mini_row.add_theme_constant_override("separation", 15)
    top_controls.add_child(figure_mini_row)
    var mini := GridContainer.new()
    mini.columns = 6
    mini.add_theme_constant_override("h_separation", 2)
    mini.add_theme_constant_override("v_separation", 2)
    figure_mini_row.add_child(mini)
    for idx in range(36):
        var tile := ColorRect.new()
        tile.color = Color("#eff2f7")
        tile.custom_minimum_size = Vector2(15, 15)
        tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mini.add_child(tile)
        figure_mini_cells.append(tile)
    var legend := VBoxContainer.new()
    figure_mini_row.add_child(legend)
    legend.add_child(_make_label("Cible 6 × 6", 14, Color("#506478")))
    figure_selector = OptionButton.new()
    figure_selector.custom_minimum_size = Vector2(180, 39)
    figure_selector.add_theme_font_size_override("font_size", 14)
    figure_selector.item_selected.connect(_select_figure)
    legend.add_child(figure_selector)
    figure_mini_row.visible = false
    figure_model_dialog = AcceptDialog.new()
    figure_model_dialog.title = "Modèle à reproduire"
    figure_model_dialog.min_size = Vector2i(330, 420)
    figure_model_text = RichTextLabel.new()
    figure_model_text.bbcode_enabled = true
    figure_model_text.fit_content = true
    figure_model_text.custom_minimum_size = Vector2(300, 320)
    figure_model_text.add_theme_font_size_override("normal_font_size", 25)
    figure_model_dialog.add_child(figure_model_text)
    add_child(figure_model_dialog)
    figure_victory_dialog = AcceptDialog.new()
    figure_victory_dialog.title = "Sculpture terminée !"
    figure_victory_dialog.ok_button_text = "Continuer"
    figure_victory_dialog.min_size = Vector2i(360, 230)
    figure_victory_dialog.confirmed.connect(_next_figure)
    figure_victory_dialog.add_button(
        "Copier le résultat", false, "copy").pressed.connect(_share_figure)
    add_child(figure_victory_dialog)

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
    camera_button = _make_button("Vue 3D", Color("#58728c"))
    camera_button.custom_minimum_size.y = 45
    camera_button.pressed.connect(_cycle_camera)
    length_row.add_child(camera_button)
    var photo_button := _make_button("Photo", Color("#4d6d73"))
    photo_button.custom_minimum_size.y = 45
    photo_button.pressed.connect(_enter_photo_mode)
    length_row.add_child(photo_button)

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
    # Cinematic gallery UI is a separate overlay. Hiding the full editor
    # never hides its own close control or traps the player.
    photo_layer = CanvasLayer.new()
    photo_layer.name = "GalleryHud"
    photo_layer.layer = 9
    add_child(photo_layer)
    var photo_surface := Control.new()
    photo_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    photo_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    photo_layer.add_child(photo_surface)
    var photo_header := HBoxContainer.new()
    photo_header.name = "GalleryHeader"
    photo_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    photo_header.offset_left = 26
    photo_header.offset_right = -26
    photo_header.offset_top = 24
    photo_header.offset_bottom = 80
    photo_surface.add_child(photo_header)
    var photo_brand := _make_label("J E L L Y   B R I C K S", 21, Color("#45546a"))
    photo_brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    photo_header.add_child(photo_brand)
    var close_gallery := _make_button("✕ Fermer", Color("#4d6177"))
    close_gallery.name = "CloseGallery"
    # Gallery controls should occupy only a small corner, not half of the
    # screenshot. Maintain a large enough touch target on narrow phones.
    close_gallery.size_flags_horizontal = Control.SIZE_SHRINK_END
    close_gallery.custom_minimum_size = Vector2(124, 46)
    close_gallery.add_theme_font_size_override("font_size", 16)
    close_gallery.pressed.connect(_leave_photo_mode)
    photo_header.add_child(close_gallery)
    photo_pause_button = _make_button("⏸ Pause", Color("#4d6177"))
    photo_pause_button.name = "PauseGallery"
    # Default Button EXPAND caused a 200px pill in our real portrait QA.
    # Reserve that width for the actual sculpture instead of photo chrome.
    photo_pause_button.size_flags_horizontal = Control.SIZE_SHRINK_END
    photo_pause_button.custom_minimum_size = Vector2(116, 46)
    photo_pause_button.add_theme_font_size_override("font_size", 16)
    photo_pause_button.pressed.connect(_toggle_photo_pause)
    photo_header.add_child(photo_pause_button)
    gallery_demo_button = _make_button("Vitrine", Color("#54736d"))
    gallery_demo_button.name = "ReferenceGallery"
    gallery_demo_button.size_flags_horizontal = Control.SIZE_SHRINK_END
    gallery_demo_button.custom_minimum_size = Vector2(120, 46)
    gallery_demo_button.add_theme_font_size_override("font_size", 16)
    gallery_demo_button.pressed.connect(_toggle_gallery_demo)
    photo_header.add_child(gallery_demo_button)
    # The replay control lives BELOW the hero image, not in the already
    # crowded four-button header. It is visible only in Vitrine mode.
    gallery_fall_button = _make_button("↘ Chute", Color("#d36d57"))
    gallery_fall_button.name = "GalleryFallReplay"
    gallery_fall_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    gallery_fall_button.offset_left = -183
    gallery_fall_button.offset_right = -26
    gallery_fall_button.offset_top = -91
    gallery_fall_button.offset_bottom = -31
    gallery_fall_button.custom_minimum_size = Vector2(157, 54)
    gallery_fall_button.add_theme_font_size_override("font_size", 18)
    gallery_fall_button.visible = false
    gallery_fall_button.pressed.connect(_start_gallery_fall)
    photo_surface.add_child(gallery_fall_button)
    photo_layer.visible = false
    _update_selection()

## Match the highlighted colors to the actual glossy candy selection.
## A clear outline, raised shadow and persistent press style make selected
## colors and lengths legible on the phone without extra labels, icons or UI
## texture atlases. Only called when the selection changes, not per frame.
func _style_selection(button: Button, chosen: bool) -> void:
    var base: Color = button.get_meta("jelly_base_tint")
    var face: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
    face.bg_color = base if chosen else base.darkened(.12)
    face.border_color = Color(1.0, .99, .93, .96) if chosen else base.lightened(.11)
    face.set_border_width_all(3 if chosen else 1)
    face.shadow_color = Color(.10, .17, .26, .28 if chosen else .12)
    face.shadow_size = 6 if chosen else 2
    button.add_theme_stylebox_override("normal", face)
    var pressed: StyleBoxFlat = face.duplicate() as StyleBoxFlat
    pressed.bg_color = face.bg_color.darkened(.16)
    pressed.shadow_size = 1
    button.add_theme_stylebox_override("pressed", pressed)

func _update_selection() -> void:
    for idx in range(color_buttons.size()):
        var chosen: bool = idx == selected_color
        color_buttons[idx].text = "✓" if chosen else "●"
        _style_selection(color_buttons[idx], chosen)
    for idx in range(length_buttons.size()):
        var chosen: bool = idx == selected_length
        _style_selection(length_buttons[idx], chosen)
        length_buttons[idx].modulate = Color.WHITE

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

## Three deliberate product-camera framings. All use the same
## Godot orthographic camera; touch raycasting remains exact in every view.
func _apply_camera() -> void:
    if host == null or host.camera == null:
        return
    var presets: Array[Vector3] = [
        Vector3(6.5, 8.5, 12.7),
        Vector3(-9.5, 6.2, 10.2),
        Vector3(5.2, 13.5, 4.2)
    ]
    # Auto-frame tall towers instead of clipping the 7th-9th layer.
    # The original showcase composition remains unchanged at low height.
    var stack_height: float = .8
    for entry in bricks:
        stack_height = maxf(stack_height,
            float(int(entry["layer"]) + 1) * STEP + .50)
    # Keep the sculpture centered within the usable space BETWEEN the
    # top label and bottom touch controls. Framing at y>=1.6 pointed
    # above short towers: the real Android screenshot showed an enormous
    # blank upper area and a pile squeezed against the action buttons.
    # Preserve the same perspective vector so screen-space touch picking
    # stays consistent. Raise the aim smoothly as the tower grows.
    var target_height: float = maxf(.75, stack_height * .40 - .30)
    host.camera.position = presets[camera_mode] + Vector3(
        0.0, target_height - 1.6, 0.0)
    # Only the default 3/4 and side product views tighten slightly.
    # The overhead view keeps its established 11.20 minimum for tapping
    # outside corner cells; a 9-layer construction still zooms back out.
    host.camera.size = maxf(9.90 if camera_mode != 2 else 11.20,
        stack_height * 1.48 + 5.20)
    host.camera.look_at(Vector3(0.0, target_height, 0.0))
    if camera_button != null:
        camera_button.text = ["Vue 3D", "Vue côté", "Vue dessus"][camera_mode]

func _cycle_camera() -> void:
    camera_mode = (camera_mode + 1) % 3
    _apply_camera()
    host._play_feedback("rotate", 8)

## Create photographic meshes only on demand. Previously every one
## of 32 interactive pieces allocated 3 invisible GeometryInstance3Ds
## (96 nodes) even if the player never opened Gallery. The in-game
## GelBody, GelStuds and GelContact remain exactly the same. Gallery
## caps are applied BEFORE creation, so a 32-piece photo allocates only
## the newest 18 body coats and no stud coats or shadow casters.
## Repeated Gallery visits reuse any previously allocated instances.
func _ensure_gallery_geometry(brick: Node3D, body: bool,
        studs: bool, shadow: bool) -> void:
    var original_body: MeshInstance3D = brick.get_node("GelBody")
    if body and brick.get_node_or_null("OpticalBody") == null:
        var coat := MeshInstance3D.new()
        coat.name = "OpticalBody"
        coat.mesh = original_body.mesh
        coat.material_override = gallery_coat
        # Photo lacquer follows the exact same long brick's bounds,
        # not its lower-left corner. The two passes share a sort pivot.
        coat.sorting_use_aabb_center = true
        coat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        coat.visible = false
        brick.add_child(coat)
    if studs and brick.get_node_or_null("OpticalStuds") == null:
        var original_studs: MultiMeshInstance3D = brick.get_node("GelStuds")
        var stud_coat := MultiMeshInstance3D.new()
        stud_coat.name = "OpticalStuds"
        stud_coat.multimesh = original_studs.multimesh
        stud_coat.material_override = gallery_coat
        stud_coat.sorting_use_aabb_center = true
        stud_coat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        stud_coat.visible = false
        brick.add_child(stud_coat)
    if shadow and brick.get_node_or_null("PhotoShadowCaster") == null:
        var caster := MeshInstance3D.new()
        caster.name = "PhotoShadowCaster"
        caster.mesh = original_body.mesh
        caster.material_override = gallery_shadow_material
        caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
        caster.visible = false
        brick.add_child(caster)

## Optical clear coat is an extra draw *only* in Gallery mode.
## All nodes share the SAME two existing meshes and one ShaderMaterial.
## Bound sidewall/stud overdraw on a fully occupied Android photo stage.
func _set_gallery_coat(enabled: bool) -> void:
    var total: int = brick_nodes.size()
    var coated_from: int = maxi(0, total - MAX_GALLERY_COATED_BRICKS)
    for index in range(total):
        var brick: Node3D = brick_nodes[index]
        if not is_instance_valid(brick):
            continue
        var body_paint: ShaderMaterial = brick.get_node("GelBody").material_override
        body_paint.set_shader_parameter("optical_depth", .93 if enabled else .54)
        body_paint.set_shader_parameter("gel_depth_optics", .90 if enabled else .78)
        body_paint.set_shader_parameter("studio_light_card", 1.0 if enabled else .88)
        body_paint.set_shader_parameter("studio_interlock", 1.0 if enabled else .84)
        body_paint.set_shader_parameter("studio_transmission", 1.0 if enabled else .86)
        var needs_body: bool = enabled and index >= coated_from
        var needs_studs: bool = enabled and total <= MAX_GALLERY_COATED_BRICKS
        var needs_shadow: bool = enabled and total <= MAX_GALLERY_SHADOW_BRICKS
        if enabled:
            _ensure_gallery_geometry(brick, needs_body, needs_studs, needs_shadow)
        var body_coat: MeshInstance3D = brick.get_node_or_null("OpticalBody")
        var stud_coat: MultiMeshInstance3D = brick.get_node_or_null("OpticalStuds")
        var caster: MeshInstance3D = brick.get_node_or_null("PhotoShadowCaster")
        if body_coat != null:
            body_coat.visible = needs_body
        if stud_coat != null:
            stud_coat.visible = needs_studs
        if caster != null:
            caster.visible = needs_shadow
    gallery_shadow_key.visible = enabled and total <= MAX_GALLERY_SHADOW_BRICKS

## Match a white product photography cyclorama while in Photo mode.
## Replace the massive pedestal with the existing continuous matte floor,
## raised exactly to brick-bottom height. The normal editor still shows
## its familiar plinth and stage.
func _set_photo_environment(enabled: bool) -> void:
    var cyclorama: MeshInstance3D = host.get_node("StudioCyclorama")
    var plinth: MeshInstance3D = scene_root.get_node("SatinPlinth")
    var edge: MeshInstance3D = scene_root.get_node("SatinPlinthEdge")
    var base_contact: MeshInstance3D = scene_root.get_node("StudioGroundContact")
    # Enhance the genuine contact patches in the bright seamless gallery.
    # This is one already-shared ShaderMaterial, never an extra draw call.
    contact_material.set_shader_parameter("strength",
        .44 if enabled else .35)
    var caustic_paint: ShaderMaterial = caustic_batch.material_override
    caustic_paint.set_shader_parameter("transmission_energy",
        1.0 if enabled else .74)
    if enabled:
        photo_floor_before = cyclorama.position.y
        cyclorama.position.y = -.30
        plinth.visible = false
        edge.visible = false
        # The white cyclorama can saturate the light-map receiver under
        # bright studio lights. Keep an inexpensive soft grounding contact
        # visible as the reliable ambient-occlusion component at ALL sizes.
        # Small galleries additionally receive real cast shadows; big
        # galleries use only this single procedural patch.
        base_contact.visible = true
        base_contact.position.y = -.297
        var shadow_paint: ShaderMaterial = base_contact.material_override
        shadow_paint.set_shader_parameter("strength", .37)
    else:
        cyclorama.position.y = photo_floor_before
        plinth.visible = true
        edge.visible = true
        base_contact.visible = true
        base_contact.position.y = -.545
        var shadow_paint: ShaderMaterial = base_contact.material_override
        shadow_paint.set_shader_parameter("strength", .24)

## Authored gallery composition inspired by the supplied physical
## Jelly Bricks reference: a real nine-floor interlocking tower plus
## three loose candies. It uses the *same* native 3D meshes and materials
## as gameplay, never the player save. This data passes the existing
## portable studio structural validator before being displayed.
func _gallery_reference_entries() -> Array[Dictionary]:
    var specifications := [
        [2, 1, 2, 0, 0, 0], # Red three-cell footing
        [2, 1, 1, 0, 3, 1], # Yellow bridge on red
        [2, 1, 2, 0, 1, 2], # Blue long crossbar
        [2, 2, 1, 0, 2, 3], # Green support
        [2, 2, 2, 0, 0, 4], # Red three-cell crossbar
        [2, 2, 1, 0, 3, 5], # Yellow cushion
        [2, 2, 1, 0, 1, 6], # Blue double
        [2, 2, 2, 0, 2, 7], # Green three-cell bridge
        [2, 2, 1, 0, 0, 8], # Red double crown
        # Three independent foreground bricks, spaced across the lower
        # photographic frame instead of clipping an orange block at the
        # left border or hiding the yellow block behind the tower.
        [4, 0, 0, 0, 3, 0], # Loose yellow at camera-left foreground
        [4, 4, 1, 0, 4, 0], # Loose tangerine at camera-right foreground
        [5, 2, 0, 0, 0, 0]  # Loose coral near the center foreground
    ]
    var entries: Array[Dictionary] = []
    for spec in specifications:
        entries.append(_entry(int(spec[0]), int(spec[1]),
            int(spec[2]), int(spec[3]), int(spec[4]), int(spec[5])))
    return entries

func _ensure_gallery_demo() -> bool:
    if gallery_demo_root != null:
        return true
    var validation: Dictionary = SAVE_TRANSFER.validate_studio(
        _gallery_reference_entries())
    if not validation.get("ok", false):
        push_error("Reference gallery demo has impossible stacking supports")
        return false
    gallery_demo_entries.clear()
    gallery_demo_nodes.clear()
    gallery_demo_root = Node3D.new()
    gallery_demo_root.name = "GalleryReferenceTower"
    gallery_demo_root.visible = false
    scene_root.add_child(gallery_demo_root)
    for item in validation["bricks"]:
        var entry: Dictionary = item
        gallery_demo_entries.append(entry)
        var piece: Node3D = _build_piece(entry, false)
        piece.position = _world_position(entry)
        gallery_demo_root.add_child(piece)
        var pigment: ShaderMaterial = piece.get_node("GelBody").material_override
        pigment.set_shader_parameter("optical_depth", .93)
        pigment.set_shader_parameter("gel_depth_optics", .90)
        pigment.set_shader_parameter("studio_light_card", 1.0)
        pigment.set_shader_parameter("studio_interlock", 1.0)
        pigment.set_shader_parameter("studio_transmission", 1.0)
        _ensure_gallery_geometry(piece, true, true, true)
        piece.get_node("OpticalBody").visible = true
        piece.get_node("OpticalStuds").visible = true
        piece.get_node("PhotoShadowCaster").visible = true
        gallery_demo_nodes.append(piece)
    _refresh_contact_optics(gallery_demo_entries, gallery_demo_nodes)
    return true

## Reference-only tower movement: coherent low-frequency sway, anchored
## exactly at layer 0. The displacement grows gradually through the nine
## real supported levels rather than randomly vibrating each brick.
## Just 12 cached Node3D transforms, no GPU particles, no rigid bodies,
## no mesh rebuilds and no extra Android draw calls. Analytic motion is
## frame-rate independent and paused when the photo is paused or touched.
func _animate_gallery_sway(elapsed: float) -> void:
    if gallery_demo_root == null or not gallery_demo_active:
        return
    gallery_sway_time = fposmod(gallery_sway_time +
        minf(maxf(elapsed, 0.0), .25), TAU * 25.0)
    var main_wave: float = sin(gallery_sway_time * 1.8)
    var cross_wave: float = sin(gallery_sway_time * 1.24)
    for index in range(gallery_demo_nodes.size()):
        var piece: Node3D = gallery_demo_nodes[index]
        var item: Dictionary = gallery_demo_entries[index]
        var elevation: float = clampf(float(int(item["layer"])) /
            float(MAX_LAYERS - 1), 0.0, 1.0)
        # Quadratic stiffness profile: the bottom remains precisely
        # planted while the top can lean only ~8 cm in a 6 m tower.
        var bend: float = elevation * elevation
        piece.position = _world_position(item) + Vector3(
            .033 * bend * main_wave, 0.0,
            .017 * bend * cross_wave)
        piece.rotation = Vector3(0.0, 0.0,
            .004 * bend * main_wave)
        # The reference tower is JELLY, not a rigid stack that merely
        # rotates. Make each softened tier gently change volume with the
        # same coherent sway. Only 9 demo bricks receive a uniform update;
        # foreground loose bricks remain geometrically untouched.
        var photo_paint: ShaderMaterial = piece.get_node(
            "GelBody").material_override
        photo_paint.set_shader_parameter("studio_squash",
            .055 * bend * sin(gallery_sway_time * 1.8 + .85))

## Video-inspired optional topple demo. These are deterministic visual
## trajectories, not a fake claim of a rigid-body physics simulation.
## They NEVER modify the player's construction or run in stacking mode.
## A single 3.1s timeline rotates and drops only the nine stacked candy
## blocks. Three loose foreground blocks and the real tower base stay put.
## The rotated box is kept above the white floor using an analytic
## orientation-dependent extent, including the physical studs.
func _apply_gallery_fall(seconds: float) -> void:
    if not gallery_demo_active or gallery_demo_nodes.size() != \
            gallery_demo_entries.size():
        return
    gallery_fall_time = clampf(seconds, 0.0, GALLERY_FALL_DURATION)
    for index in range(gallery_demo_nodes.size()):
        var piece: Node3D = gallery_demo_nodes[index]
        var item: Dictionary = gallery_demo_entries[index]
        var level: int = int(item["layer"])
        var pigment: ShaderMaterial = piece.get_node(
            "GelBody").material_override
        if level == 0:
            # The footing and the three scattered pieces are the visual
            # anchors throughout the entire video-style topple.
            piece.position = _world_position(item)
            piece.rotation = Vector3.ZERO
            pigment.set_shader_parameter("studio_squash", 0.0)
            continue
        var start_time: float = .46 + float(MAX_LAYERS - 1 - level) * .115
        var fraction: float = clampf((gallery_fall_time -
            start_time) / 1.42, 0.0, 1.0)
        if fraction <= 0.0:
            # An accelerating elastic lean precedes the first detachment.
            var anticipation: float = clampf(gallery_fall_time / .46,
                0.0, 1.0)
            var bend: float = pow(float(level) /
                float(MAX_LAYERS - 1), 2.0) * anticipation
            piece.position = _world_position(item) + Vector3(
                .075 * bend * sin(gallery_fall_time * 4.5),
                0.0, 0.0)
            piece.rotation = Vector3(0.0, 0.0,
                .020 * bend * sin(gallery_fall_time * 4.5))
            pigment.set_shader_parameter("studio_squash", .12 * bend)
            continue
        var eased: float = fraction * fraction * (3.0 - 2.0 * fraction)
        var direction: float = -1.0 if level % 2 == 0 else 1.0
        # All real reference bricks are HORIZONTAL bars before impact.
        # Rotating them 90-120 degrees around local Z in the old trial
        # made the fallen pile look like upright dominoes. Roll around
        # their LONG axis instead, with varied end poses (flat, on-edge
        # or upside down), and only a little sideways tipping.
        var roll: float = .36
        if level % 3 == 0:
            roll = 2.64
        elif level % 3 == 1:
            roll = 1.30
        var rotation := Vector3(
            direction * roll * eased,
            direction * (.26 + float(level % 4) * .23) * eased,
            direction * (.07 + float(level % 2) * .10) * eased)
        var rotated := Basis.from_euler(rotation)
        var length: int = LENGTHS[int(item["length"])]
        var along_x: bool = posmod(int(item["turns"]), 2) == 0
        var span_x: float = float(length if along_x else 1)
        var span_z: float = float(1 if along_x else length)
        var local_center := Vector3(span_x * .5,
            (GEL.BASE + GEL.STUDIO_STUD_TOP) * .5, span_z * .5)
        var half_box := Vector3(span_x * .5 + .07,
            (GEL.STUDIO_STUD_TOP - GEL.BASE) * .5 + .02,
            span_z * .5 + .07)
        # AABB radius under the rotated true 3D brick, evaluated in
        # constant time. Even a 3-cell bar tilted onto a corner cannot
        # pass through the photographic floor.
        var vertical_extent: float = absf(rotated.x.y) * half_box.x + \
            absf(rotated.y.y) * half_box.y + \
            absf(rotated.z.y) * half_box.z
        var starting_center: Vector3 = _world_position(item) + local_center
        # Distribute landings across a golden-angle rosette, rather than
        # dropping every colorful layer into the same two piles. The
        # original photo includes other loose bricks, so keep a generous
        # radial gap and expand the video-replay camera very slightly.
        var scatter_angle: float = float(level) * 2.39996323
        var spread: float = 3.20 + float(level % 3) * .33
        var sideways: float = cos(scatter_angle) * spread
        var outward: float = sin(scatter_angle) * spread
        var ground_center := starting_center + Vector3(
            sideways, 0.0, outward)
        ground_center.y = -.30 + vertical_extent + .01
        # A short outward launch and gravity-shaped arc are much more
        # legible than the old cubic interpolation straight to the floor.
        # The apex occurs early (24% of flight), followed by a faster
        # descent and a distinct contact at 76%. All coordinates are
        # evaluated analytically: replay, pause and slow Android frames
        # see exactly the same trajectory at a given timeline position.
        const CONTACT_FRACTION := .76
        var flight: float = clampf(fraction / CONTACT_FRACTION, 0.0, 1.0)
        var launch: float = flight * flight * (3.0 - 2.0 * flight)
        var center: Vector3 = starting_center.lerp(ground_center, launch)
        # Positive-only parabola peaks before landing. Higher floors
        # launch farther; the floor-bound remains the hard lower limit.
        var lift: float = (.35 + float(level) * .055) * \
            4.0 * flight * (1.0 - flight) * (1.0 - .36 * flight)
        # Horizontal scatter can ease smoothly while gravity must take
        # over later, otherwise early vertical interpolation erases launch.
        center.y = lerpf(starting_center.y, ground_center.y,
            pow(flight, 3.0)) + lift
        var impact_phase: float = clampf(
            (fraction - CONTACT_FRACTION) / (1.0 - CONTACT_FRACTION),
            0.0, 1.0)
        var bounce: float = 0.0
        if fraction > CONTACT_FRACTION:
            # Two diminishing, non-negative lobes. No permanent jitter,
            # and no visually impossible motion through the white floor.
            bounce = .18 * pow(1.0 - impact_phase, 2.0) * \
                absf(sin(impact_phase * PI * 2.0))
        center.y = maxf(center.y + bounce, ground_center.y)
        piece.rotation = rotation
        piece.position = center - rotated * local_center
        # Gel stretches during free flight, squashes only AFTER actual
        # contact and then relaxes to a clean, undeformed rest pose.
        var flight_stretch: float = -.10 * sin(PI * flight) \
            if fraction <= CONTACT_FRACTION else 0.0
        var impact_squash: float = .36 * (1.0 - impact_phase) * \
            absf(sin(impact_phase * PI * 2.0)) \
            if fraction > CONTACT_FRACTION else 0.0
        pigment.set_shader_parameter("studio_squash",
            clampf(flight_stretch + impact_squash, -.5, .5))
    if gallery_fall_time >= GALLERY_FALL_DURATION:
        gallery_fall_active = false
        gallery_fall_finished = true
        if gallery_fall_button != null:
            gallery_fall_button.text = "↻ Rejouer"

func _animate_gallery_fall(elapsed: float) -> void:
    if gallery_fall_active:
        _apply_gallery_fall(gallery_fall_time +
            minf(maxf(elapsed, 0.0), .25))

func _start_gallery_fall() -> void:
    if not active or not photo_mode or not gallery_demo_active:
        return
    _reset_gallery_sway()
    gallery_fall_active = true
    gallery_fall_finished = false
    gallery_fall_time = 0.0
    # Optical mixing exists only while two pigments remain seated.
    for piece in gallery_demo_nodes:
        var pigment: ShaderMaterial = piece.get_node("GelBody").material_override
        pigment.set_shader_parameter("studio_contact_dye", Color(0, 0, 0, 0))
    # Pause already belongs to the existing Gallery user controls.
    # A replay starts playing, even if the previous photo was paused.
    if photo_paused:
        _toggle_photo_pause()
    photo_resume_wait = PHOTO_GESTURE_COOLDOWN
    # Larger cinematic footprint during the scatter. This affects only
    # the temporary gallery, not the player's saved inspection zoom.
    photo_zoom = maxf(photo_zoom, 1.39)
    _update_photo_camera()
    if gallery_fall_button != null:
        gallery_fall_button.text = "↻ Rejouer"

func _reset_gallery_sway() -> void:
    gallery_fall_active = false
    gallery_fall_finished = false
    gallery_fall_time = 0.0
    gallery_sway_time = 0.0
    if gallery_fall_button != null:
        gallery_fall_button.text = "↘ Chute"
    for index in range(gallery_demo_nodes.size()):
        var piece: Node3D = gallery_demo_nodes[index]
        if is_instance_valid(piece):
            piece.position = _world_position(gallery_demo_entries[index])
            piece.rotation = Vector3.ZERO
            var photo_paint: ShaderMaterial = piece.get_node(
                "GelBody").material_override
            photo_paint.set_shader_parameter("studio_squash", 0.0)
    if not gallery_demo_nodes.is_empty():
        _refresh_contact_optics(gallery_demo_entries, gallery_demo_nodes)

func _show_gallery_demo(enabled: bool) -> void:
    if enabled == gallery_demo_active:
        return
    if enabled and not _ensure_gallery_demo():
        return
    if enabled:
        # A restrained 3/4 product angle reveals the actual molded depth
        # and two tenon lanes. The old near-zero yaw flattened the 3D tower
        # into colored rectangles in the Android portrait gallery.
        # Restore the user's precise orbit and zoom after the demonstration.
        gallery_user_angle = photo_angle
        gallery_user_zoom = photo_zoom
        photo_angle = 0.34
        # Nine closer interlocked layers need a slightly wider editorial
        # portrait frame, otherwise the loose yellow brick is clipped.
        photo_zoom = 1.0
    else:
        photo_angle = gallery_user_angle
        photo_zoom = gallery_user_zoom
    gallery_demo_active = enabled
    # Re-entering Vitrine begins from its exact neutral valid stack.
    # Switching back restores every demo node, never touching user data.
    _reset_gallery_sway()
    if gallery_demo_root != null:
        gallery_demo_root.visible = enabled
    for piece in brick_nodes:
        if is_instance_valid(piece):
            piece.visible = not enabled
    if not enabled:
        # Restore real shadow budget for the user's original construction.
        _set_gallery_coat(photo_mode)
    else:
        # The twelve-brick demo uses the existing shared shadow atlas.
        gallery_shadow_key.visible = true
    _refresh_caustics()
    if gallery_demo_button != null:
        gallery_demo_button.text = "Ma pile" if enabled else "Vitrine"
    if gallery_fall_button != null:
        gallery_fall_button.visible = enabled
    if photo_mode:
        _update_photo_camera()

func _toggle_gallery_demo() -> void:
    if not photo_mode:
        return
    _show_gallery_demo(not gallery_demo_active)

func _clear_gallery_demo() -> void:
    if gallery_demo_active:
        _show_gallery_demo(false)
    if gallery_demo_root != null:
        scene_root.remove_child(gallery_demo_root)
        gallery_demo_root.queue_free()
        gallery_demo_root = null
    gallery_demo_nodes.clear()
    gallery_demo_entries.clear()
    gallery_demo_active = false
    if gallery_demo_button != null:
        gallery_demo_button.text = "Vitrine"
    if gallery_fall_button != null:
        gallery_fall_button.visible = false
        gallery_fall_button.text = "↘ Chute"

func _studio_height() -> float:
    var height: float = .8
    var photographed: Array[Dictionary] = gallery_demo_entries if gallery_demo_active else bricks
    for entry in photographed:
        height = maxf(height, float(int(entry["layer"]) + 1) * STEP + .50)
    return height

## An orthographic portrait camera crops the left/right foreground
## long before tall towers clip vertically. Compute a rotation-independent
## footprint radius from the REAL 3D brick dimensions, so all pieces remain
## in frame even as the Gallery auto-orbits on slower Android GPUs. Keeping
## this minimum constant across angles prevents a distracting zoom pulse.
func _photo_horizontal_frame_size() -> float:
    var photographed: Array[Dictionary] = gallery_demo_entries \
        if gallery_demo_active else bricks
    var radius: float = 0.0
    for entry in photographed:
        var length: int = LENGTHS[int(entry["length"])]
        var along_x: bool = posmod(int(entry["turns"]), 2) == 0
        var span_x: float = float(length if along_x else 1)
        var span_z: float = float(1 if along_x else length)
        var origin: Vector3 = _world_position(entry)
        # Molded body overhangs each nominal cell footprint by 0.064.
        # The .30 extra margin also accommodates animated gel sway.
        for dx in [-0.07, span_x + 0.07]:
            for dz in [-0.07, span_z + 0.07]:
                radius = maxf(radius, Vector2(
                    origin.x + float(dx), origin.z + float(dz)).length())
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    var aspect: float = viewport_size.x / maxf(1.0, viewport_size.y)
    return 2.0 * (radius + 0.30) / maxf(aspect, 0.1)

func _update_photo_camera() -> void:
    var height: float = _studio_height()
    var target_y: float = maxf(1.20, height * .38)
    # As the video-style tower tumbles to the white floor, the virtual
    # product camera gently follows the lower center of mass instead of
    # leaving a huge blank portrait above a tiny scattered pile. Framing
    # restores automatically with the unchanged original user camera.
    if gallery_demo_active and (gallery_fall_active or gallery_fall_finished):
        var follow: float = smoothstep(.70, 2.70, gallery_fall_time)
        target_y = lerpf(target_y, 1.10, follow)
    # Retain the low photographic view while also fitting the full width
    # of the actual sculpture into a portrait Android viewport.
    host.camera.position = Vector3(
        sin(photo_angle) * 12.4,
        target_y + 5.8,
        cos(photo_angle) * 12.4)
    host.camera.size = maxf(maxf(8.8, height * 1.4 + 4.5),
        _photo_horizontal_frame_size()) * photo_zoom
    host.camera.look_at(Vector3(0.0, target_y, 0.0))

func _toggle_photo_pause() -> void:
    if not photo_mode:
        return
    photo_paused = not photo_paused
    photo_pause_button.text = "▶ Reprise" if photo_paused else "⏸ Pause"

func _enter_photo_mode() -> void:
    if not active or photo_mode:
        return
    photo_mode = true
    gallery_demo_active = false
    gallery_demo_button.text = "Vitrine"
    gallery_fall_active = false
    gallery_fall_finished = false
    gallery_fall_time = 0.0
    gallery_fall_button.visible = false
    photo_paused = false
    photo_pause_button.text = "⏸ Pause"
    active_touch_index = -1
    play_touch_contacts.clear()
    play_multitouch_blocked = false
    mouse_held = false
    hud.visible = false
    photo_layer.visible = true
    _reset_preview_inertia()
    if preview_node != null:
        preview_node.visible = false
    _set_gallery_coat(true)
    _set_photo_environment(true)
    photo_zoom = 1.0
    _clear_photo_gestures()
    photo_angle = atan2(host.camera.position.x, host.camera.position.z)
    _update_photo_camera()

func _leave_photo_mode() -> void:
    if not photo_mode:
        return
    _clear_gallery_demo()
    photo_mode = false
    photo_paused = false
    play_touch_contacts.clear()
    play_multitouch_blocked = false
    _clear_photo_gestures()
    photo_layer.visible = false
    hud.visible = active
    _set_gallery_coat(false)
    _set_photo_environment(false)
    if active:
        _apply_camera()
        _refresh_preview()

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
        # Straight bars are truly one soft molded object with smooth
        # volumetric corner radii, unlike the irregular puzzle polyominoes.
        mesh_cache[mesh_key] = GEL.build_studio(cells.size(), turns)
    var material := ShaderMaterial.new()
    material.shader = SHADER
    material.set_shader_parameter("candy_tint", Color(COLORS[color_idx]))
    material.set_shader_parameter("gel_opacity", .43 if translucent else .94)
    material.set_shader_parameter("sheen", .18 if translucent else .51)
    material.set_shader_parameter("studio_glass", 1.0)
    if translucent:
        material.set_shader_parameter("studio_drag", Vector2.ZERO)
    material.set_shader_parameter("studio_pigment", .72 if translucent else .88)
    # Fully pigmented polished candy: visible only in the 3D studio.
    # Keep ghost less opaque and less glossy for precise mobile placement.
    material.set_shader_parameter("studio_finish", .46 if translucent else .94)
    # A localized photographic bead on the real bevel, not a white tint
    # over the whole block. Ghost stays dim while the solid is glossy.
    material.set_shader_parameter("studio_wet_edge", .15 if translucent else .95)
    # Broad tinted photographic reflections live INSIDE the original Jelly
    # shader, not on an extra mesh. Ghosts never receive opaque light panels.
    material.set_shader_parameter("studio_light_card", 0.0 if translucent else .88)
    # Root menisci match the TWO actual stud lanes on either orientation.
    # No simulated collar on translucent placement ghosts or 21 puzzles.
    material.set_shader_parameter("studio_interlock", 0.0 if translucent else .84)
    # Contact tint is computed only when the piece is seated. Ghosts and
    # loose pieces never inherit optical traces from previous materials.
    material.set_shader_parameter("studio_contact_dye", Color(0, 0, 0, 0))
    material.set_shader_parameter("studio_contact_extent", 0.0)
    material.set_shader_parameter("studio_stud_axis", float(posmod(turns, 2)))
    # Reference candy has a luminous interior, not opaque painted sides.
    # Core light diffusion is one shader branch on already existing faces.
    material.set_shader_parameter("studio_transmission", 0.0 if translucent else .86)
    material.set_shader_parameter("studio_squash", 0.0)
    # Live solids couple indentation of the crown with a gentle
    # lateral pressure release. Ghosts/legacy puzzles remain unchanged.
    material.set_shader_parameter("studio_pressure_strength",
        0.0 if translucent else .96)
    # Studio gel starts with a neutral optical path, then its density
    # changes only when the real pressure uniform deforms the vertices.
    # Keep placement ghosts transparent and the original puzzles intact.
    material.set_shader_parameter("studio_strain_optics",
        0.0 if translucent else .88)
    material.set_shader_parameter("studio_wave_phase", 0.0)
    material.set_shader_parameter("studio_wave_gain", 0.0)
    material.set_shader_parameter("studio_jiggle_phase", 0.0)
    material.set_shader_parameter("studio_jiggle_gain", 0.0)
    material.set_shader_parameter("studio_span", Vector2(
        float(cells.size()) if posmod(turns, 2) == 0 else 1.0,
        1.0 if posmod(turns, 2) == 0 else float(cells.size())))
    # Regular gameplay uses conservative optics; the Gallery enhances
    # absorption without extra geometry or texture lookups.
    material.set_shader_parameter("optical_depth", .18 if translucent else .54)
    # Enhance the true visible sidewalls, not the placement preview.
    # Disable in the classic 21-puzzle material through the shader default.
    material.set_shader_parameter("gel_depth_optics", 0.0 if translucent else .78)
    material.set_shader_parameter("gel_spring", 0.0)
    var body := MeshInstance3D.new()
    body.name = "GelBody"
    body.mesh = mesh_cache[mesh_key]
    body.material_override = material
    # Godot alpha blending sorts by the MeshInstance origin by default.
    # The procedural bar extends from local 0 to 1/2/3 cells, so its
    # origin is at the far corner instead of the actual volume centre.
    # Long blue/red overlapping bars then render out of order and look
    # like semitransparent plastic sheets. Native Godot 4.6 can sort
    # by the world-space AABB centre without a custom shader or extra
    # rendering pass. This follows the bounds during Gallery rotations.
    body.sorting_use_aabb_center = true
    body.material_override = material
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root_piece.add_child(body)
    # Even solid interactive bricks allocate NO Gallery-only instances.
    # The gallery creates/reuses these only after the user taps Photo.
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    # Per-stud XZ footprint centres are packed into the EXISTING batched
    # draw. Godot 4.6 Compatibility exposes INSTANCE_CUSTOM in shaders.
    # Use [0, 1] encoding, so data remains safe in its 16-bit format.
    # The body's top and each individual stud can now sample the SAME
    # world-of-brick gel wave: no shared false origin on rotated bars,
    # extra MeshInstance3Ds or additional materials/draw calls.
    instances.use_custom_data = true
    # The 21 puzzle stages still use host.stud_mesh, unchanged. Only the
    # 3D studio uses shorter flat-topped molded studs.
    instances.mesh = studio_stud_mesh
    # The physical reference shows TWO stud lanes across the narrow
    # width, not a crowded 2x2 cluster in every one-cell bar segment.
    # Three-cell bricks therefore carry six studs; short bricks carry two.
    # This halves the shared MultiMesh instance count for every 3D piece.
    instances.instance_count = cells.size() * 2
    var along_x: bool = posmod(turns, 2) == 0
    var idx := 0
    for cell in cells:
        for across in [-.235, .235]:
            var stud_x: float = float(cell.y) + .5 + (
                0.0 if along_x else across)
            var stud_z: float = float(cell.x) + .5 + (
                across if along_x else 0.0)
            instances.set_instance_transform(idx,
                Transform3D(Basis.IDENTITY, Vector3(stud_x, 0.0, stud_z)))
            instances.set_instance_custom_data(idx,
                Color(stud_x / 4.0, stud_z / 4.0, 0.0, 1.0))
            idx += 1
    var studs := MultiMeshInstance3D.new()
    studs.name = "GelStuds"
    studs.multimesh = instances
    studs.material_override = material
    # Match transparent stud-group ordering to the complete 2-lane body.
    # A grouped MultiMesh is still a single draw, not six sort passes.
    studs.sorting_use_aabb_center = true
    studs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root_piece.add_child(studs)
    if not translucent:
        # Each stacked piece casts a small radial contact impression directly
        # under its body, without shadow maps or per-frame ray casts.
        var longest_row := 0
        var longest_col := 0
        for cell in cells:
            longest_row = maxi(longest_row, cell.x + 1)
            longest_col = maxi(longest_col, cell.y + 1)
        var contact_key := str(length_index) + ":" + str(posmod(turns, 2))
        if not contact_mesh_cache.has(contact_key):
            var patch := PlaneMesh.new()
            patch.size = Vector2(float(longest_col) + .38,
                float(longest_row) + .38)
            contact_mesh_cache[contact_key] = patch
        var contact := MeshInstance3D.new()
        contact.name = "GelContact"
        contact.mesh = contact_mesh_cache[contact_key]
        contact.material_override = contact_material
        contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        contact.position = Vector3(float(longest_col) * .5,
            GEL.STUDIO_SOCKET_ROOF + .004
                if int(entry["layer"]) > 0 else .035,
            float(longest_row) * .5)
        root_piece.add_child(contact)
    return root_piece

func _world_position(entry: Dictionary) -> Vector3:
    # Bottom of gel body is at y=.055; the plinth surface is at y=-.30.
    # At .55 step the .21-deep pocket fully encloses real studs while the
    # continuous rounded Jelly shells almost meet at their molded collars.
    return Vector3(float(entry["col"]) - float(GRID) * .5,
        -.33 + float(entry["layer"]) * STEP,
        float(entry["row"]) - float(GRID) * .5)

## A finger can add or undo during a spring animation. Never allow stale
## tweens to deform a reconstructed pile or touch a freed instance.
func _stop_motion() -> void:
    for tween in motion_tweens:
        if tween != null and tween.is_valid():
            tween.kill()
    motion_tweens.clear()
    # A new gesture, Undo or mode change settles any previous flight.
    # Its colored floor projection must be restored just like GelContact.
    if pending_caustic_index >= 0:
        pending_caustic_index = -1
        _refresh_caustics()
    for i in range(mini(bricks.size(), brick_nodes.size())):
        var node: Node3D = brick_nodes[i]
        if is_instance_valid(node):
            node.position = _world_position(bricks[i])
            node.rotation = Vector3.ZERO
            node.scale = Vector3.ONE
            node.get_node("GelContact").visible = true
            var paint: ShaderMaterial = node.get_node("GelBody").material_override
            paint.set_shader_parameter("gel_spring", 0.0)
            paint.set_shader_parameter("studio_squash", 0.0)
            paint.set_shader_parameter("studio_wave_phase", 0.0)
            paint.set_shader_parameter("studio_wave_gain", 0.0)
            paint.set_shader_parameter("studio_jiggle_phase", 0.0)
            paint.set_shader_parameter("studio_jiggle_gain", 0.0)
    # Interrupted animations settle immediately; the permanent interface
    # dye must then match the current saved pile, never a removed piece.
    if not brick_nodes.is_empty():
        _refresh_contact_optics(bricks, brick_nodes)

## Trigger the squeeze only when the real brick reaches its support.
## Four successive, decaying lobes make a short gelatin compression and
## rebound, unlike a rigid block's instantaneous elastic transform.
## Signed squash deforms the true vertex shell and studs in the GPU shader.
## No physics solver, new material, new draw call or per-frame CPU polling.
func _animate_gel_compression(paint: ShaderMaterial,
        peak: float, delay: float = 0.0) -> Tween:
    var rebound := create_tween()
    motion_tweens.append(rebound)
    if delay > 0.0:
        rebound.tween_interval(delay)
    rebound.tween_property(paint, "shader_parameter/studio_squash",
        peak, .095).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    rebound.tween_property(paint, "shader_parameter/studio_squash",
        -peak * .34, .18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    rebound.tween_property(paint, "shader_parameter/studio_squash",
        peak * .11, .13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    rebound.tween_property(paint, "shader_parameter/studio_squash",
        0.0, .23).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    return rebound

## Compute the impact in RECEIVER-local coordinates, using actual
## overlapping cells on the same supporting tier. Sideways contact must
## not appear as a generic wave emitted from the middle of every brick.
## Ground impacts and non-overlapping lower tiers fall back to the centre.
func _wave_center_on(receiver: Dictionary, contact: Dictionary) -> Vector2:
    var length: int = LENGTHS[int(receiver["length"])]
    var along_x: bool = posmod(int(receiver["turns"]), 2) == 0
    var midpoint := Vector2(
        float(length if along_x else 1) * .5,
        float(1 if along_x else length) * .5)
    if contact.is_empty():
        return midpoint
    var footprint: Array[Vector2i] = _occupied_cells(receiver)
    var center := Vector2.ZERO
    var shared := 0
    for cell in _occupied_cells(contact):
        if not footprint.has(cell):
            continue
        center += Vector2(
            float(cell.y - int(receiver["col"])) + .5,
            float(cell.x - int(receiver["row"])) + .5)
        shared += 1
    return center / float(shared) if shared > 0 else midpoint

## No idle per-frame script. Godot tweens ONE existing shader uniform only
## while a live brick settles. The vertex shader analytically expands a
## narrow, damped radial ring on its side walls; studs and base stay seated.
func _animate_gel_wave(paint: ShaderMaterial,
        center: Vector2, strength: float, delay: float = 0.0) -> Tween:
    paint.set_shader_parameter("studio_wave_center", center)
    paint.set_shader_parameter("studio_wave_phase", 0.0)
    paint.set_shader_parameter("studio_wave_gain", clampf(strength, 0.0, .92))
    var wave := create_tween()
    motion_tweens.append(wave)
    if delay > 0.0:
        wave.tween_interval(delay)
    wave.tween_property(paint, "shader_parameter/studio_wave_phase",
        1.0, .54).set_trans(Tween.TRANS_LINEAR)
    wave.tween_callback(paint.set_shader_parameter.bind(
        "studio_wave_phase", 0.0))
    wave.tween_callback(paint.set_shader_parameter.bind(
        "studio_wave_gain", 0.0))
    return wave

## Independent, low-frequency viscoelastic aftershock. The contact ring
## lasts .54 s; the whole gelatin volume takes ~1.10 s to stop wobbling.
## Phase and gain are set once at the interaction, not updated every
## frame from GDScript. This ensures separate impact times never lock to
## Godot's global TIME oscillator. The shader clamps displacement to the
## wall's middle and anchors the socket, crown and every actual stud.
func _animate_gel_jiggle(paint: ShaderMaterial, center: Vector2,
        strength: float, delay: float = 0.0) -> Tween:
    paint.set_shader_parameter("studio_wave_center", center)
    paint.set_shader_parameter("studio_jiggle_phase", 0.0)
    paint.set_shader_parameter("studio_jiggle_gain",
        clampf(strength, 0.0, .92))
    var jiggle := create_tween()
    motion_tweens.append(jiggle)
    if delay > 0.0:
        jiggle.tween_interval(delay)
    jiggle.tween_property(paint, "shader_parameter/studio_jiggle_phase",
        1.0, 1.10).set_trans(Tween.TRANS_LINEAR)
    jiggle.tween_callback(paint.set_shader_parameter.bind(
        "studio_jiggle_phase", 0.0))
    jiggle.tween_callback(paint.set_shader_parameter.bind(
        "studio_jiggle_gain", 0.0))
    return jiggle

## One draw per studio floor, not one light or shader material per
## piece. Only ground-contact pieces transmit color onto the white base.
## UVs stay normalized under nonuniform scaling of each shared plane.
func _refresh_caustics() -> void:
    if caustic_batch == null:
        return
    var on_ground: Array[Dictionary] = []
    var projected: Array[Dictionary] = gallery_demo_entries if gallery_demo_active else bricks
    for index in range(projected.size()):
        # The last brick is saved immediately but its visual fall takes .29s.
        # Do not project its light onto the floor before contact.
        if not gallery_demo_active and index == pending_caustic_index:
            continue
        var entry: Dictionary = projected[index]
        if int(entry["layer"]) == 0:
            on_ground.append(entry)
    var batch: MultiMesh = caustic_batch.multimesh
    batch.instance_count = on_ground.size()
    for index in range(on_ground.size()):
        var entry: Dictionary = on_ground[index]
        var count: int = LENGTHS[int(entry["length"])]
        var along_col: bool = posmod(int(entry["turns"]), 2) == 0
        var span_x: float = float(count if along_col else 1)
        var span_z: float = float(1 if along_col else count)
        var corner: Vector3 = _world_position(entry)
        var center := Vector3(corner.x + span_x * .5, -.292,
            corner.z + span_z * .5)
        var scale := Basis.IDENTITY.scaled(Vector3(
            span_x + .68, 1.0, span_z + .68))
        batch.set_instance_transform(index, Transform3D(scale, center))
        batch.set_instance_color(index, Color(
            COLORS[int(entry["color"])]).lerp(Color.WHITE, .12))

func _finish_ground_caustic() -> void:
    if pending_caustic_index < 0:
        return
    pending_caustic_index = -1
    _refresh_caustics()

## A contact is eligible only when the two bricks have adjacent layers
## AND physically overlapping cells. Weighted colors and coordinates are
## computed once per structural change; there is no per-frame neighborhood
## scan in the Android renderer.
func _contact_profile(entry: Dictionary, arrangement: Array[Dictionary]) -> Dictionary:
    if int(entry["layer"]) <= 0:
        return {}
    var own_cells: Array[Vector2i] = _occupied_cells(entry)
    var sum_color := Vector3.ZERO
    var sum_position := Vector2.ZERO
    var shared := 0
    for lower in arrangement:
        if int(lower["layer"]) != int(entry["layer"]) - 1:
            continue
        var pigment := Color(COLORS[int(lower["color"])])
        for cell in _occupied_cells(lower):
            if not own_cells.has(cell):
                continue
            sum_color += Vector3(pigment.r, pigment.g, pigment.b)
            sum_position += Vector2(
                float(cell.y - int(entry["col"])) + .5,
                float(cell.x - int(entry["row"])) + .5)
            shared += 1
    if shared == 0:
        return {}
    return {
        "dye": Color(sum_color.x / float(shared),
            sum_color.y / float(shared),
            sum_color.z / float(shared), .78),
        "center": sum_position / float(shared),
        "extent": .56 + .17 * float(mini(shared - 1, 3)),
        # Not persisted: this is computed from real occupied contacts.
        # Used by the impact animation, not by collision/saving rules.
        "supported_cells": shared,
        "support_fraction": float(shared) / float(own_cells.size())
    }

func _apply_contact_optics(node: Node3D, entry: Dictionary,
        arrangement: Array[Dictionary]) -> void:
    if not is_instance_valid(node):
        return
    var material: ShaderMaterial = node.get_node("GelBody").material_override
    var profile: Dictionary = _contact_profile(entry, arrangement)
    material.set_shader_parameter("studio_contact_dye",
        profile.get("dye", Color(0, 0, 0, 0)))
    material.set_shader_parameter("studio_contact_center",
        profile.get("center", Vector2(.5, .5)))
    material.set_shader_parameter("studio_contact_extent",
        profile.get("extent", 0.0))

func _refresh_contact_optics(arrangement: Array[Dictionary],
        nodes: Array[Node3D]) -> void:
    for i in range(mini(arrangement.size(), nodes.size())):
        _apply_contact_optics(nodes[i], arrangement[i], arrangement)

func _rebuild() -> void:
    _stop_motion()
    for child in scene_root.get_children():
        if child.name == "StudioBrick":
            scene_root.remove_child(child)
            child.queue_free()
    brick_nodes.clear()
    _rebuild_occupancy()
    for entry in bricks:
        var piece := _build_piece(entry, false)
        piece.position = _world_position(entry)
        scene_root.add_child(piece)
        brick_nodes.append(piece)
    _refresh_contact_optics(bricks, brick_nodes)
    _refresh_caustics()
    if photo_mode:
        _set_gallery_coat(true)
    _refresh_preview()
    _refresh_labels()
    if active:
        _apply_camera()

## During a drag the shape and studs NEVER need reallocating.
## Reuse the same translucent node and shared ShaderMaterial until the user
## changes the brick's geometry. Only its transform/tint is updated on motion.
func _refresh_preview() -> void:
    if not active:
        return
    var result := _drop_candidate(selected_cell.x, selected_cell.y,
        selected_length, selected_turns)
    var entry := _entry(selected_cell.x, selected_cell.y,
        selected_length, selected_turns, selected_color,
        int(result.get("layer", 0)))
    var signature := str(selected_length) + ":" + str(posmod(selected_turns, 2))
    if preview_node == null or preview_signature != signature:
        if preview_node != null:
            remove_child(preview_node)
            preview_node.queue_free()
        preview_node = _build_piece(entry, true)
        _reset_preview_inertia()
        preview_node.name = "StudioPreview"
        add_child(preview_node)
        preview_signature = signature
        preview_node.position = _world_position(entry) + Vector3(0, .14, 0)
    var paint: ShaderMaterial = preview_node.get_node("GelBody").material_override
    paint.set_shader_parameter("candy_tint", Color(COLORS[selected_color])
        if result.get("ok", false) else Color("#ff6f88"))
    preview_target = _world_position(entry) + Vector3(0, .14, 0)
    preview_node.visible = not photo_mode
    _refresh_labels()

func _refresh_labels(message: String = "") -> void:
    if figure_target_label != null:
        figure_target_label.visible = figure_active
        figure_next_button.visible = figure_active
        figure_model_button.visible = figure_active
        figure_mini_row.visible = figure_active
        if figure_active:
            var goal: Dictionary = FIGURES.target(figure_index)
            var state: Dictionary = FIGURES.evaluate(figure_index, bricks)
            figure_target_label.text = "%02d/20 · %s · %d/%d cases · %d XP" % [
                figure_index + 1, FIGURES.difficulty(figure_index),
                state["correct"], state["required"],
                int(figure_progress.get("xp", 0))]
    if title_label != null:
        if figure_active:
            title_label.text = "Figure %02d · %s" % [
                figure_index + 1, FIGURES.target(figure_index)["name"]]
        else:
            var height := 0
            for entry in bricks:
                height = maxi(height, int(entry["layer"]) + 1)
            title_label.text = "%d briques · %d étages" % [
                bricks.size(), height]
    if status_label == null:
        return
    if not message.is_empty():
        status_label.text = message
    elif figure_active:
        var state: Dictionary = FIGURES.evaluate(figure_index, bricks)
        status_label.text = "Complète le modèle · %d/%d cases correctes" % [
            state["correct"], state["required"]]
    else:
        var candidate := _drop_candidate(selected_cell.x, selected_cell.y,
            selected_length, selected_turns)
        status_label.text = "Glisse pour empiler · relâche pour poser" if \
            candidate.get("ok", false) else String(candidate.get("reason", ""))

func _refresh_figure_thumbnail() -> void:
    var model: Dictionary = FIGURES.target(figure_index)
    for idx in range(36):
        var row: int = idx / 6
        var col: int = idx % 6
        var symbol: String = String(model["rows"][row]).substr(col, 1)
        figure_mini_cells[idx].color = Color("#edf1f7") if symbol == "." \
            else Color(COLORS[int(symbol)])

func _populate_figure_selector() -> void:
    figure_selector.clear()
    var unlocked: int = int(figure_progress.get("unlocked", 0))
    var stars: Dictionary = figure_progress.get("stars", {})
    for idx in range(20):
        var model: Dictionary = FIGURES.target(idx)
        var earned_stars: int = int(stars.get(str(idx), 0))
        var suffix := "  ★%d" % earned_stars if earned_stars > 0 else ""
        figure_selector.add_item("%02d · %s%s" % [
            idx + 1, model["name"], suffix], idx)
        figure_selector.set_item_disabled(idx, idx > unlocked)
    figure_selector.select(figure_index)

func _save_figure_session() -> bool:
    if not figure_active:
        return true
    var next_state: Dictionary = figure_progress.duplicate(true)
    var sessions: Dictionary = next_state.get("sessions", {}).duplicate(true)
    sessions[str(figure_index)] = _export_entries()
    next_state["sessions"] = sessions
    next_state["active"] = figure_index
    if not FIGURES.save_progress(next_state):
        return false
    figure_progress = next_state
    return true

func _open_figure_session() -> void:
    _stop_motion()
    var sessions: Dictionary = figure_progress.get("sessions", {})
    var entries = sessions.get(str(figure_index), [])
    # Every saved brick goes back through the SAME support, bounds,
    # shape and palette validation as the free Studio on Android.
    if not _load_entries(entries):
        bricks.clear()
        occupancy.clear()
    figure_cleared = false
    figure_next_button.text = "Valider"
    figure_share_text = ""
    _rebuild()
    _populate_figure_selector()
    _refresh_figure_thumbnail()
    _refresh_labels()

func _select_figure(index: int) -> void:
    if not figure_active or index == figure_index:
        return
    if index < 0 or index > int(figure_progress.get("unlocked", 0)):
        figure_selector.select(figure_index)
        return
    if not _save_figure_session():
        figure_selector.select(figure_index)
        _refresh_labels("Stockage indisponible · niveau conservé")
        return
    figure_index = index
    _open_figure_session()

func _show_figure_model() -> void:
    if not figure_active:
        return
    var challenge: Dictionary = FIGURES.target(figure_index)
    var markup := "[center][b]%s[/b][/center]\n\n" % challenge["name"]
    for row in challenge["rows"]:
        markup += "[center]"
        for symbol in String(row):
            if symbol == ".":
                markup += "[color=#e3e7ed]■[/color] "
            else:
                markup += "[color=%s]■[/color] " % COLORS[int(symbol)]
        markup += "[/center]\n"
    markup += "\n[center]Tu peux consulter le petit modèle pendant la pose.[/center]"
    figure_model_text.text = markup
    figure_model_dialog.popup_centered()

func _toggle_figures() -> void:
    if not figure_active:
        figure_active = true
        figure_index = clampi(int(figure_progress.get("active", 0)), 0,
            mini(19, int(figure_progress.get("unlocked", 0))))
        figure_button.text = "Atelier libre"
        _open_figure_session()
    else:
        if not _save_figure_session():
            _refresh_labels("Stockage indisponible · atelier défi conservé")
            return
        figure_active = false
        figure_button.text = "Défis · 20 figures"
        _stop_motion()
        _restore_or_seed()
        _rebuild()
        _refresh_labels()

func _share_figure() -> void:
    if figure_share_text.is_empty():
        return
    DisplayServer.clipboard_set(figure_share_text)
    _refresh_labels("Résultat copié · colle-le dans un message ou sur les réseaux")
    figure_victory_dialog.dialog_text += "\n\nRésultat copié dans le presse-papiers."

func _validate_figure() -> void:
    if not figure_active:
        return
    if figure_cleared:
        figure_victory_dialog.popup_centered()
        return
    var result: Dictionary = FIGURES.evaluate(figure_index, bricks)
    if not result["won"]:
        _refresh_labels("Figure incomplète · %d/%d correctes · %d erreurs" % [
            result["correct"], result["required"], result["wrong"]])
        host._play_feedback("reject", 10)
        return
    var draft: Dictionary = figure_progress.duplicate(true)
    var earned: Dictionary = FIGURES.grant(draft, figure_index, bricks.size())
    var new_progress: Dictionary = earned["progress"]
    if not FIGURES.save_progress(new_progress):
        _refresh_labels("Stockage indisponible · progression non enregistrée")
        return
    figure_progress = new_progress
    figure_cleared = true
    figure_next_button.text = "Récompense"
    _populate_figure_selector()
    host._play_feedback("win", 12)
    var reward_data: Dictionary = earned["reward"]
    var stars: int = int(reward_data["stars"])
    var xp_gain: int = int(reward_data["xp"]) if earned["first_win"] else 0
    figure_share_text = "J'ai réalisé %s (%d/20) dans Jelly Bricks ! %d étoiles · %d points · %d XP. #JellyBricks" % [
        FIGURES.target(figure_index)["name"], figure_index + 1, stars,
        reward_data["score"], int(figure_progress["xp"])]
    figure_victory_dialog.dialog_text = (
        "%s · Niveau %d/20\n\n★ %d/3 étoiles\n+%d points · +%d XP\nMeilleur score : %d\n\nAppuie sur Copier pour partager ta réussite." % [
            FIGURES.target(figure_index)["name"], figure_index + 1,
            stars, earned["earned"], xp_gain,
            int(figure_progress["best"].get(str(figure_index), 0))])
    figure_victory_dialog.ok_button_text = (
        "Revoir les niveaux" if figure_index == 19 else "Figure suivante")
    _refresh_labels("Figure réussie ! %d étoiles · +%d points · +%d XP" % [
        stars, earned["earned"], xp_gain])
    figure_victory_dialog.popup_centered()

func _next_figure() -> void:
    if not figure_active:
        return
    figure_index = 0 if figure_index == 19 else figure_index + 1
    figure_index = mini(figure_index, int(figure_progress.get("unlocked", 0)))
    _open_figure_session()

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
    # Finish a preceding bounce first. Every committed layer starts from
    # its true support height; the deterministic occupancy never wobbles.
    _stop_motion()
    bricks.append(entry)
    _rebuild_occupancy()
    # Persist the actual structural move before showing a successful landing.
    # If storage is full or unavailable, do not mislead the player with
    # a brick that will silently disappear on the next Android launch.
    if not figure_active and not _save():
        bricks.pop_back()
        _rebuild_occupancy()
        host._play_feedback("reject", 10)
        _refresh_labels("Stockage indisponible · brique non posée")
        return
    pending_caustic_index = bricks.size() - 1
    _refresh_caustics()
    var node := _build_piece(entry, false)
    node.position = _world_position(entry) + Vector3(0, .85, 0)
    scene_root.add_child(node)
    node.get_node("GelContact").visible = false
    brick_nodes.append(node)
    var material: ShaderMaterial = node.get_node("GelBody").material_override
    material.set_shader_parameter("gel_spring", 1.0)
    var settle := create_tween()
    motion_tweens.append(settle)
    settle.set_parallel(true)
    # A falling Jelly brick accelerates into the supporting studs before
    # the GPU mesh compresses and rebounds. No fake hard-plastic bounce.
    settle.tween_property(node, "position", _world_position(entry), .29) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    # Rigid parent scaling distorts the footprint, studs and socket.
    # The actual soft deformation belongs to the existing GPU squash.
    node.rotation.z = .028
    settle.tween_property(node, "rotation", Vector3.ZERO, .42) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    settle.tween_property(material, "shader_parameter/gel_spring", 0.0, .91) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    # This brick may bridge two or three separate supports. The old
    # implementation picked whichever support happened to appear first
    # in the save order and sent the ripple off-centre, despite the
    # optical contact centroid already knowing ALL actual shared cells.
    # Reuse that authoritative contact profile for balanced soft-body
    # compression and the wave's initial point. Unsupported ground
    # placements correctly use the centre of the body footprint.
    var impact_contact: Dictionary = _contact_profile(entry, bricks)
    var impact_center: Vector2 = impact_contact.get(
        "center", _wave_center_on(entry, {}))
    var support_fraction: float = float(
        impact_contact.get("support_fraction", 1.0))
    # Partially supported pieces feel slightly softer, without changing
    # the support rule, spring duration or geometry. Bound every impulse.
    var impact_gain: float = clampf(.86 + (1.0 - support_fraction) * .12,
        .86, .92)
    _animate_gel_compression(material, .96, .29)
    _react_to_supports(entry)
    _animate_gel_wave(material, impact_center, impact_gain, .29)
    _animate_gel_jiggle(material, impact_center, impact_gain, .29)
    # The visual flight lasts .29 s: FX must not precede the support
    # contact. A tracked tween is killed by _stop_motion on Undo or
    # replacement and captures the original brick's attributes.
    var contact_event: Tween = create_tween()
    motion_tweens.append(contact_event)
    contact_event.tween_interval(.29)
    contact_event.tween_callback(_finish_ground_caustic)
    contact_event.tween_callback(_apply_contact_optics.bind(node, entry, bricks))
    contact_event.tween_callback(func(): node.get_node("GelContact").visible = true)
    contact_event.tween_callback(_emit_contact_feedback.bind(
        Color(COLORS[selected_color]), selected_length, int(entry["layer"]),
        _world_position(entry)))
    _refresh_preview()
    _apply_camera()
    _refresh_labels("Brique posée · continue la pile")

func _emit_contact_feedback(tint: Color, length_index: int,
        level: int, contact: Vector3) -> void:
    if not active:
        return
    host.candy_fx.landing(contact, tint, true)
    var landing_haptic: int = clampi(16 + LENGTHS[length_index] * 4 +
        level * 2, 18, 44)
    var gel_pitch: float = clampf(1.12 -
        float(LENGTHS[length_index]) * .07 -
        float(level) * .012, .78, 1.1)
    host._play_feedback("place", landing_haptic, gel_pitch)

## Find only bricks that geometrically support the new piece,
## layer by layer. No full-scene motion, rigid-body simulation or solver.
func _support_indices(entry: Dictionary) -> Array[int]:
    var result: Array[int] = []
    var previous: Array[Vector2i] = _occupied_cells(entry)
    for layer in range(int(entry["layer"]) - 1, -1, -1):
        var next_cells: Array[Vector2i] = []
        for index in range(bricks.size() - 1):
            var lower: Dictionary = bricks[index]
            if int(lower["layer"]) != layer:
                continue
            var footprint := _occupied_cells(lower)
            var touching := false
            for cell in footprint:
                if previous.has(cell):
                    touching = true
                    break
            if not touching:
                continue
            result.append(index)
            for cell in footprint:
                if not next_cells.has(cell):
                    next_cells.append(cell)
        previous = next_cells
        if previous.is_empty():
            break
    return result

func _react_to_supports(entry: Dictionary) -> void:
    var indices := _support_indices(entry)
    # A soft impact travels down the actual connected supports. The contact
    # tier reacts first, then each lower tier after a short propagation delay.
    # All impulses are bounded and tweened; there is no per-frame physics
    # solver, no global tower shake, and no changes to structural occupancy.
    for index in indices:
        if index < 0 or index >= brick_nodes.size() - 1:
            continue
        var base: Node3D = brick_nodes[index]
        var distance: int = int(entry["layer"]) - int(bricks[index]["layer"])
        var strength: float = .052 * pow(.68, float(distance - 1))
        var propagation: float = .29 + float(distance - 1) * .055
        var direction: float = -1.0 if index % 2 == 0 else 1.0
        var lower_paint: ShaderMaterial = base.get_node("GelBody").material_override
        # Delay both the material and the physical lean until the wave
        # actually reaches this tier. Previously every lower brick wobbled
        # immediately, before the falling piece made contact.
        var gel_damping := create_tween()
        motion_tweens.append(gel_damping)
        gel_damping.tween_interval(propagation)
        gel_damping.tween_property(lower_paint, "shader_parameter/gel_spring",
            minf(.48, strength * 8.0), .065) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        gel_damping.tween_property(lower_paint, "shader_parameter/gel_spring",
            0.0, .60).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        _animate_gel_compression(lower_paint,
            minf(.28, strength * 5.2), propagation)
        var shake := create_tween()
        motion_tweens.append(shake)
        shake.tween_interval(propagation)
        shake.tween_property(base, "rotation",
            Vector3(strength * .50, 0.0, strength * direction), .11) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
        shake.tween_property(base, "rotation", Vector3.ZERO, .59) \
            .set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
        var lower_contact: Vector2 = _wave_center_on(bricks[index], entry)
        var lower_gain: float = minf(.50, strength * 8.3)
        _animate_gel_wave(lower_paint, lower_contact,
            lower_gain, propagation)
        _animate_gel_jiggle(lower_paint, lower_contact,
            minf(.62, lower_gain * 1.15), propagation)

## A full rebuild discarded all 31 surviving meshes, shader instances,
## stud buffers and soft contact nodes whenever Android Undo removed ONE
## piece. On a 32-brick stage that caused needless driver churn and a
## visible hitch. Preserve every remaining Node3D and ShaderMaterial;
## only remove the last saved brick, then reconcile contact/caustics.
## The save still happens before changing any render objects.
func _undo() -> void:
    if bricks.is_empty():
        return
    var removed: Dictionary = bricks.pop_back()
    if not figure_active and not _save():
        bricks.append(removed)
        _refresh_labels("Stockage indisponible · annulation conservée")
        return
    # Cancels pending landing callbacks BEFORE deleting their target.
    # With one fewer entry, _stop_motion safely settles only surviving
    # nodes and refreshes pigment contacts from the exact saved stack.
    _stop_motion()
    if not brick_nodes.is_empty():
        var last_piece: Node3D = brick_nodes.pop_back()
        if is_instance_valid(last_piece):
            if last_piece.get_parent() != null:
                last_piece.get_parent().remove_child(last_piece)
            last_piece.queue_free()
    _rebuild_occupancy()
    _refresh_caustics()
    if photo_mode:
        # Re-evaluate the bounded photo coat/shadow cutoffs on the
        # surviving geometry, without recreating their mesh resources.
        _set_gallery_coat(true)
        _update_photo_camera()
    else:
        _refresh_preview()
        if active:
            _apply_camera()
    host._play_feedback("undo", 9)
    _refresh_labels("Dernière brique retirée")

func _reset() -> void:
    var previous: Array[Dictionary] = bricks.duplicate(true)
    bricks.clear()
    if not figure_active and not _save():
        bricks = previous
        _refresh_labels("Stockage indisponible · atelier conservé")
        return
    _rebuild()
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

## Validate the complete structure rather than trusting a parseable JSON
## object with a 'schema' field. A bad primary must never supersede a good
## secondary generation, including after an autosave following recovery.
func _read_valid_studio_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parser := JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path)) != OK \
            or not parser.data is Dictionary:
        return {}
    var record: Dictionary = parser.data
    if record.get("schema", -1) != 1:
        return {}
    var verified: Dictionary = SAVE_TRANSFER.validate_studio(
        record.get("bricks", null))
    return verified if verified.get("ok", false) else {}

func _restore_or_seed() -> void:
    # Retain a structurally verified backup if an Android process stops
    # between the temporary write and the primary-file rename.
    for source in [SAVE_PATH, SAVE_PATH + ".bak"]:
        var verified: Dictionary = _read_valid_studio_file(source)
        if verified.get("ok", false) and _load_entries(verified["bricks"]):
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

## Portable export/import is separate from the local stack save.
## Never trust geometry from a user-provided Android SAF file.
func _export_entries() -> Array:
    return bricks.duplicate(true)

func _install_entries(incoming: Variant) -> bool:
    var checked: Dictionary = SAVE_TRANSFER.validate_studio(incoming)
    if not checked.get("ok", false):
        return false
    var previous: Array = bricks.duplicate(true)
    if not _load_entries(checked["bricks"]):
        _load_entries(previous)
        return false
    if not _save():
        _load_entries(previous)
        _rebuild()
        return false
    _rebuild()
    return true

func _save() -> bool:
    var temporary := SAVE_PATH + ".tmp"
    var f := FileAccess.open(temporary, FileAccess.WRITE)
    if f == null:
        push_warning("Cannot stage studio stack progress")
        return false
    f.store_string(JSON.stringify({"schema": 1, "bricks": bricks}))
    f.flush()
    var write_error: Error = f.get_error()
    f.close()
    if write_error != OK:
        DirAccess.remove_absolute(temporary)
        push_warning("Could not flush studio stack progress: " + str(write_error))
        return false
    # Reject corrupt JSON AND physically impossible saved stacks: neither
    # is safe to rotate into the only known-good .bak generation.
    if FileAccess.file_exists(SAVE_PATH) \
            and not _read_valid_studio_file(SAVE_PATH).is_empty():
        var backup_error: Error = DirAccess.copy_absolute(
            SAVE_PATH, SAVE_PATH + ".bak")
        if backup_error != OK:
            DirAccess.remove_absolute(temporary)
            push_warning("Cannot preserve previous studio generation: " + str(backup_error))
            return false
    var swap_error: Error = DirAccess.rename_absolute(temporary, SAVE_PATH)
    if swap_error != OK:
        DirAccess.remove_absolute(temporary)
        push_warning("Could not commit studio stack progress: " + str(swap_error))
        return false
    return true

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

func _reset_preview_inertia() -> void:
    preview_motion_energy = 0.0
    preview_drag_bend = Vector2.ZERO
    if preview_node != null and is_instance_valid(preview_node):
        var paint: ShaderMaterial = preview_node.get_node(
            "GelBody").material_override
        paint.set_shader_parameter("gel_spring", 0.0)
        paint.set_shader_parameter("studio_drag", Vector2.ZERO)

func _apply_preview_drag(before: Vector2i, after: Vector2i) -> void:
    var travel := Vector2(float(after.y - before.y),
        float(after.x - before.x))
    if travel.length_squared() < .001:
        return
    # 1 grid cell = 0.5 unit of drag; cap both speed and vertex motion.
    # The actual collision and snap positions always remain unchanged.
    preview_drag_bend = travel.limit_length(2.0) * .5
    preview_motion_energy = minf(.65, .20 + travel.length() * .12)
    if preview_node != null:
        var paint: ShaderMaterial = preview_node.get_node(
            "GelBody").material_override
        paint.set_shader_parameter("gel_spring", preview_motion_energy)
        paint.set_shader_parameter("studio_drag", preview_drag_bend)

func _track(screen: Vector2, commit: bool) -> void:
    if not _usable_area(screen):
        return
    var hit := _point_to_cell(screen)
    if hit.x < 0 or hit.y < 0 or hit.x >= GRID or hit.y >= GRID:
        return
    if hit != selected_cell:
        var previous: Vector2i = selected_cell
        selected_cell = hit
        _refresh_preview()
        _apply_preview_drag(previous, hit)
    if commit:
        _commit()

## Gallery controls are independent from the brick-placement touch
## machinery. Pinching affects only the Camera3D orthographic size; a drag
## rotates the product. Gestures never commit a new brick or alter saves.
func _clear_photo_gestures() -> void:
    photo_touch_points.clear()
    photo_pinch_span = 0.0
    photo_mouse_drag = false
    photo_resume_wait = 0.0

func _photo_touch_span() -> float:
    if photo_touch_points.size() < 2:
        return 0.0
    var samples: Array = photo_touch_points.values()
    var first: Vector2 = samples[0]
    var second: Vector2 = samples[1]
    return first.distance_to(second)

func _handle_photo_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            photo_touch_points[event.index] = event.position
        else:
            photo_touch_points.erase(event.index)
            if photo_touch_points.is_empty():
                photo_resume_wait = PHOTO_GESTURE_COOLDOWN
        photo_pinch_span = _photo_touch_span()
    elif event is InputEventScreenDrag:
        if not photo_touch_points.has(event.index):
            return
        photo_touch_points[event.index] = event.position
        if photo_touch_points.size() >= 2:
            var span: float = _photo_touch_span()
            if span > 12.0 and photo_pinch_span > 12.0:
                photo_zoom = clampf(photo_zoom * photo_pinch_span / span,
                    .70, 1.75)
            photo_pinch_span = span
        else:
            photo_angle = fposmod(photo_angle -
                event.relative.x * .006, TAU)
        _update_photo_camera()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if photo_touch_points.is_empty():
            if photo_mouse_drag and not event.pressed:
                photo_resume_wait = PHOTO_GESTURE_COOLDOWN
            photo_mouse_drag = event.pressed
    elif event is InputEventMouseMotion and photo_mouse_drag \
            and photo_touch_points.is_empty():
        photo_angle = fposmod(photo_angle -
            event.relative.x * .006, TAU)
        _update_photo_camera()

func handle_input(event: InputEvent) -> void:
    if not active:
        return
    if photo_mode:
        _handle_photo_input(event)
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            play_touch_contacts[event.index] = true
            if play_touch_contacts.size() > 1:
                play_multitouch_blocked = true
                # No lingering rubber band after a canceled pinch.
                _reset_preview_inertia()
                if preview_node != null:
                    preview_node.visible = false
            elif not play_multitouch_blocked and active_touch_index == -1 \
                    and _usable_area(event.position):
                active_touch_index = event.index
                play_multitouch_blocked = false
                _track(event.position, false)
        else:
            if event.index == active_touch_index:
                if not event.canceled and not play_multitouch_blocked:
                    _track(event.position, true)
                active_touch_index = -1
            play_touch_contacts.erase(event.index)
            if play_touch_contacts.is_empty():
                play_multitouch_blocked = false
    elif event is InputEventScreenDrag and event.index == active_touch_index:
        if not play_multitouch_blocked:
            _track(event.position, false)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            mouse_held = _usable_area(event.position) and play_touch_contacts.is_empty()
            if mouse_held:
                _track(event.position, false)
        else:
            if mouse_held and play_touch_contacts.is_empty():
                _track(event.position, true)
            mouse_held = false
    elif event is InputEventMouseMotion and mouse_held and play_touch_contacts.is_empty():
        _track(event.position, false)
