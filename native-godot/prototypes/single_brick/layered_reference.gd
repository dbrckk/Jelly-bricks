extends "res://prototypes/single_brick/soft_reference_mobile.gd"
## Experimental two-stage translucent jelly composition.
## Pass A : studio only (view layers 1).
## Pass B : studio + lower RED gel (view layers 1 | 2).
## Main   : studio + red + upper BLUE gel (layers 1 | 2 | 4).
## The upper blue gel samples pass B, not the empty studio texture.
## The lower red gel samples pass A. There is no recursive viewport.
##
## Deliberately separated from the 21 production levels and Physics Lab.
const STAGE2_LAYER := 4
const BLUE_DYE := Color("#345de0")
var upper_brick: Node3D
var upper_shell: MeshInstance3D
var upper_coat: MeshInstance3D
var upper_studs: MultiMeshInstance3D
var upper_paint: ShaderMaterial
var upper_coat_paint: ShaderMaterial
var upper_stud_paint: ShaderMaterial
var foreground_viewport: SubViewport
var foreground_camera: Camera3D
var stack_enabled: bool = true
var stack_toggle: Button
var quality_toggle: Button
var lightweight_mode: bool = true
var upper_triangles: int = 0
var perf_label: Label
var perf_elapsed: float = 0.0

func _ready() -> void:
    super._ready()
    name = "TwoGelLayerReview"
    _make_second_optical_pass()
    _make_blue_brick()
    _make_stack_controls()
    sample_reference("rest")
    pose_label.text = "Gel rouge + bleu - deux briques"
    _apply_render_budget()

func _make_second_optical_pass() -> void:
    foreground_viewport = SubViewport.new()
    foreground_viewport.name = "StudioAndLowerGel"
    foreground_viewport.own_world_3d = false
    foreground_viewport.transparent_bg = false
    foreground_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    foreground_viewport.msaa_3d = Viewport.MSAA_DISABLED
    add_child(foreground_viewport)

    foreground_camera = Camera3D.new()
    foreground_camera.name = "ViewStudioAndRedButNotBlue"
    foreground_camera.cull_mask = 3
    foreground_camera.current = true
    foreground_viewport.add_child(foreground_camera)
    _sync_second_camera()

func _make_blue_brick() -> void:
    # Create a distinct, shorter 1x1 brick, matching the alternating
    # red-long/blue-short proportions of the reference movie.
    upper_brick = brick_root.duplicate(0) as Node3D
    upper_brick.name = "BlueShortGelAboveRed"
    add_child(upper_brick)

    upper_shell = upper_brick.get_node("CurvedShellWithSocket") as MeshInstance3D
    upper_coat = upper_brick.get_node("ThinOpticalClearcoat") as MeshInstance3D
    upper_studs = upper_brick.get_node("ActualFourMoldedStuds") as MultiMeshInstance3D
    # Never reuse the red mesh's material instance: changing upper blue
    # shader settings must not recolor the lower brick or vice versa.
    upper_paint = gel_material.duplicate() as ShaderMaterial
    upper_paint.shader = BACKDROP_GEL
    upper_paint.set_shader_parameter("pigment", BLUE_DYE)
    upper_paint.set_shader_parameter("brick_extent", Vector2.ONE)
    upper_paint.set_shader_parameter(
        "backdrop_tex", foreground_viewport.get_texture())
    upper_paint.set_shader_parameter("backdrop_strength", 0.76)
    upper_paint.set_shader_parameter("refraction_pixels", 3.4)

    # Full, correctly wound 1x1 body and coat, tessellated ONCE.
    var compact_mesh: ArrayMesh = FINE.tessellate(
        _corrected_studio_mesh(1), 2)
    upper_triangles = FINE.triangle_count(compact_mesh)
    upper_shell.mesh = compact_mesh
    upper_coat.mesh = compact_mesh
    upper_shell.material_override = upper_paint

    upper_coat_paint = (wet_coat.material_override as ShaderMaterial).duplicate()
    upper_coat_paint.set_shader_parameter("brick_extent", Vector2.ONE)
    upper_coat.material_override = upper_coat_paint

    var caps := upper_studs.multimesh.duplicate() as MultiMesh
    caps.instance_count = 2
    for lane in range(2):
        caps.set_instance_transform(lane,
            Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.68, 1.0)),
                Vector3(0.5, 0.18944, 0.265 if lane == 0 else 0.735)))
    upper_studs.multimesh = caps
    upper_stud_paint = (studs.material_override as ShaderMaterial).duplicate()
    upper_stud_paint.set_shader_parameter("pigment", BLUE_DYE)
    upper_studs.material_override = upper_stud_paint

    # Visible ONLY in the main camera. The second pass sees red but
    # never blue, so sampling it cannot recurse into itself.
    upper_shell.layers = STAGE2_LAYER
    upper_coat.layers = STAGE2_LAYER
    upper_studs.layers = STAGE2_LAYER

func _make_stack_controls() -> void:
    var column := mobile_hud.get_node(
        "ReviewOverlay/ReviewControls/ControlColumn") as VBoxContainer
    var row := HBoxContainer.new()
    row.name = "StackControls"
    row.add_theme_constant_override("separation", 9)
    column.add_child(row)

    stack_toggle = Button.new()
    stack_toggle.name = "ToggleStack"
    stack_toggle.text = "PILE: 2 BRIQUES"
    stack_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stack_toggle.custom_minimum_size.y = 48.0
    stack_toggle.add_theme_font_size_override("font_size", 16)
    stack_toggle.pressed.connect(_toggle_stack)
    row.add_child(stack_toggle)

    quality_toggle = Button.new()
    quality_toggle.name = "ToggleQuality"
    quality_toggle.text = "GPU: ECO"
    quality_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quality_toggle.custom_minimum_size.y = 48.0
    quality_toggle.add_theme_font_size_override("font_size", 16)
    quality_toggle.pressed.connect(_toggle_quality)
    row.add_child(quality_toggle)

    var controls_panel := mobile_hud.get_node(
        "ReviewOverlay/ReviewControls") as PanelContainer
    controls_panel.offset_top = -316.0
    # Android-specific diagnostics: lets the player inspect actual FPS and
    # the effective extra GPU render resolutions on their own device.
    var header := mobile_hud.get_node(
        "ReviewOverlay/Header") as PanelContainer
    var header_content := header.get_child(0) as VBoxContainer
    var main_title := header_content.get_child(0) as Label
    main_title.text = "JELLY BRICKS  /  PILE BICOLORE"
    perf_label = _label(
        "FPS: --  |  passes GPU: 2", 16, Color("#c5d5ec"))
    perf_label.name = "RenderBudgetStats"
    header_content.add_child(perf_label)

func _toggle_stack() -> void:
    set_stack_enabled(not stack_enabled)

func set_stack_enabled(enabled: bool) -> void:
    stack_enabled = enabled
    if upper_brick != null:
        upper_brick.visible = enabled
    if stack_toggle != null:
        stack_toggle.text = (
            "PILE: 2 BRIQUES" if enabled else "PILE: 1 BRIQUE")
    _apply_render_budget()

func _toggle_quality() -> void:
    lightweight_mode = not lightweight_mode
    if quality_toggle != null:
        quality_toggle.text = (
            "GPU: ECO" if lightweight_mode else "GPU: DETAIL")
    _apply_render_budget()

func _apply_render_budget() -> void:
    if foreground_viewport == null:
        return
    # When there is only one brick, the upper pass is unnecessary.
    foreground_viewport.render_target_update_mode = (
        SubViewport.UPDATE_ALWAYS if (
            stack_enabled and transmission_enabled)
        else SubViewport.UPDATE_DISABLED)
    if not stack_enabled:
        return
    var source_size: Vector2 = get_viewport().get_visible_rect().size
    var fraction := 0.34 if lightweight_mode else 0.50
    foreground_viewport.size = Vector2i(
        clampi(int(source_size.x * fraction), 200, 540),
        clampi(int(source_size.y * fraction), 280, 960))

func _sync_second_camera() -> void:
    if foreground_camera == null or camera == null:
        return
    foreground_camera.projection = camera.projection
    foreground_camera.keep_aspect = camera.keep_aspect
    foreground_camera.size = camera.size
    foreground_camera.near = camera.near
    foreground_camera.far = camera.far
    foreground_camera.global_transform = camera.global_transform

func sample_reference(state: String) -> void:
    super.sample_reference(state)
    if upper_brick == null:
        return
    # This is still a visual comparison, not real deformable-body physics.
    # The top small brick follows the compressing surface of the red brick.
    var squash_value := 0.0
    var lag := 0.0
    match state:
        "compression":
            squash_value = 0.19
            lag = -0.11
        "rebound":
            squash_value = -0.055
            lag = 0.07
    upper_brick.position = Vector3(
        0.5, 0.55 - maxf(0.0, squash_value) * 0.48, 0.0)
    upper_paint.set_shader_parameter("deformation", squash_value)
    upper_coat_paint.set_shader_parameter("deformation", squash_value)
    upper_paint.set_shader_parameter("silhouette_softness", 0.85)
    upper_coat_paint.set_shader_parameter("silhouette_softness", 0.85)
    upper_paint.set_shader_parameter("momentum_lag", lag)
    upper_coat_paint.set_shader_parameter("momentum_lag", lag)

func set_transmission_enabled(enabled: bool) -> void:
    super.set_transmission_enabled(enabled)
    if upper_paint != null:
        upper_paint.set_shader_parameter(
            "backdrop_strength", 0.76 if enabled else 0.0)
    _apply_render_budget()

func _process(delta: float) -> void:
    super._process(delta)
    _sync_second_camera()
    perf_elapsed += maxf(delta, 0.0)
    if perf_elapsed > 0.50 and perf_label != null:
        perf_elapsed = 0.0
        var count := 1 if transmission_enabled else 0
        if stack_enabled and transmission_enabled:
            count += 1
        perf_label.text = "FPS: %d  |  GPU: %d passe(s)  |  %dx%d" % [
            Engine.get_frames_per_second(), count,
            backdrop_frame_size.x, backdrop_frame_size.y]
    if stack_enabled and foreground_viewport != null:
        # Keep the second optical texture at its intended reduced size
        # if Android rotates or viewport metrics change.
        var target_fraction := 0.34 if lightweight_mode else 0.50
        var screen: Vector2 = get_viewport().get_visible_rect().size
        var expected := Vector2i(
            clampi(int(screen.x * target_fraction), 200, 540),
            clampi(int(screen.y * target_fraction), 280, 960))
        if foreground_viewport.size != expected:
            foreground_viewport.size = expected
