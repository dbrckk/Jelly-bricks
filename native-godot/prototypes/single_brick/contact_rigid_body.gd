extends RigidBody3D
## Physical contact locations sampled directly from Godot's physics solver.
## No geometric guess based on body centers or a scripted collision timeline.
## Keep only the last impactful solver sample to drive a small visual ripple.
var local_impact_point: Vector3 = Vector3(0.5, 0.1, 0.5)
var local_impact_speed: float = 0.0
var samples_reported: int = 0
var local_impact_normal: Vector3 = Vector3.UP

func clear_contact_sample() -> void:
    local_impact_point = Vector3(0.5, 0.1, 0.5)
    local_impact_speed = 0.0
    local_impact_normal = Vector3.UP
    samples_reported = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    var count: int = state.get_contact_count()
    if count == 0:
        return
    var best_speed := 0.0
    var best_index := -1
    for i in range(count):
        var relative_velocity: Vector3 = (
            state.get_contact_local_velocity_at_position(i) -
            state.get_contact_collider_velocity_at_position(i))
        var relative_speed: float = relative_velocity.length()
        if relative_speed > best_speed:
            best_speed = relative_speed
            best_index = i
    if best_index < 0:
        return
    # Stable under resting contact: do not reset the wave every physics tick
    # when a stack is resting against an unmoving support.
    if best_speed < 0.10:
        return
    var point: Vector3 = state.get_contact_local_position(best_index)
    if not point.is_finite():
        return
    local_impact_point = point
    local_impact_speed = clampf(best_speed, 0.0, 25.0)
    local_impact_normal = state.get_contact_local_normal(best_index)
    samples_reported += 1
