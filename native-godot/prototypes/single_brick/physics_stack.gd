extends "res://prototypes/single_brick/three_stack.gd"
## Isolated Godot rigid-body experiment: actual collision response, gravity,
## friction and angular motion. Visual spring impulses follow contact events,
## but the shell is still shader-deformed (not a soft-body volume).
##
## Do not attach this scene to the shipped game until reviewed on Android.
const START_LIFT := 0.72
const IMPACT_DECAY := 7.5
const IMPACT_THRESHOLD := 0.025
var bodies: Array[RigidBody3D] = []
var impact_energy := PackedFloat32Array([0.0, 0.0, 0.0])
var impact_peak: float = 0.0
var contact_count: int = 0
var interbrick_contacts: int = 0
var peak_tilt_degrees: float = 0.0
var peak_lateral_shift: float = 0.0
var first_contact_at: float = -1.0
var simulation_seconds: float = 0.0
var is_simulating: bool = false
var floor_body: StaticBody3D

func _ready() -> void:
    super._ready()
    # Rendering remains a standard three-brick scene while physics is
    # initially frozen. Touch calls the overridden replay_stack().
    time_enabled = false
    manual_pose = true
    _build_floor()
    for i in range(3):
        var body := RigidBody3D.new()
        body.name = "CollidingGel_%d" % i
        body.mass = 1.25 if i == 0 else (0.75 if i == 1 else 1.10)
        body.gravity_scale = 1.0
        body.linear_damp = 0.85
        body.angular_damp = 1.8
        body.continuous_cd = true
        body.contact_monitor = true
        body.max_contacts_reported = 12
        body.freeze = true
        body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
        var surface := PhysicsMaterial.new()
        surface.friction = 0.88
        surface.bounce = 0.11
        body.physics_material_override = surface
        add_child(body)

        # The curved shell includes an underside socket, so a compact
        # convex box is used only for collision response. It does not
        # pretend to resolve the stud/socket lip perfectly.
        var shape_node := CollisionShape3D.new()
        shape_node.name = "CollisionCore"
        var box := BoxShape3D.new()
        box.size = Vector3(0.90 if i == 1 else 1.90, 0.48, 0.90)
        shape_node.shape = box
        shape_node.position = Vector3(0.5 if i == 1 else 1.0, 0.31, 0.5)
        body.add_child(shape_node)

        var visual: Node3D = layers[i]
        # Preserve local geometry, not the former scripted stack pose.
        visual.position = Vector3.ZERO
        visual.rotation = Vector3.ZERO
        visual.reparent(body, false)
        body.body_entered.connect(_on_contact.bind(i))
        bodies.append(body)

    reset_stack()

func _build_floor() -> void:
    floor_body = StaticBody3D.new()
    floor_body.name = "ActualPhysicalFloor"
    var floor_collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(18.0, 0.20, 18.0)
    floor_collider.shape = shape
    floor_collider.position = Vector3(1.0, -0.10, 0.5)
    floor_body.add_child(floor_collider)
    var surface := PhysicsMaterial.new()
    surface.friction = 0.96
    surface.bounce = 0.06
    floor_body.physics_material_override = surface
    add_child(floor_body)

func _pose_for_layer(i: int) -> Vector3:
    if i == 0:
        return Vector3.ZERO
    if i == 1:
        return Vector3(0.50, STEP, 0.0)
    return Vector3(0.24, 2.0 * STEP + START_LIFT, 0.0)

func reset_stack() -> void:
    is_simulating = false
    simulation_seconds = 0.0
    contact_count = 0
    interbrick_contacts = 0
    peak_tilt_degrees = 0.0
    peak_lateral_shift = 0.0
    first_contact_at = -1.0
    impact_peak = 0.0
    for i in range(bodies.size()):
        var body: RigidBody3D = bodies[i]
        body.freeze = true
        body.linear_velocity = Vector3.ZERO
        body.angular_velocity = Vector3.ZERO
        body.transform = Transform3D(Basis.IDENTITY, _pose_for_layer(i))
        body.sleeping = true
        impact_energy[i] = 0.0
        _apply_visual_spring(i, 0.0)

func replay_stack() -> void:
    reset_stack()
    manual_pose = false
    is_simulating = true
    # A static base gives a stable reference; the short middle support
    # and offset long top use real 3D bodies, gravity and friction.
    for i in range(1, bodies.size()):
        bodies[i].freeze = false
        bodies[i].sleeping = false
    # A small off-axis kick makes the unequal supports capable of toppling;
    # the resulting motion is solved by Godot's physics engine.
    # Two real momentum impulses: moderate sideways velocity plus torque,
    # applied before first contact. The short support cannot magically lock
    # a long off-centre bar, so the engine can produce a visible collapse.
    bodies[2].apply_central_impulse(Vector3(1.20, 0.0, 0.05))
    bodies[2].apply_torque_impulse(Vector3(0.0, 0.0, -0.50))

func _on_contact(other: Node, i: int) -> void:
    if not is_simulating or i == 0:
        return
    var body: RigidBody3D = bodies[i]
    var speed := body.linear_velocity.length()
    var strength := clampf(0.34 + speed * 0.11, 0.34, 0.92)
    impact_energy[i] = maxf(impact_energy[i], strength)
    impact_peak = maxf(impact_peak, strength)
    contact_count += 1
    if first_contact_at < 0.0:
        first_contact_at = simulation_seconds
    # Actual contact pair propagates a smaller compression to its support.
    var neighbor := bodies.find(other)
    if neighbor >= 0:
        interbrick_contacts += 1
        impact_energy[neighbor] = maxf(impact_energy[neighbor],
            strength * 0.48)

func _apply_visual_spring(i: int, energy: float) -> void:
    var compressed: float = energy * (0.27 if i == 2 else 0.18)
    var phase: float = simulation_seconds * 22.0
    var angular: float = 0.0
    if i < bodies.size():
        angular = clampf(bodies[i].angular_velocity.z * 0.08, -0.24, 0.24)
    paints[i].set_shader_parameter("deformation", compressed)
    paints[i].set_shader_parameter("tilt_energy", angular)
    paints[i].set_shader_parameter("ripple_energy", energy * 0.55)
    paints[i].set_shader_parameter("ripple_phase", fposmod(phase, TAU))
    var coat := layers[i].get_node("ThinOpticalClearcoat") as MeshInstance3D
    var coat_mat := coat.material_override as ShaderMaterial
    coat_mat.set_shader_parameter("deformation", compressed)
    coat_mat.set_shader_parameter("tilt_energy", angular)
    coat_mat.set_shader_parameter("ripple_energy", energy * 0.55)
    coat_mat.set_shader_parameter("ripple_phase", fposmod(phase, TAU))
    var caps := layers[i].get_node("ActualFourMoldedStuds") as MultiMeshInstance3D
    caps.scale.y = 1.0 - compressed * 0.19

func _physics_process(delta: float) -> void:
    if not is_simulating:
        return
    simulation_seconds += maxf(delta, 0.0)
    peak_tilt_degrees = maxf(peak_tilt_degrees,
        absf(rad_to_deg(bodies[2].rotation.z)))
    peak_lateral_shift = maxf(peak_lateral_shift,
        absf(bodies[2].position.x - _pose_for_layer(2).x))
    for i in range(3):
        impact_energy[i] *= exp(-IMPACT_DECAY * delta)
        if impact_energy[i] < IMPACT_THRESHOLD:
            impact_energy[i] = 0.0
        _apply_visual_spring(i, impact_energy[i])
    # The simulation stays awake for collision review, until a new tap.
    # Do not teleport objects to rest or falsify a deterministic collapse.

func _process(_delta: float) -> void:
    # Disable the parent's scripted trajectory; physics owns all poses.
    pass
