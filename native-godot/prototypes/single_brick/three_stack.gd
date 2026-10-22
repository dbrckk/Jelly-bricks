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
        var paint: ShaderMaterial = gel_material.duplicate() as ShaderMaterial
        paint.set_shader_parameter("pigment",
            Color("#275bf8") if i == 1 else Color("#30d969"))
        shell_part.material_override = paint
        paints.append(paint)
        var caps: MultiMeshInstance3D = layer.get_node("ActualFourMoldedStuds")
        var caps_mat: StandardMaterial3D = studs.material_override.duplicate() as StandardMaterial3D
        caps_mat.albedo_color = Color("#4270fa") if i == 1 else Color("#44e987")
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
        var squash_amount: float = impulse * (0.27 if i == 2 else (0.15 if i == 1 else 0.07))
        var lift: float = 0.0
        if i == 2 and elapsed < CONTACT_AT:
            # Top descends from a clearance, then lands on the second layer.
            lift = 0.72 * (1.0 - smoothstep(0.10, CONTACT_AT, elapsed))
        elif elapsed >= CONTACT_AT:
            var dt: float = maxf(elapsed - CONTACT_AT, 0.0)
            lift = maxf(0.0, sin(dt * 14.0)) * exp(-dt * 9.0) * (0.07 if i == 2 else 0.015)
        var root_layer: Node3D = layers[i]
        root_layer.position = Vector3(0.0, i * STEP + lift, 0.0)
        root_layer.rotation_degrees.z = (sin((elapsed - CONTACT_AT) * 13.0) *
            impulse * (1.8 if i == 2 else 0.8))
        paints[i].set_shader_parameter("deformation", squash_amount)
        paints[i].set_shader_parameter("tilt_energy", impulse * 0.09)
        # Both the shell and its highlights follow the same root transform.
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
