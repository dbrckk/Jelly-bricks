extends "res://prototypes/single_brick/scene.gd"
## Production-safe SINGLE RED 2x1 reference. Unlike the mobile game or
## physics lab, this scene tests the maximum studio tessellation and gel
## optical controls. The unmodified studio generator remains the baseline.
const FINE = preload("res://prototypes/single_brick/subdivided_studio_mesh.gd")
const STUD_WET = preload("res://prototypes/single_brick/wet_stud.gdshader")
const OPAQUE_GEL = preload("res://prototypes/single_brick/wet_gel_opaque_reference.gdshader")
var base_triangles: int = 0
var fine_triangles: int = 0

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
    # True volumetric refraction remains Blender's offline reference:
    # this opaque Godot control must not pretend to be transparent.
    gel_material.set_shader_parameter("highlights", 0.63)
    var cap_mat := ShaderMaterial.new()
    cap_mat.shader = STUD_WET
    cap_mat.set_shader_parameter("pigment", dye)
    studs.material_override = cap_mat
    var coat := wet_coat.material_override as ShaderMaterial
    coat.set_shader_parameter("coat_strength", 0.21)
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
