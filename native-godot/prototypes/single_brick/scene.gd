extends Node3D
## Isolated REAL Godot 4.6 / Compatibility study, never instantiated by
## the shipped puzzle. Uses the production curved 3D studio body/stud meshes.
## Animation is deterministic, inspectable, and can be driven by touch.
const GEL = preload("res://scripts/gel_mesh.gd")
const WET = preload("res://prototypes/single_brick/wet_gel.gdshader")
const CONTACT = preload("res://prototypes/single_brick/contact.gdshader")
const COAT = preload("res://prototypes/single_brick/wet_coat.gdshader")
const DYE := Color("#e82936")
const FRAME_DURATION := 3.4

var brick_root: Node3D
var shell: MeshInstance3D
var studs: MultiMeshInstance3D
var wet_coat: MeshInstance3D
var gel_material: ShaderMaterial
var contact_material: ShaderMaterial
var camera: Camera3D
var orbit: float = 0.0
var elapsed: float = 0.0
var manual_pose: bool = false
var phase_name: String = "rest"
var squash: float = 0.0
var height_offset: float = 0.0
var yaw: float = 0.0
var time_enabled: bool = true

func _ready() -> void:
    name = "OneMoldedGelBrick"
    _make_environment()
    _make_brick()
    _make_camera()
    _apply_state("rest", 0.0, 0.0, 0.0)

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#f2f6f5")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#e8f1fa")
    env.ambient_light_energy = 0.88
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)

    var key := DirectionalLight3D.new()
    key.name = "ProductSoftboxKey"
    key.light_color = Color("#fff8ef")
    key.light_energy = 1.2
    key.position = Vector3(-4.0, 8.0, 6.0)
    add_child(key)
    key.look_at(Vector3(1.0, 0.2, 0.5))
    key.shadow_enabled = true

    var fill := DirectionalLight3D.new()
    fill.name = "CoolFill"
    fill.light_color = Color("#d1e5ff")
    fill.light_energy = 0.48
    fill.position = Vector3(5.0, 5.0, -5.0)
    add_child(fill)
    fill.look_at(Vector3(1.0, 0.35, 0.5))
    fill.shadow_enabled = false

    var cyclorama := MeshInstance3D.new()
    cyclorama.name = "RealStudioFloor"
    var floor := PlaneMesh.new()
    floor.size = Vector2(40, 40)
    cyclorama.mesh = floor
    var floor_paint := StandardMaterial3D.new()
    floor_paint.albedo_color = Color("#f2f6f5")
    floor_paint.roughness = 0.91
    cyclorama.material_override = floor_paint
    cyclorama.position.y = 0.011
    cyclorama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(cyclorama)

    var optical_contact := MeshInstance3D.new()
    optical_contact.name = "TransmittedPigmentContact"
    var projected := PlaneMesh.new()
    projected.size = Vector2(2.9, 1.9)
    optical_contact.mesh = projected
    contact_material = ShaderMaterial.new()
    contact_material.shader = CONTACT
    contact_material.set_shader_parameter("intensity", 0.60)
    optical_contact.material_override = contact_material
    optical_contact.position = Vector3(1.0, 0.017, 0.5)
    optical_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(optical_contact)

## The production studio shell has its cap triangle winding reversed
## relative to the Godot Compatibility front face: with back-face culling
## enabled the recessed inner socket roof appears ABOVE the real crown.
## Fix orientation in this isolated prototype; do not change game mesh yet.
func _corrected_shell() -> ArrayMesh:
    var original: ArrayMesh = GEL.build_studio(2, 0)
    var arrays: Array = original.surface_get_arrays(0)
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for t in range(0, indices.size(), 3):
        var temp: int = indices[t + 1]
        indices[t + 1] = indices[t + 2]
        indices[t + 2] = temp
    arrays[Mesh.ARRAY_INDEX] = indices
    var repaired := ArrayMesh.new()
    repaired.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return repaired

func _make_brick() -> void:
    brick_root = Node3D.new()
    brick_root.name = "ActualGelVolume"
    add_child(brick_root)

    gel_material = ShaderMaterial.new()
    gel_material.shader = WET
    gel_material.set_shader_parameter("pigment", DYE)
    gel_material.set_shader_parameter("brick_extent", Vector2(2.0, 1.0))
    gel_material.set_shader_parameter("gel_alpha", 0.94)

    shell = MeshInstance3D.new()
    shell.name = "CurvedShellWithSocket"
    shell.mesh = _corrected_shell()
    shell.material_override = gel_material
    shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    brick_root.add_child(shell)

    # A bounded photographic wet layer over an opaque, correctly wound
    # molded core. No transparency through the recessed socket roof.
    wet_coat = MeshInstance3D.new()
    wet_coat.name = "ThinOpticalClearcoat"
    wet_coat.mesh = shell.mesh
    wet_coat.material_override = ShaderMaterial.new()
    wet_coat.material_override.shader = COAT
    wet_coat.position = Vector3(-0.006, -0.008, -0.004)
    wet_coat.scale = Vector3(1.006, 1.012, 1.008)
    wet_coat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    brick_root.add_child(wet_coat)

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = GEL.build_studio_stud()
    multi.instance_count = 4
    for i in range(2):
        for lane in range(2):
            multi.set_instance_transform(i * 2 + lane,
                Transform3D(Basis.IDENTITY, Vector3(
                    float(i) + 0.5, 0.0, 0.265 if lane == 0 else 0.735)))
    studs = MultiMeshInstance3D.new()
    studs.name = "ActualFourMoldedStuds"
    studs.multimesh = multi
    # The reference footage shows colored short studs, not four dark holes.
    # Use a solid glossy molded cap while the core material is being tuned.
    var stud_paint := StandardMaterial3D.new()
    stud_paint.albedo_color = Color("#f7264c")
    stud_paint.roughness = 0.18
    stud_paint.metallic = 0.0
    stud_paint.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
    studs.material_override = stud_paint
    studs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    brick_root.add_child(studs)

func _make_camera() -> void:
    camera = Camera3D.new()
    camera.name = "ComparisonCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 4.7
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    camera.current = true
    add_child(camera)
    _update_camera()

func _update_camera() -> void:
    var centre := Vector3(1.0, 0.43, 0.5)
    camera.position = centre + Vector3(
        sin(0.60 + orbit) * 5.5, 3.6,
        cos(0.60 + orbit) * 5.5)
    camera.look_at(centre)

func _apply_state(state: String, raise: float, bend: float,
        amount: float) -> void:
    phase_name = state
    squash = amount
    height_offset = raise
    yaw = bend
    brick_root.position.y = raise
    brick_root.rotation_degrees.z = bend * 3.8
    gel_material.set_shader_parameter("deformation", amount)
    gel_material.set_shader_parameter("tilt_energy", bend)
    contact_material.set_shader_parameter("intensity",
        clampf(.65 - raise * .42 + amount * .18, .12, .90))

## Input values are physical samples of a single, explicit spring model.
## The first flight ends at 0.50s, impact is maximal at 0.57s.
## Exponential recovery is frame-rate independent.
func set_elapsed(t: float) -> void:
    elapsed = maxf(0.0, t)
    if elapsed < 0.22:
        _apply_state("rest", 0.0, 0.0, 0.0)
    elif elapsed < 0.41:
        var u := (elapsed - 0.22) / 0.19
        var rise := u * u * (3.0 - 2.0 * u)
        _apply_state("lift", rise * 0.60, u * 0.055, 0.0)
    elif elapsed < 0.68:
        var u := (elapsed - 0.41) / 0.27
        _apply_state("flight", (1.0 - u * u) * 0.60,
            (1.0 - u) * 0.055, 0.0)
    else:
        var u := elapsed - 0.68
        var spring := exp(-u * 5.8)
        var contact := maxf(0.0, sin(u * 17.0))
        var compressed := contact * spring * 0.94
        var bounce := absf(sin(u * 11.2)) * spring * 0.16
        _apply_state("impact" if u < 0.20 else "settling",
            bounce, sin(u * 13.8) * spring * 0.17, compressed)
    if elapsed > 2.5:
        _apply_state("rest", 0.0, 0.0, 0.0)

## Deterministic frames for real GL render QA; never a canned image.
func sample(label: String) -> void:
    manual_pose = true
    match label:
        "rest": _apply_state("rest", 0.0, 0.0, 0.0)
        "flight": set_elapsed(0.53)
        "impact": set_elapsed(0.77)
        "rebound": set_elapsed(0.99)
        "settled": set_elapsed(2.80)
        _: push_error("Unknown prototype phase: " + label)

func _process(delta: float) -> void:
    if time_enabled and not manual_pose:
        set_elapsed(fposmod(elapsed + minf(maxf(delta, 0.0), .05),
            FRAME_DURATION))

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenDrag:
        orbit += event.relative.x * 0.003
        _update_camera()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(
            MOUSE_BUTTON_LEFT):
        orbit += event.relative.x * 0.004
        _update_camera()
    elif event is InputEventScreenTouch and event.pressed:
        manual_pose = false
        set_elapsed(0.22)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            manual_pose = false
            set_elapsed(0.22)
