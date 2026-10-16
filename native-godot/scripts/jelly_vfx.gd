extends Node3D
## Procedural 3D candy glints for Godot 4.6 Compatibility (OpenGL ES).
## Four pooled, low-count CPU emitters; no textures, GPU compute,
## dependencies, network requests or per-touch particle allocations.
const LANDING_POOL := 3
const LANDING_COUNT := 12
const VICTORY_COUNT := 38
const LANDING_DURATION := 0.44
const VICTORY_DURATION := 1.10

var landing_emitters: Array[CPUParticles3D] = []
var victory_emitter: CPUParticles3D
var landing_cursor: int = 0
var glint_mesh: SphereMesh

func _ready() -> void:
    glint_mesh = SphereMesh.new()
    glint_mesh.radius = .041
    glint_mesh.height = .082
    glint_mesh.radial_segments = 6
    glint_mesh.rings = 2
    var glint_material := StandardMaterial3D.new()
    glint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    glint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glint_material.vertex_color_use_as_albedo = true
    glint_material.albedo_color = Color.WHITE
    glint_mesh.material = glint_material
    for index in range(LANDING_POOL):
        var emitter := _make_emitter("LandingGlints%d" % index,
            LANDING_COUNT, LANDING_DURATION)
        emitter.gravity = Vector3(0.0, -3.0, 0.0)
        emitter.direction = Vector3.UP
        emitter.spread = 79.0
        emitter.initial_velocity_min = .76
        emitter.initial_velocity_max = 1.42
        landing_emitters.append(emitter)
    victory_emitter = _make_emitter("VictoryGlints", VICTORY_COUNT,
        VICTORY_DURATION)
    victory_emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    victory_emitter.emission_box_extents = Vector3(1.5, .04, 1.5)
    victory_emitter.direction = Vector3.UP
    victory_emitter.spread = 59.0
    victory_emitter.initial_velocity_min = 1.8
    victory_emitter.initial_velocity_max = 3.25
    victory_emitter.gravity = Vector3(0.0, -3.9, 0.0)

func _make_emitter(node_name: String, count: int,
        duration: float) -> CPUParticles3D:
    var emitter := CPUParticles3D.new()
    emitter.name = node_name
    emitter.amount = count
    emitter.lifetime = duration
    emitter.one_shot = true
    emitter.emitting = false
    emitter.explosiveness = 1.0
    emitter.fixed_fps = 30
    emitter.local_coords = true
    emitter.mesh = glint_mesh
    emitter.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
    emitter.scale_amount_min = .55
    emitter.scale_amount_max = 1.15
    var fade := Gradient.new()
    fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
    fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
    emitter.color_ramp = fade
    add_child(emitter)
    return emitter

## Only invoke after a committed placement. The incoming piece tint stays
## recognisable; valid placements use mint/white glints, wrong ones amber.
func landing(world_position: Vector3, tint: Color, correct: bool) -> void:
    if landing_emitters.is_empty():
        return
    var emitter: CPUParticles3D = landing_emitters[
        landing_cursor % landing_emitters.size()]
    landing_cursor += 1
    emitter.position = world_position + Vector3(0.35, 0.30, 0.35)
    emitter.color = tint.lerp(Color("#d4fff2"), .45) if correct \
        else tint.lerp(Color("#ffbd69"), .70)
    emitter.restart()

func victory() -> void:
    if victory_emitter == null:
        return
    victory_emitter.position = Vector3(0.0, .15, 0.0)
    victory_emitter.color = Color("#d9fff5")
    victory_emitter.restart()

func reset() -> void:
    for emitter in landing_emitters:
        emitter.emitting = false
    if victory_emitter != null:
        victory_emitter.emitting = false
    landing_cursor = 0
