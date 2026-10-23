extends "res://prototypes/single_brick/scene.gd"
## Production-safe SINGLE RED 2x1 reference. Unlike the mobile game or
## physics lab, this scene tests the maximum studio tessellation and gel
## optical controls. The unmodified studio generator remains the baseline.
const FINE = preload("res://prototypes/single_brick/subdivided_studio_mesh.gd")
const STUD_WET = preload("res://prototypes/single_brick/wet_stud.gdshader")
const OPAQUE_GEL = preload("res://prototypes/single_brick/wet_gel_opaque_reference.gdshader")
const BACKDROP_GEL = preload("res://prototypes/single_brick/wet_gel_viewport_reference.gdshader")
const TEST_CARD = preload("res://prototypes/single_brick/transmission_test_card.gdshader")
var base_triangles: int = 0
var fine_triangles: int = 0
var backdrop_viewport: SubViewport
var backdrop_camera: Camera3D
var test_card: MeshInstance3D
var diagnostic_background_enabled: bool = false
var transmission_enabled: bool = true
var backdrop_frame_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
    super._ready()
    time_enabled = false
    manual_pose = true
    var before := shell.mesh as ArrayMesh
    base_triangles = FINE.triangle_count(before)
    var dense: ArrayMesh = FINE.tessellate(before, 2)
    fine_triangles = FINE.triangle_count(dense)
    # The same indexed mesh keeps the optical coating attached at all times.
    shell.mesh = dense
    wet_coat.mesh = dense
    # Sampling SCREEN_TEXTURE categorizes Godot Compatibility materials as
    # transparent, showing the hollow socket roof through the front cap.
    # Use a shader variant WITHOUT screen reads to test correct geometry.
    gel_material.shader = OPAQUE_GEL
    var dye := Color("#c8233c")
    gel_material.set_shader_parameter("pigment", dye)
    gel_material.set_shader_parameter("bulk_optics", 0.66)
    gel_material.set_shader_parameter("gel_milkiness", 0.22)
    gel_material.set_shader_parameter("interior_scatter", 0.44)
    gel_material.set_shader_parameter("highlights", 0.63)
    var cap_mat := ShaderMaterial.new()
    cap_mat.shader = STUD_WET
    cap_mat.set_shader_parameter("pigment", dye)
    studs.material_override = cap_mat
    var coat := wet_coat.material_override as ShaderMaterial
    coat.set_shader_parameter("coat_strength", 0.21)
    _build_isolated_backdrop()
    sample_reference("rest")

func sample_reference(state: String) -> void:
    manual_pose = true
    time_enabled = false
    match state:
        "rest":
            _apply_state("rest", 0.0, 0.0, 0.0)
            _set_soft_pose(0.0, 0.0)
        "compression":
            _apply_state("contact", 0.0, 0.11, 0.83)
            _set_soft_pose(1.0, 0.22)
        "rebound":
            _apply_state("rebound", 0.05, -0.08, -0.19)
            _set_soft_pose(1.0, -0.17)
        "settled":
            _apply_state("settled", 0.0, 0.0, 0.0)
            _set_soft_pose(0.0, 0.0)
        _:
            push_error("Unknown red reference pose: " + state)

func _set_soft_pose(softness: float, lag: float) -> void:
    gel_material.set_shader_parameter("silhouette_softness", softness)
    gel_material.set_shader_parameter("momentum_lag", lag)
    var coat := wet_coat.material_override as ShaderMaterial
    coat.set_shader_parameter("silhouette_softness", softness)
    coat.set_shader_parameter("momentum_lag", lag)

## Split-scene rendering makes a meaningful image-driven refraction possible
## without sampling the CURRENT framebuffer. Core depth remains opaque and
## the bottom socket roof cannot bleed through the front surface.
## One half-resolution background render; no expensive texture readback.
func _build_isolated_backdrop() -> void:
    # Mask bit 1 is studio-only; the physical gel, optical coat and studs
    # render on layer bit 2 in the main view and not in the backdrop view.
    shell.layers = 2
    wet_coat.layers = 2
    studs.layers = 2

    test_card = MeshInstance3D.new()
    test_card.name = "BackgroundOpticsDiagnosticCard"
    var card_mesh := PlaneMesh.new()
    card_mesh.size = Vector2(3.7, 2.9)
    test_card.mesh = card_mesh
    var card_mat := ShaderMaterial.new()
    card_mat.shader = TEST_CARD
    test_card.material_override = card_mat
    test_card.position = Vector3(1.0, 0.026, 0.5)
    test_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    test_card.layers = 1
    test_card.visible = false
    add_child(test_card)

    backdrop_viewport = SubViewport.new()
    backdrop_viewport.name = "FloorOnlyOpticalBackground"
    backdrop_viewport.own_world_3d = false
    backdrop_viewport.transparent_bg = false
    backdrop_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    backdrop_viewport.msaa_3d = Viewport.MSAA_DISABLED
    add_child(backdrop_viewport)

    backdrop_camera = Camera3D.new()
    backdrop_camera.name = "MatchingBackdropCamera"
    backdrop_camera.cull_mask = 1
    backdrop_camera.current = true
    backdrop_viewport.add_child(backdrop_camera)
    _sync_backdrop_camera()

    # Ordinary sampler2D: no hint_screen_texture and no ALPHA. Therefore the
    # core stays in the opaque depth pass despite sampling rendered pixels.
    gel_material.shader = BACKDROP_GEL
    gel_material.set_shader_parameter(
        "backdrop_tex", backdrop_viewport.get_texture())
    gel_material.set_shader_parameter("backdrop_strength", 0.82)
    gel_material.set_shader_parameter("refraction_pixels", 5.0)

func _sync_backdrop_camera() -> void:
    if backdrop_camera == null or camera == null:
        return
    var main_size: Vector2 = get_viewport().get_visible_rect().size
    var target_size := Vector2i(
        maxi(240, int(round(main_size.x * 0.5))),
        maxi(320, int(round(main_size.y * 0.5))))
    if backdrop_viewport.size != target_size:
        backdrop_viewport.size = target_size
    backdrop_frame_size = target_size
    backdrop_camera.projection = camera.projection
    backdrop_camera.keep_aspect = camera.keep_aspect
    backdrop_camera.size = camera.size
    backdrop_camera.near = camera.near
    backdrop_camera.far = camera.far
    backdrop_camera.global_transform = camera.global_transform

func set_diagnostic_background(enabled: bool) -> void:
    diagnostic_background_enabled = enabled
    if test_card != null:
        test_card.visible = enabled

func set_transmission_enabled(enabled: bool) -> void:
    transmission_enabled = enabled
    gel_material.set_shader_parameter(
        "backdrop_strength", 0.82 if enabled else 0.0)

func _process(delta: float) -> void:
    super._process(delta)
    # Only a transform sync: the backdrop camera follows touch orbit and
    # phone resolution without copying pixel buffers to the CPU.
    _sync_backdrop_camera()
