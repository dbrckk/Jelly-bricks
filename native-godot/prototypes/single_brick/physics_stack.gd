extends "res://prototypes/single_brick/three_stack.gd"
## Isolated Godot rigid-body experiment: actual collision response, gravity,
## friction and angular motion. Visual spring impulses follow contact events,
## but the shell is still shader-deformed (not a soft-body volume).
##
## Do not attach this scene to the shipped game until reviewed on Android.
const START_LIFT := 0.72
const IMPACT_DECAY := 7.5
const IMPACT_THRESHOLD := 0.025
# Underdamped Kelvin-Voigt-like VISUAL rebound, driven by real contacts.
# Godot still solves the rigid bodies; no misleading soft-body claim.
const GEL_OMEGA := 16.0
const GEL_DAMPING := 0.29
const STUD_WET = preload("res://prototypes/single_brick/wet_stud.gdshader")
const SOFT_SHADOW = preload("res://prototypes/single_brick/soft_shadow.gdshader")
const CONTACT_RIGID = preload("res://prototypes/single_brick/contact_rigid_body.gd")
# The lab can compare genuine physics impacts without changing the base
# scene's verified reference preset (1.0). Keep the multiplier bounded.
var impact_multiplier: float = 1.0
# User-adjustable amount of optical / silhouette jelly distortion.
# Purely visual; real collisions remain stable on the original compound shapes.
var gel_softness: float = 0.92
var peak_silhouette_bulge: float = 0.0
var peak_follow_through: float = 0.0
var paused_by_user: bool = false
var bodies: Array[RigidBody3D] = []
var ground_shadows: Array[MeshInstance3D] = []
var shadow_paints: Array[ShaderMaterial] = []
var peak_shadow_travel: float = 0.0
var impact_energy := PackedFloat32Array([0.0, 0.0, 0.0])
var impact_local_energy := PackedFloat32Array([0.0, 0.0, 0.0])
var impact_local_age := PackedFloat32Array([3.0, 3.0, 3.0])
var observed_local_samples := PackedInt32Array([0, 0, 0])
var impact_local_points: Array[Vector3] = [
    Vector3(1.0, 0.1, 0.5), Vector3(0.5, 0.1, 0.5),
    Vector3(1.0, 0.1, 0.5)]
var peak_local_impact: float = 0.0
var total_local_hits: int = 0
var spring_displacement := PackedFloat32Array([0.0, 0.0, 0.0])
var spring_velocity := PackedFloat32Array([0.0, 0.0, 0.0])
var peak_spring_compression: float = 0.0
var peak_spring_rebound: float = 0.0
var impact_peak: float = 0.0
var contact_count: int = 0
var interbrick_contacts: int = 0
var peak_tilt_degrees: float = 0.0
var peak_lateral_shift: float = 0.0
var peak_drop: float = 0.0
var peak_stud_shift: float = 0.0
var peak_edge_flex: float = 0.0
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
        var body := CONTACT_RIGID.new()
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

        # Compound convex primitives leave an ACTUAL open socket below the
        # upper roof and four/two physical cylindrical studs above it. Each
        # CollisionShape3D must be a DIRECT child of the RigidBody3D.
        # This matches the production studio profile without requiring a
        # concave dynamic trimesh (unstable/unsupported for rigid bodies).
        _build_molded_colliders(body, 1 if i == 1 else 2)

        var visual: Node3D = layers[i]
        # Preserve local geometry, not the former scripted stack pose.
        visual.position = Vector3.ZERO
        visual.rotation = Vector3.ZERO
        visual.reparent(body, false)
        # Node.duplicate() can retain a shared MultiMesh resource. Each
        # independently jiggling layer MUST own its per-instance transforms.
        var instance_mesh := visual.get_node(
            "ActualFourMoldedStuds") as MultiMeshInstance3D
        instance_mesh.multimesh = instance_mesh.multimesh.duplicate() as MultiMesh
        # The molded cap's old StandardMaterial made studs look like rigid
        # candy buttons. Physical lab ONLY: one compact wet-gel shader per
        # layer, pigmented together with its actual gel body.
        var stud_optics := ShaderMaterial.new()
        stud_optics.shader = STUD_WET
        var physical_dye: Color = [
            Color("#d83a55"), Color("#376fc9"), Color("#19ad70")][i]
        stud_optics.set_shader_parameter("pigment", physical_dye)
        instance_mesh.material_override = stud_optics
        paints[i].set_shader_parameter("pigment", physical_dye)
        paints[i].set_shader_parameter("gel_milkiness", 0.46)
        # Dense paint on the deterministic demo stays untouched; only the
        # physical scene uses analytical, path-length-colored gel.
        paints[i].set_shader_parameter("bulk_optics", 0.88)
        var clearcoat := visual.get_node("ThinOpticalClearcoat") as MeshInstance3D
        var coat_material := clearcoat.material_override as ShaderMaterial
        coat_material.set_shader_parameter("coat_strength", 0.34)
        body.body_entered.connect(_on_contact.bind(i))
        bodies.append(body)
        _build_ground_shadow(i)

    reset_stack()

## Studio mesh profile: underside ceiling y=.265, outer shell top y=.56,
## physical molded studs y≈.592..732 after the production 0.68 scale.
## Four thin rim strips support the shell while keeping the pocket hollow.
const ROOF_Y := 0.410
const ROOF_HEIGHT := 0.30
const RIM_Y := 0.163
const RIM_HEIGHT := 0.216
const RIM_THICKNESS := 0.095
const STUD_CENTER_Y := 0.663
const STUD_HEIGHT := 0.142
const STUD_RADIUS := 0.112

func _box_collider(parent: RigidBody3D, label: String,
        size: Vector3, center: Vector3) -> void:
    var node := CollisionShape3D.new()
    node.name = label
    var shape := BoxShape3D.new()
    shape.size = size
    node.shape = shape
    node.position = center
    parent.add_child(node)

func _build_molded_colliders(parent: RigidBody3D, length: int) -> void:
    var width := float(length)
    # Top is solid; below its 0.265 underside, the center is hollow.
    _box_collider(parent, "CollisionRoof",
        Vector3(width - 0.012, ROOF_HEIGHT, 0.988),
        Vector3(width * 0.5, ROOF_Y, 0.5))
    var wall_y := RIM_Y
    _box_collider(parent, "RimWest",
        Vector3(RIM_THICKNESS, RIM_HEIGHT, 0.94),
        Vector3(RIM_THICKNESS * 0.5, wall_y, 0.5))
    _box_collider(parent, "RimEast",
        Vector3(RIM_THICKNESS, RIM_HEIGHT, 0.94),
        Vector3(width - RIM_THICKNESS * 0.5, wall_y, 0.5))
    _box_collider(parent, "RimFront",
        Vector3(width - 2.0 * RIM_THICKNESS, RIM_HEIGHT, RIM_THICKNESS),
        Vector3(width * 0.5, wall_y, RIM_THICKNESS * 0.5))
    _box_collider(parent, "RimBack",
        Vector3(width - 2.0 * RIM_THICKNESS, RIM_HEIGHT, RIM_THICKNESS),
        Vector3(width * 0.5, wall_y, 1.0 - RIM_THICKNESS * 0.5))
    # Four visible short studs on the long brick, two on the short one.
    for cell in range(length):
        for lane in range(2):
            var peg := CollisionShape3D.new()
            peg.name = "PhysicalStud_%d_%d" % [cell, lane]
            var cylinder := CylinderShape3D.new()
            cylinder.radius = STUD_RADIUS
            cylinder.height = STUD_HEIGHT
            peg.shape = cylinder
            peg.position = Vector3(float(cell) + 0.5,
                STUD_CENTER_Y, 0.265 if lane == 0 else 0.735)
            parent.add_child(peg)

## Spatial shadows grounded on the studio floor, not glued to a rotating
## brick. A single soft quad follows each physically measured world pose.
func _build_ground_shadow(i: int) -> void:
    var shadow := MeshInstance3D.new()
    shadow.name = "MovingGroundShadow_%d" % i
    var plane := PlaneMesh.new()
    plane.size = Vector2.ONE
    shadow.mesh = plane
    var material := ShaderMaterial.new()
    material.shader = SOFT_SHADOW
    shadow.material_override = material
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shadow)
    ground_shadows.append(shadow)
    shadow_paints.append(material)

func _update_ground_shadow(i: int) -> void:
    var body: RigidBody3D = bodies[i]
    var len: float = 1.0 if i == 1 else 2.0
    var center := body.to_global(Vector3(len * 0.5, 0.30, 0.5))
    var altitude := maxf(0.0, center.y - 0.30)
    var shadow: MeshInstance3D = ground_shadows[i]
    shadow.position = Vector3(center.x, 0.022 + float(i) * 0.001, center.z)
    var growth := 1.0 + altitude * 0.11
    shadow.scale = Vector3((len + 0.68) * growth, 1.0,
        1.54 * growth)
    shadow_paints[i].set_shader_parameter("shadow_opacity",
        clampf(0.39 - altitude * 0.16, 0.075, 0.39))
    peak_shadow_travel = maxf(peak_shadow_travel,
        shadow.position.distance_to(Vector3(
            _pose_for_layer(i).x + len * 0.5,
            0.022 + float(i) * 0.001,
            _pose_for_layer(i).z + 0.5)))

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
        # A centered half-cell offset would place BOTH lower stud columns
        # directly under this brick's rim, not inside its socket. Align
        # one stud column to the shorter support's actual open pocket.
        return Vector3(0.0, STEP, 0.0)
    return Vector3(0.24, 2.0 * STEP + START_LIFT, 0.0)

func reset_stack() -> void:
    paused_by_user = false
    is_simulating = false
    simulation_seconds = 0.0
    contact_count = 0
    interbrick_contacts = 0
    peak_tilt_degrees = 0.0
    peak_lateral_shift = 0.0
    peak_drop = 0.0
    peak_stud_shift = 0.0
    peak_edge_flex = 0.0
    first_contact_at = -1.0
    impact_peak = 0.0
    peak_spring_compression = 0.0
    peak_spring_rebound = 0.0
    peak_shadow_travel = 0.0
    peak_local_impact = 0.0
    total_local_hits = 0
    peak_silhouette_bulge = 0.0
    peak_follow_through = 0.0
    for i in range(bodies.size()):
        var body: RigidBody3D = bodies[i]
        body.freeze = true
        body.linear_velocity = Vector3.ZERO
        body.angular_velocity = Vector3.ZERO
        body.transform = Transform3D(Basis.IDENTITY, _pose_for_layer(i))
        body.sleeping = true
        impact_energy[i] = 0.0
        impact_local_energy[i] = 0.0
        impact_local_age[i] = 3.0
        observed_local_samples[i] = 0
        impact_local_points[i] = Vector3(
            0.5 if i == 1 else 1.0, 0.1, 0.5)
        body.call("clear_contact_sample")
        spring_displacement[i] = 0.0
        spring_velocity[i] = 0.0
        _apply_visual_spring(i, 0.0)
        _update_ground_shadow(i)

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
    var magnitude := clampf(impact_multiplier, 0.45, 1.55)
    bodies[2].apply_central_impulse(Vector3(1.20, 0.0, 0.05) *
        magnitude)
    bodies[2].apply_torque_impulse(Vector3(0.0, 0.0, -0.50) *
        magnitude)

## Changing impact intensity is intentionally a physics input change,
## never a fake animation-speed multiplier. The caller explicitly replays.
func select_impact_multiplier(value: float) -> void:
    impact_multiplier = clampf(value, 0.45, 1.55)

func select_gel_softness(value: float) -> void:
    gel_softness = clampf(value, 0.0, 1.0)
    for i in range(paints.size()):
        _apply_visual_spring(i, impact_energy[i])

## A real pause keeps the bodies and their rotations where they were.
## Frozen bodies retain their velocities until unpaused. If the scene has
## already ended, pause is ignored and a new replay is required.
func set_lab_paused(value: bool) -> void:
    if not is_simulating or paused_by_user == value:
        return
    paused_by_user = value
    for i in range(1, bodies.size()):
        bodies[i].freeze = value

func _on_contact(other: Node, i: int) -> void:
    if not is_simulating or i == 0:
        return
    var body: RigidBody3D = bodies[i]
    var speed := body.linear_velocity.length()
    var strength := clampf(0.34 + speed * 0.11, 0.34, 0.92)
    impact_energy[i] = maxf(impact_energy[i], strength)
    # Impacts ADD kinetic energy to a real underdamped oscillator. Unlike
    # the old exp-only falloff, gel compresses, rebounds and overshoots.
    spring_velocity[i] = clampf(spring_velocity[i] +
        strength * 8.5, -10.0, 14.0)
    impact_peak = maxf(impact_peak, strength)
    contact_count += 1
    if first_contact_at < 0.0:
        first_contact_at = simulation_seconds
    # Actual contact pair propagates a smaller compression to its support.
    # A body can also hit the floor (StaticBody3D). Typed arrays reject
    # searching for a static body in Array[RigidBody3D] at runtime.
    if other is RigidBody3D:
        var neighbor: int = bodies.find(other)
        if neighbor >= 0:
            interbrick_contacts += 1
            impact_energy[neighbor] = maxf(impact_energy[neighbor],
                strength * 0.48)
            spring_velocity[neighbor] = clampf(
                spring_velocity[neighbor] + strength * 3.8, -10.0, 14.0)

func _apply_visual_spring(i: int, energy: float) -> void:
    var compressed: float = clampf(
        spring_displacement[i] * 1.15, -0.24, 0.76)
    var phase: float = simulation_seconds * 22.0
    var angular: float = 0.0
    if i < bodies.size():
        angular = clampf(bodies[i].angular_velocity.z * 0.08, -0.24, 0.24)
    # Measured body velocity plus angular momentum move the upper gel
    # with a small inertia offset independent from rigid-body rotation.
    var inertia: float = angular * 1.6
    if i < bodies.size():
        inertia += bodies[i].linear_velocity.x * 0.21
    inertia = clampf(inertia, -0.72, 0.72)
    paints[i].set_shader_parameter("deformation", compressed)
    paints[i].set_shader_parameter("silhouette_softness", gel_softness)
    paints[i].set_shader_parameter("momentum_lag", inertia)
    peak_silhouette_bulge = maxf(peak_silhouette_bulge,
        maxf(0.0, compressed) * gel_softness * 0.17)
    peak_follow_through = maxf(peak_follow_through,
        absf(inertia) * gel_softness)
    paints[i].set_shader_parameter("impact_local_point", impact_local_points[i])
    paints[i].set_shader_parameter("impact_local_energy", impact_local_energy[i])
    paints[i].set_shader_parameter("impact_local_age", impact_local_age[i])
    paints[i].set_shader_parameter("tilt_energy", angular)
    paints[i].set_shader_parameter("ripple_energy", energy * 0.55)
    paints[i].set_shader_parameter("ripple_phase", fposmod(phase, TAU))
    var edge_flex := clampf(energy * 0.85, 0.0, 1.0)
    var edge_axis := Vector2(1.0, 0.4)
    if i < bodies.size():
        var motion := bodies[i].linear_velocity
        if Vector2(motion.x, motion.z).length_squared() > 0.0004:
            edge_axis = Vector2(motion.x, motion.z).normalized()
    paints[i].set_shader_parameter("soft_edge_strength", edge_flex)
    paints[i].set_shader_parameter("soft_edge_axis", edge_axis)
    peak_edge_flex = maxf(peak_edge_flex, edge_flex)
    var coat := layers[i].get_node("ThinOpticalClearcoat") as MeshInstance3D
    var coat_mat := coat.material_override as ShaderMaterial
    coat_mat.set_shader_parameter("deformation", compressed)
    coat_mat.set_shader_parameter("silhouette_softness", gel_softness)
    coat_mat.set_shader_parameter("momentum_lag", inertia)
    coat_mat.set_shader_parameter("impact_local_point", impact_local_points[i])
    coat_mat.set_shader_parameter("impact_local_energy", impact_local_energy[i])
    coat_mat.set_shader_parameter("impact_local_age", impact_local_age[i])
    coat_mat.set_shader_parameter("tilt_energy", angular)
    coat_mat.set_shader_parameter("ripple_energy", energy * 0.55)
    coat_mat.set_shader_parameter("ripple_phase", fposmod(phase, TAU))
    coat_mat.set_shader_parameter("soft_edge_strength", edge_flex)
    coat_mat.set_shader_parameter("soft_edge_axis", edge_axis)
    _deform_molded_studs(i, compressed, energy, phase)

## Reposition each actual modeled stud around the MOVING gel crown.
## The old node-wide scale.y shrank the pegs toward the floor, pulling their
## bottom lip away from the deforming shell. This applies the same vertical
## squash to the stud origin, retains its 0.68 mesh scale, and adds a tiny
## phase-lagged lean. Maximum four studs per brick: no new draw calls.
func _deform_molded_studs(i: int, squash_amount: float,
        energy: float, phase: float) -> void:
    var caps := layers[i].get_node("ActualFourMoldedStuds") as MultiMeshInstance3D
    var multi: MultiMesh = caps.multimesh
    var length: int = 1 if i == 1 else 2
    var extent_center := Vector2(float(length) * 0.5, 0.5)
    var vertical_scale := 1.0 - squash_amount * 0.19
    var lateral_scale := 1.0 + squash_amount * 0.075
    caps.scale = Vector3.ONE
    for j in range(multi.instance_count):
        var cell := int(j / 2)
        var lane := j % 2
        var original := Vector2(float(cell) + 0.5,
            0.265 if lane == 0 else 0.735)
        var away := original - extent_center
        var crest := sin(original.x * 8.0 - fposmod(phase, TAU)) * cos(
            original.y * 5.2 + fposmod(phase, TAU) * 0.35)
        var phase_lag := sin(phase * 0.66 + float(j) * 0.72)
        var ripple := energy * 0.55 * crest * 0.023
        var bend := energy * 0.030 * phase_lag
        var xz := extent_center + away * lateral_scale
        xz.x += bend * 0.25
        var origin := Vector3(xz.x,
            0.055 + (0.18944 - 0.055) * vertical_scale + ripple, xz.y)
        var basis := Basis(
            Vector3(lateral_scale, 0.0, 0.0),
            Vector3(bend * 0.68, 0.68 * vertical_scale, 0.0),
            Vector3(0.0, 0.0, lateral_scale))
        multi.set_instance_transform(j, Transform3D(basis, origin))
        peak_stud_shift = maxf(peak_stud_shift,
            absf(origin.y - 0.18944) + absf(xz.x - original.x))

func _physics_process(delta: float) -> void:
    if not is_simulating or paused_by_user:
        return
    simulation_seconds += maxf(delta, 0.0)
    peak_tilt_degrees = maxf(peak_tilt_degrees,
        absf(rad_to_deg(bodies[2].rotation.z)))
    peak_lateral_shift = maxf(peak_lateral_shift,
        absf(bodies[2].position.x - _pose_for_layer(2).x))
    peak_drop = maxf(peak_drop,
        _pose_for_layer(2).y - bodies[2].position.y)
    # The fixed-step solver has a stable critical stiffness range for
    # 30/60/120 Hz. It never depends on the GPU render frame rate.
    var step := minf(maxf(delta, 0.0), 0.034)
    for i in range(3):
        # The contact solver has the accurate LOCAL origin, even when a
        # brick is rotated on its edge. Use it instead of moving the wave
        # along the body midpoint or replaying a canned impact.
        var sampler: RigidBody3D = bodies[i]
        var newest_sample: int = int(sampler.get("samples_reported"))
        var restarted_wave := false
        if newest_sample > observed_local_samples[i]:
            observed_local_samples[i] = newest_sample
            var relative_speed: float = float(sampler.get(
                "local_impact_speed"))
            # A contact manifold generates solver samples on EVERY tick
            # while two rigid bodies slide together. Starting a new wave
            # for each one pins the crest to one spot forever. Admit only
            # substantial impulses, with 120 ms minimum wave travel time.
            if relative_speed >= 0.70 and impact_local_age[i] >= 0.12:
                var local_point: Vector3 = sampler.get("local_impact_point")
                var max_length := 1.0 if i == 1 else 2.0
                impact_local_points[i] = Vector3(
                    clampf(local_point.x, 0.0, max_length),
                    clampf(local_point.y, 0.0, 0.75),
                    clampf(local_point.z, 0.0, 1.0))
                impact_local_energy[i] = clampf(
                    0.25 + relative_speed * 0.14, 0.0, 0.96)
                impact_local_age[i] = 0.0
                total_local_hits += 1
                peak_local_impact = maxf(peak_local_impact,
                    impact_local_energy[i])
                restarted_wave = true
        if not restarted_wave:
            impact_local_age[i] = minf(3.0, impact_local_age[i] + step)
            impact_local_energy[i] *= exp(-4.5 * step)
            if impact_local_energy[i] < 0.003:
                impact_local_energy[i] = 0.0
        var accel: float = (-GEL_OMEGA * GEL_OMEGA * spring_displacement[i] -
            2.0 * GEL_DAMPING * GEL_OMEGA * spring_velocity[i])
        spring_velocity[i] += accel * step
        spring_displacement[i] += spring_velocity[i] * step
        spring_displacement[i] = clampf(spring_displacement[i], -0.42, 0.92)
        if (absf(spring_displacement[i]) < 0.0004 and
                absf(spring_velocity[i]) < 0.008):
            spring_displacement[i] = 0.0
            spring_velocity[i] = 0.0
        peak_spring_compression = maxf(peak_spring_compression,
            spring_displacement[i])
        peak_spring_rebound = maxf(peak_spring_rebound,
            -spring_displacement[i])
        impact_energy[i] *= exp(-IMPACT_DECAY * step)
        if impact_energy[i] < IMPACT_THRESHOLD:
            impact_energy[i] = 0.0
        _apply_visual_spring(i, impact_energy[i])
        _update_ground_shadow(i)
    # The simulation stays awake for collision review, until a new tap.
    # Do not teleport objects to rest or falsify a deterministic collapse.

func _process(_delta: float) -> void:
    # Disable the parent's scripted trajectory; physics owns all poses.
    pass
