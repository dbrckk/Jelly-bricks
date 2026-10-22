extends "res://prototypes/single_brick/scene.gd"
## Three actual independent GPU bricks. Top contact transmits a damped wave
## through supporting layers after controlled delays; this is NOT rigid-body
## physics or a claim of fidelity to the film's full collapse.
const STEP := 0.55
const CONTACT_AT := 0.68
const WAVE_DELAY := 0.085
var layers: Array[Node3D] = []
var paints: Array[ShaderMaterial] = []
var stud_paints: Array[StandardMaterial3D] = []
var layer_energy := PackedFloat32Array([0.0, 0.0, 0.0])
var layer_sway := PackedFloat32Array([0.0, 0.0, 0.0])
# The front lip and each support are coupled by delayed, damped waves.
# Still a deterministic visual approximation: no fake rigid-body claim.

func _ready() -> void:
    super._ready()
    time_enabled = false
    layers.append(brick_root)
    paints.append(gel_material)
    stud_paints.append(studs.material_override)
    for i in range(1, 3):
        var layer: Node3D = brick_root.duplicate()
        layer.name = "GelLayer_%d" % i
        add_child(layer)
        layers.append(layer)
        var shell_part: MeshInstance3D = layer.get_node("CurvedShellWithSocket")
        if i == 1:
            # The reference alternates long / short brick silhouettes.
            # A one-cell support carries the next two-cell bridge.
            shell_part.mesh = _corrected_studio_mesh(1)
            var highlight: MeshInstance3D = layer.get_node("ThinOpticalClearcoat")
            highlight.mesh = shell_part.mesh
        var coat: MeshInstance3D = layer.get_node("ThinOpticalClearcoat")
        var coat_paint: ShaderMaterial = wet_coat.material_override.duplicate() as ShaderMaterial
        coat_paint.set_shader_parameter("brick_extent",
            Vector2(1.0, 1.0) if i == 1 else Vector2(2.0, 1.0))
        coat.material_override = coat_paint
        var paint: ShaderMaterial = gel_material.duplicate() as ShaderMaterial
        paint.set_shader_parameter("brick_extent",
            Vector2(1.0, 1.0) if i == 1 else Vector2(2.0, 1.0))
        paint.set_shader_parameter("pigment",
            Color("#234bdc") if i == 1 else Color("#1cad40"))
        shell_part.material_override = paint
        paints.append(paint)
        var caps: MultiMeshInstance3D = layer.get_node("ActualFourMoldedStuds")
        if i == 1:
            var short_studs := caps.multimesh.duplicate() as MultiMesh
            short_studs.instance_count = 2
            for lane in range(2):
                short_studs.set_instance_transform(lane,
                    Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.68, 1.0)),
                        Vector3(0.5, 0.18944, 0.265 if lane == 0 else 0.735)))
            caps.multimesh = short_studs
        var caps_mat: StandardMaterial3D = studs.material_override.duplicate() as StandardMaterial3D
        caps_mat.albedo_color = Color("#3360ea") if i == 1 else Color("#24c251")
        caps.material_override = caps_mat
        stud_paints.append(caps_mat)
    # The base is the fixed support and the upper brick travels down.
    _update_camera()
    sample_stack("rest")

func _update_camera() -> void:
    if camera == null:
        return
    var center := Vector3(1.0, 0.98, 0.5)
    camera.size = 6.4
    camera.position = center + Vector3(
        sin(0.67 + orbit) * 6.6, 4.2,
        cos(0.67 + orbit) * 6.6)
    camera.look_at(center)

static func _pulse(after_contact: float, level: int) -> float:
    var delay := CONTACT_AT + float(2-level) * WAVE_DELAY
    if after_contact < delay:
        return 0.0
    var age: float = after_contact - delay
    return exp(-age * 8.2) * maxf(0.0, sin(age * 21.0))

func set_stack_time(t: float) -> void:
    elapsed = maxf(t, 0.0)
    for i in range(3):
        var impulse: float = _pulse(elapsed, i)
        layer_energy[i] = impulse
        var squash_amount: float = impulse * (0.43 if i == 2 else (0.30 if i == 1 else 0.18))
        var dt_wave: float = elapsed - CONTACT_AT - float(2-i) * WAVE_DELAY
        var sway: float = 0.0
        if dt_wave >= 0.0:
            sway = sin(dt_wave * 19.0) * exp(-dt_wave * 4.8)
        layer_sway[i] = sway
        var lift: float = 0.0
        if i == 2 and elapsed < CONTACT_AT:
            # Top descends from a clearance, then lands on the second layer.
            lift = 0.72 * (1.0 - smoothstep(0.10, CONTACT_AT, elapsed))
        elif elapsed >= CONTACT_AT:
            var dt: float = maxf(elapsed - CONTACT_AT, 0.0)
            lift = maxf(0.0, sin(dt * 14.0)) * exp(-dt * 9.0) * (0.07 if i == 2 else 0.015)
        var root_layer: Node3D = layers[i]
        var sway_amplitude: float = 0.048 if i == 2 else (0.027 if i == 1 else 0.010)
        root_layer.position = Vector3((0.5 if i == 1 else 0.0) +
            sway * sway_amplitude, i * STEP + lift, 0.0)
        root_layer.rotation_degrees.z = sway * (3.8 if i == 2 else (2.3 if i == 1 else 0.9))
        paints[i].set_shader_parameter("deformation", squash_amount)
        paints[i].set_shader_parameter("tilt_energy", sway * 0.48)
        var ripple_strength: float = impulse * (0.85 if i == 2 else 0.56)
        var phase: float = fposmod(maxf(dt_wave, 0.0) * 18.0, TAU)
        paints[i].set_shader_parameter("ripple_energy", ripple_strength)
        paints[i].set_shader_parameter("ripple_phase", phase)
        var coat_mesh: MeshInstance3D = root_layer.get_node("ThinOpticalClearcoat")
        var coat_paint: ShaderMaterial = coat_mesh.material_override as ShaderMaterial
        coat_paint.set_shader_parameter("deformation", squash_amount)
        coat_paint.set_shader_parameter("tilt_energy", sway * 0.48)
        coat_paint.set_shader_parameter("ripple_energy", ripple_strength)
        coat_paint.set_shader_parameter("ripple_phase", phase)
        var layer_studs: MultiMeshInstance3D = root_layer.get_node("ActualFourMoldedStuds")
        layer_studs.scale.y = 1.0 - squash_amount * 0.19
        # The shell, studs and highlight respond to the same impulse.
    phase_name = "contact" if elapsed >= CONTACT_AT and elapsed < 1.15 else "stack"

func sample_stack(state: String) -> void:
    manual_pose = true
    match state:
        "rest": set_stack_time(3.0)
        "approach": set_stack_time(0.48)
        "contact": set_stack_time(0.76)
        "wave": set_stack_time(0.94)
        "settled": set_stack_time(3.0)
        _: push_error("Unknown stack state: " + state)

func _process(delta: float) -> void:
    if time_enabled and not manual_pose:
        set_stack_time(fposmod(elapsed + minf(delta, .05), 3.4))
