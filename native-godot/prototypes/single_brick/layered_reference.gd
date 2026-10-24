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
# An actual 1x1 brick must seat over ONE full column of the base's 2x1
# studs. The old X=0.5 straddled both columns and exposed red studs
# through the blue FRONT WALL, as seen in the real Android screenshot.
const BLUE_SEAT_X := 1.0
const GEL_HEIGHT := 0.505
const LAB_COMPRESSION_FACTOR := 0.29
const RED_SUPPORT_DROP := GEL_HEIGHT * LAB_COMPRESSION_FACTOR
const COUPLED_SPRINGS = preload(
    "res://prototypes/single_brick/coupled_gel_springs.gd")
var elastic_pair: Variant = COUPLED_SPRINGS.new()
var motion_active: bool = false
var last_impact_time: float = 0.0
var impact_button: Button
var peak_live_red: float = 0.0
var peak_live_blue: float = 0.0
var peak_live_lag: float = 0.0
# Visible deformation gain is intentionally independent from the stable
# spring solver. Raise the gel squash on Android without changing solver
# energy, collision volumes or causing time-step instability.
var visual_gain: float = 1.90
var force_slider: HSlider
var force_readout: Label
var peak_visual_red: float = 0.0
var peak_visual_blue: float = 0.0
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
var upper_mesh_eco: ArrayMesh
var upper_mesh_detail: ArrayMesh
var upper_triangles_eco: int = 0
var upper_triangles_detail: int = 0
var perf_label: Label
var perf_elapsed: float = 0.0
var organic_material_enabled: bool = true
var organic_toggle: Button
var deep_gel_enabled: bool = true
var deep_gel_toggle: Button

func _ready() -> void:
    super._ready()
    name = "TwoGelLayerReview"
    _make_second_optical_pass()
    _make_blue_brick()
    _make_stack_controls()
    set_organic_material_enabled(true)
    set_deep_gel_enabled(true)
    # Volume-corrected GPU outlines only for this experimental two-layer
    # studio. Older single-brick screenshots and production stay unchanged.
    gel_material.set_shader_parameter("volume_conservation", 0.93)
    var red_coat := wet_coat.material_override as ShaderMaterial
    red_coat.set_shader_parameter("volume_conservation", 0.93)
    upper_paint.set_shader_parameter("volume_conservation", 0.93)
    upper_coat_paint.set_shader_parameter("volume_conservation", 0.93)
    # The softness gain affects actual GPU vertices, not only a displayed
    # number. Matching red/blue coat/core uniforms prevent coating tears.
    for material in [gel_material, red_coat, upper_paint, upper_coat_paint]:
        material.set_shader_parameter("gel_malleability", 1.0)
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
    upper_paint.set_shader_parameter("highlight_softness", 0.86)

    # Full, correctly wound 1x1 body and coat, tessellated ONCE.
    # Prebuild BOTH LODs only once. The lower 2x1 is full quality;
    # on the blue 1x1 the ECO button saves 75% of shell + coat triangles.
    var compact_source := _corrected_studio_mesh(1)
    upper_mesh_eco = FINE.tessellate(compact_source, 1)
    upper_mesh_detail = FINE.tessellate(compact_source, 2)
    upper_triangles_eco = FINE.triangle_count(upper_mesh_eco)
    upper_triangles_detail = FINE.triangle_count(upper_mesh_detail)
    upper_triangles = upper_triangles_eco
    upper_shell.mesh = upper_mesh_eco
    upper_coat.mesh = upper_mesh_eco
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
    upper_stud_paint.set_shader_parameter("milkiness", 0.20)
    upper_stud_paint.set_shader_parameter("wetness", 0.32)
    upper_studs.material_override = upper_stud_paint
    (studs.material_override as ShaderMaterial).set_shader_parameter(
        "milkiness", 0.20)
    (studs.material_override as ShaderMaterial).set_shader_parameter(
        "wetness", 0.32)
    # The additive white coat previously produced clipped triangles
    # across both top faces. Keep small *tinted* meniscus highlights.
    upper_coat_paint.set_shader_parameter("coat_strength", 0.075)
    upper_coat_paint.set_shader_parameter(
        "light_color", BLUE_DYE.lerp(Color.WHITE, 0.48))
    (wet_coat.material_override as ShaderMaterial).set_shader_parameter(
        "coat_strength", 0.073)
    (wet_coat.material_override as ShaderMaterial).set_shader_parameter(
        "light_color", Color("#c8233c").lerp(Color.WHITE, 0.48))
    gel_material.set_shader_parameter("highlight_softness", 0.86)

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

    impact_button = Button.new()
    impact_button.name = "TriggerGelRebound"
    impact_button.text = "CHOC GEL"
    impact_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    impact_button.custom_minimum_size.y = 48.0
    impact_button.add_theme_font_size_override("font_size", 16)
    impact_button.focus_mode = Control.FOCUS_NONE
    impact_button.pressed.connect(trigger_elastic_impact)
    row.add_child(impact_button)

    # Compare the improved gelatin directly against the earlier plastic-
    # looking material, without modifying the stable physics or viewports.
    var optical_controls := mobile_hud.get_node(
        "ReviewOverlay/ReviewControls/ControlColumn/OpticModes") as HBoxContainer
    organic_toggle = Button.new()
    organic_toggle.name = "ToggleOrganicMaterial"
    organic_toggle.text = "GEL: OUI"
    organic_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    organic_toggle.custom_minimum_size.y = 56.0
    organic_toggle.add_theme_font_size_override("font_size", 16)
    organic_toggle.pressed.connect(_toggle_organic_material)
    optical_controls.add_child(organic_toggle)
    deep_gel_toggle = Button.new()
    deep_gel_toggle.name = "ToggleDeepGel"
    deep_gel_toggle.text = "PROF: OUI"
    deep_gel_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    deep_gel_toggle.custom_minimum_size.y = 56.0
    deep_gel_toggle.add_theme_font_size_override("font_size", 15)
    deep_gel_toggle.focus_mode = Control.FOCUS_NONE
    deep_gel_toggle.pressed.connect(_toggle_deep_gel)
    optical_controls.add_child(deep_gel_toggle)

    var force_row := HBoxContainer.new()
    force_row.name = "DeformationRange"
    force_row.add_theme_constant_override("separation", 9)
    column.add_child(force_row)
    force_readout = _label("GEL FORT 190%", 16, Color("#c6f1dc"))
    force_readout.name = "CurrentStrength"
    force_readout.custom_minimum_size.x = 154.0
    force_row.add_child(force_readout)
    force_slider = HSlider.new()
    force_slider.name = "DeformationSlider"
    force_slider.min_value = 1.0
    force_slider.max_value = 2.2
    force_slider.step = 0.1
    force_slider.value = visual_gain
    force_slider.custom_minimum_size.y = 38.0
    force_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    force_slider.value_changed.connect(set_visual_gain)
    force_row.add_child(force_slider)

    var controls_panel := mobile_hud.get_node(
        "ReviewOverlay/ReviewControls") as PanelContainer
    controls_panel.offset_top = -330.0
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

func _toggle_organic_material() -> void:
    set_organic_material_enabled(not organic_material_enabled)

func set_organic_material_enabled(enabled: bool) -> void:
    organic_material_enabled = enabled
    var organic: float = 0.90 if enabled else 0.0
    for paint in [gel_material, upper_paint]:
        if paint != null:
            paint.set_shader_parameter("organic_gel", organic)
    # Keep identical vertex swell between tinted gel and additive coat.
    var swell: float = 0.92 if enabled else 0.0
    for paint in [gel_material,
            wet_coat.material_override as ShaderMaterial,
            upper_paint, upper_coat_paint]:
        if paint != null:
            paint.set_shader_parameter("organic_rest_swell", swell)
    if organic_toggle != null:
        organic_toggle.text = "GEL: OUI" if enabled else "GEL: NON"

func _toggle_deep_gel() -> void:
    set_deep_gel_enabled(not deep_gel_enabled)

func set_deep_gel_enabled(enabled: bool) -> void:
    deep_gel_enabled = enabled
    # Core and optically dyed coat change together. No geometry changes
    # to the game or CPU collision shape and no extra GPU sub-viewport.
    var strength: float = 0.92 if enabled else 0.0
    for paint in [gel_material, upper_paint]:
        if paint != null:
            paint.set_shader_parameter("deep_gel", strength)
    for paint in [
            wet_coat.material_override as ShaderMaterial,
            upper_coat_paint]:
        if paint != null:
            paint.set_shader_parameter("deep_gel", strength)
    # The transparent additive coat drew a ruler-straight WHITE stripe
    # across each brick in actual Godot captures. The opaque gel already
    # computes its own tinted specular light and volume scattering.
    # Skip the duplicate clearcoat entirely in deep mode; this saves two
    # glossy draw surfaces and avoids transparency overdraw on Android.
    if wet_coat != null:
        wet_coat.visible = not enabled
    if upper_coat != null:
        upper_coat.visible = not enabled
    if deep_gel_toggle != null:
        deep_gel_toggle.text = "PROF: OUI" if enabled else "PROF: NON"

func set_visual_gain(value: float) -> void:
    visual_gain = clampf(value, 1.0, 2.2)
    if force_readout != null:
        force_readout.text = "GEL FORT %d%%" % int(roundf(
            visual_gain * 100.0))
    # The slider must also update a paused or explicitly sampled spring
    # frame (not only a running Android animation). If the user selected a
    # legacy static REPOS / IMPACT pose, there is no active spring to alter.
    if motion_active or float(elastic_pair.simulation_time) > 0.0001:
        _apply_coupled_movement()

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
    # Geometry LOD and offscreen resolution change together. The coat
    # MUST share the exact same mesh instance as the pigmented core.
    var selected: ArrayMesh = (
        upper_mesh_eco if lightweight_mode else upper_mesh_detail)
    if selected != null and upper_shell.mesh != selected:
        upper_shell.mesh = selected
        upper_coat.mesh = selected
    if selected != null:
        upper_triangles = (
            upper_triangles_eco if lightweight_mode
            else upper_triangles_detail)
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
    motion_active = false
    elastic_pair.reset()
    last_impact_time = 0.0
    peak_live_red = 0.0
    peak_live_blue = 0.0
    peak_visual_red = 0.0
    peak_visual_blue = 0.0
    peak_live_lag = 0.0
    super.sample_reference(state)
    # A REPOS or manually selected static pose must never preserve a
    # residual traveling impact wave from the previous live spring.
    if wet_coat != null and gel_material != null:
        _set_interface_wave(gel_material,
            wet_coat.material_override as ShaderMaterial,
            Vector3(BLUE_SEAT_X + 0.5, 0.52, 0.5), 0.0, 3.0)
    if upper_brick == null:
        return
    _set_interface_wave(upper_paint, upper_coat_paint,
        Vector3(0.5, 0.06, 0.5), 0.0, 3.0)
    # This is still a visual comparison, not real deformable-body physics.
    # The top small brick follows the compressing surface of the red brick.
    var squash_value := 0.0
    var red_support_squash := 0.0
    var lag := 0.0
    match state:
        "compression":
            squash_value = 0.19
            red_support_squash = 0.83
            lag = -0.11
        "rebound":
            squash_value = -0.055
            red_support_squash = -0.19
            lag = 0.07
    # Blue must ride the actual red crown, not its OWN squash amount.
    # The old formula sunk the top piece when pressed and left a visual gap
    # when the red brick bounced above its rest height.
    upper_brick.position = Vector3(
        BLUE_SEAT_X, 0.55 - red_support_squash * RED_SUPPORT_DROP, 0.0)
    studs.scale.y = maxf(0.73,
        1.0 - red_support_squash * LAB_COMPRESSION_FACTOR)
    upper_paint.set_shader_parameter("deformation", squash_value)
    upper_coat_paint.set_shader_parameter("deformation", squash_value)
    upper_studs.scale.y = maxf(0.73,
        1.0 - squash_value * LAB_COMPRESSION_FACTOR)
    upper_paint.set_shader_parameter("silhouette_softness", 0.85)
    upper_coat_paint.set_shader_parameter("silhouette_softness", 0.85)
    upper_paint.set_shader_parameter("momentum_lag", lag)
    upper_coat_paint.set_shader_parameter("momentum_lag", lag)

## This is a coupled viscoelastic VISUAL laboratory driven by true
## integration over time, not the previous instant three-pose animation.
## Do not confuse it with a solved soft-body collision volume.
func trigger_elastic_impact() -> void:
    # Repeated taps add real energy to the current spring motion instead
    # of snapping the scene back to its rest pose every time.
    if not motion_active:
        sample_reference("rest")
        elastic_pair.strike(1.0)
    else:
        elastic_pair.strike(0.76)
    last_impact_time = float(elastic_pair.simulation_time)
    motion_active = true
    pose_label.text = "Oscillation elastique : rouge + bleu"

## For real GPU visual QA, sample the SAME numerical spring integrator at
## specified simulation times. This removes Mesa software rasterizer latency
## from the captured impact/rebound phase while preserving real shader output.
## Never called by the live Android CHOC GEL button.
func preview_elastic_sample(seconds: float) -> void:
    sample_reference("rest")
    elastic_pair.strike(1.0)
    last_impact_time = 0.0
    var iterations: int = clampi(int(roundf(
        maxf(seconds, 0.0) / COUPLED_SPRINGS.STEP)), 0, 600)
    for i in range(iterations):
        elastic_pair.integrate(COUPLED_SPRINGS.STEP)
    motion_active = false
    _apply_coupled_movement()
    pose_label.text = "Gel reel calcule a %.2f s" % seconds

func _physics_process(delta: float) -> void:
    if not motion_active:
        return
    elastic_pair.integrate(delta)
    _apply_coupled_movement()
    if not elastic_pair.active:
        motion_active = false
        pose_label.text = "Gel stabilise - toucher CHOC GEL"

func _apply_coupled_movement() -> void:
    var lower: float = clampf(
        float(elastic_pair.red) * visual_gain, -0.27, 0.88)
    var upper: float = clampf(
        float(elastic_pair.blue) * visual_gain, -0.27, 0.88)
    var red_lag := clampf(elastic_pair.red_velocity * 0.021, -0.28, 0.28)
    var blue_lag := clampf(elastic_pair.blue_velocity * 0.025, -0.35, 0.35)

    # Keep base support at y=0; crown falls by 19% of its 0.515m height
    # per unit squash. Blue contact stays above that moving crown.
    _apply_state("elastic", 0.0, red_lag * 0.22, lower)
    _set_soft_pose(0.97, red_lag)
    var red_wave := clampf(
        absf(elastic_pair.red_velocity) * 0.055, 0.0, 0.55)
    gel_material.set_shader_parameter("ripple_energy", red_wave)
    (wet_coat.material_override as ShaderMaterial).set_shader_parameter(
        "ripple_energy", red_wave)
    var red_time: float = float(elastic_pair.simulation_time)
    gel_material.set_shader_parameter("ripple_phase", red_time * 15.0)
    (wet_coat.material_override as ShaderMaterial).set_shader_parameter(
        "ripple_phase", red_time * 15.0)
    # Physically motivated VISUAL approximation of the force transmitted
    # through the interface (red crown / blue underside). Distinct from
    # Physics Lab v4, which gets contact coordinates from Godot's solver.
    # The two layers use identical values so the wet coat never shears off.
    var contact_age := clampf(
        red_time - last_impact_time, 0.0, 3.0)
    var red_pulse := 0.80 * exp(-contact_age * 4.5)
    var blue_pulse := 0.70 * exp(-contact_age * 4.8)
    _set_interface_wave(gel_material,
        wet_coat.material_override as ShaderMaterial,
        Vector3(BLUE_SEAT_X + 0.5, 0.52, 0.5), red_pulse, contact_age)
    _set_interface_wave(upper_paint, upper_coat_paint,
        Vector3(0.5, 0.06, 0.5), blue_pulse, contact_age)
    # The actual blue two-stud mesh follows its spring and its red support;
    # both optical materials use precisely the same vertex parameters.
    upper_brick.position = Vector3(
        BLUE_SEAT_X + clampf(red_lag * 0.045, -0.015, 0.015),
        0.55 - lower * RED_SUPPORT_DROP,
        clampf(blue_lag * 0.016, -0.014, 0.014))
    studs.scale.y = maxf(0.73,
        1.0 - lower * LAB_COMPRESSION_FACTOR)
    upper_paint.set_shader_parameter("deformation", upper)
    upper_coat_paint.set_shader_parameter("deformation", upper)
    upper_paint.set_shader_parameter("silhouette_softness", 0.97)
    upper_coat_paint.set_shader_parameter("silhouette_softness", 0.97)
    upper_paint.set_shader_parameter("momentum_lag", blue_lag)
    upper_coat_paint.set_shader_parameter("momentum_lag", blue_lag)
    var blue_wave := clampf(
        absf(elastic_pair.blue_velocity) * 0.045, 0.0, 0.55)
    upper_paint.set_shader_parameter("ripple_energy", blue_wave)
    upper_coat_paint.set_shader_parameter("ripple_energy", blue_wave)
    upper_paint.set_shader_parameter(
        "ripple_phase", red_time * 18.0 + 0.3)
    upper_coat_paint.set_shader_parameter(
        "ripple_phase", red_time * 18.0 + 0.3)
    upper_studs.scale.y = maxf(0.73,
        1.0 - upper * LAB_COMPRESSION_FACTOR)
    peak_live_red = maxf(peak_live_red, float(elastic_pair.red))
    peak_live_blue = maxf(peak_live_blue, float(elastic_pair.blue))
    peak_visual_red = maxf(peak_visual_red, lower)
    peak_visual_blue = maxf(peak_visual_blue, upper)
    peak_live_lag = maxf(peak_live_lag, absf(blue_lag - red_lag))

func _set_interface_wave(core: ShaderMaterial, coat: ShaderMaterial,
        point: Vector3, energy: float, seconds: float) -> void:
    # Keep exact parity across optical surface layers; avoids the
    # disconnected plastic shell appearance at high gel amplitude.
    for target in [core, coat]:
        target.set_shader_parameter("impact_local_point", point)
        target.set_shader_parameter(
            "impact_local_energy", clampf(energy, 0.0, 0.85))
        target.set_shader_parameter("impact_local_age", seconds)

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
        perf_label.text = "FPS:%d | GPU:%d | Bleu:%d tr. | %dx%d" % [
            Engine.get_frames_per_second(), count,
            upper_triangles,
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
