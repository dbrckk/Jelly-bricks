extends SceneTree
## End-to-end prototype check in the actual Godot 3D physics server,
## under Mesa OpenGL (MultiMesh requires a real rendering driver).
const RIG = preload("res://prototypes/single_brick/physics_stack.gd")
const SHOTS := ["01-static", "02-first-contact", "03-collapse", "04-settled"]
const AT_TICKS := [4, 38, 85, 168]
var rig: Node3D
var ticks := 0
var shot_index := 0
var finished := false

func _initialize() -> void:
    rig = RIG.new()
    root.add_child(rig)
    var out_dir := ProjectSettings.globalize_path("res://../build/physics-stack")
    if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
        push_error("Cannot create physical Jelly QA output directory")
        quit(1)

func _physics_process(_delta: float) -> bool:
    ticks += 1
    if ticks == 6:
        if rig.bodies.size() != 3 or not rig.bodies[0].freeze:
            push_error("Expected static base and three physical bodies")
            quit(1)
            return false
        for i in range(3):
            var body: RigidBody3D = rig.bodies[i]
            var length: int = 1 if i == 1 else 2
            var found := 0
            var studs := 0
            for child in body.get_children():
                if child is CollisionShape3D:
                    found += 1
                    if child.name.begins_with("PhysicalStud_"):
                        studs += 1
                        if not child.shape is CylinderShape3D or \
                                absf(child.position.y - rig.STUD_CENTER_Y) > 0.001:
                            push_error("Invalid molded stud collider")
                            quit(1)
                            return false
            # One solid roof + four perimeter strips + two studs/cell.
            if found != 5 + 2 * length or studs != 2 * length or \
                    rig.layers[i].get_parent() != body:
                push_error("A molded brick lost its hollow socket or physical studs")
                quit(1)
                return false
            if body.get_node("CollisionRoof").position.y < 0.35 or \
                    body.get_node("RimFront").position.y >= 0.28:
                push_error("Compound collider would seal the underside socket")
                quit(1)
                return false
            # The optic experiment must apply to the real moving bodies,
            # while the five original deterministic reference frames stay
            # on the previous visually validated material preset.
            var bulk := float(rig.paints[i].get_shader_parameter("bulk_optics"))
            if absf(bulk - 0.88) > 0.001:
                push_error("The depth-dependent gel shader is not enabled on this body")
                quit(1)
                return false
        # At least one pair of actual lower studs must fit INSIDE each
        # upper underside pocket (clearance from all four rim strips).
        # A centered 0.5-cell offset is visually plausible but places pegs
        # directly below the rim and cannot genuinely interlock.
        for upper_i in range(1, 3):
            var lower := rig.bodies[upper_i - 1] as RigidBody3D
            var upper := rig.bodies[upper_i] as RigidBody3D
            var upper_length := 1.0 if upper_i == 1 else 2.0
            var fits := 0
            for child in lower.get_children():
                if child is CollisionShape3D and child.name.begins_with("PhysicalStud_"):
                    var local_peg: Vector3 = lower.position + child.position - upper.position
                    if local_peg.x > rig.STUD_RADIUS + rig.RIM_THICKNESS and \
                            local_peg.x < upper_length - rig.STUD_RADIUS - rig.RIM_THICKNESS and \
                            local_peg.z > rig.STUD_RADIUS + rig.RIM_THICKNESS and \
                            local_peg.z < 1.0 - rig.STUD_RADIUS - rig.RIM_THICKNESS:
                        fits += 1
            if fits < 2:
                push_error("Physical supports do not align at least two studs with the upper socket")
                quit(1)
                return false
        rig.replay_stack()
        if rig.bodies[1].freeze or rig.bodies[2].freeze:
            push_error("Tap must release the two upper bodies")
            quit(1)
            return false
    if ticks == 194:
        print("Physics debug: contacts=", rig.contact_count,
            " interbrick=", rig.interbrick_contacts,
            " tilt=", rig.peak_tilt_degrees,
            " lateral=", rig.peak_lateral_shift,
            " drop=", rig.peak_drop,
            " top_now=", rig.bodies[2].position,
            " middle_now=", rig.bodies[1].position,
            " max_stud_shift=", rig.peak_stud_shift,
            " max_edge_flex=", rig.peak_edge_flex)
        if rig.contact_count < 1 or rig.impact_peak <= 0.2:
            push_error("No observed physical collision / no contact-driven gel")
            quit(1)
            return false
        if rig.first_contact_at < 0.0 or rig.first_contact_at > 3.2:
            push_error("Collision time is not physical")
            quit(1)
            return false
        if rig.interbrick_contacts < 1:
            push_error("Upper brick missed the support; only floor contact occurred")
            quit(1)
            return false
        if rig.peak_tilt_degrees < 18.0 or rig.peak_lateral_shift < 0.35:
            push_error("The stack remained almost static instead of toppling: %.1f degrees, %.2f units" %
                [rig.peak_tilt_degrees, rig.peak_lateral_shift])
            quit(1)
            return false
        if rig.peak_drop < 0.30:
            push_error("The upper piece never descended by 0.30 world units")
            quit(1)
            return false
        if rig.peak_edge_flex < 0.12 or rig.peak_stud_shift < 0.002:
            push_error("Collisions did not bend corners and shift independent studs")
            quit(1)
            return false
        for i in range(3):
            var core_mat := rig.paints[i] as ShaderMaterial
            var coat_mesh := rig.layers[i].get_node(
                "ThinOpticalClearcoat") as MeshInstance3D
            var coat_mat := coat_mesh.material_override as ShaderMaterial
            var edge_main := float(core_mat.get_shader_parameter(
                "soft_edge_strength"))
            var edge_coat := float(coat_mat.get_shader_parameter(
                "soft_edge_strength"))
            if absf(edge_main - edge_coat) > 0.0001:
                push_error("The wet coat detached from the bending corners")
                quit(1)
                return false
            var caps := rig.layers[i].get_node(
                "ActualFourMoldedStuds") as MultiMeshInstance3D
            if caps.multimesh.instance_count != (2 if i == 1 else 4) or \
                    caps.scale.distance_to(Vector3.ONE) > 0.0001:
                push_error("Studs were not animated as independent instances")
                quit(1)
                return false
        # Distinct MultiMesh resources are mandatory: otherwise deforming
        # a top stud silently alters the fixed bottom brick.
        for i in range(3):
            var left_studs := rig.layers[i].get_node(
                "ActualFourMoldedStuds") as MultiMeshInstance3D
            for j in range(i + 1, 3):
                var right_studs := rig.layers[j].get_node(
                    "ActualFourMoldedStuds") as MultiMeshInstance3D
                if left_studs.multimesh == right_studs.multimesh:
                    push_error("Physics bricks share writable stud transforms")
                    quit(1)
                    return false
        for i in range(3):
            var p: Vector3 = rig.bodies[i].global_position
            if p.y < -1.0 or p.y > 5.0 or absf(p.x) > 7.0 or absf(p.z) > 7.0:
                push_error("Physics explosion or floor tunnelling in body %d" % i)
                quit(1)
                return false
        if not rig.bodies[0].freeze or rig.bodies[0].position.length() > 0.001:
            push_error("Base must remain fixed under force")
            quit(1)
            return false
        finished = true
        print("PASS: real rigid-body gravity, contacts, support and gel response;",
            " contacts=", rig.contact_count,
            " peak=", rig.impact_peak,
            " first-contact=", rig.first_contact_at,
            " interbrick=", rig.interbrick_contacts,
            " peak-tilt=", rig.peak_tilt_degrees,
            " lateral-shift=", rig.peak_lateral_shift)
    return false

func _process(_delta: float) -> bool:
    if shot_index < AT_TICKS.size() and ticks >= AT_TICKS[shot_index]:
        var frame: Image = root.get_texture().get_image()
        if frame == null or frame.is_empty():
            push_error("No physically simulated GPU frame")
            quit(1)
            return false
        frame.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
        var file: String = ProjectSettings.globalize_path(
            "res://../build/physics-stack/" + SHOTS[shot_index] + ".png")
        if frame.save_png(file) != OK:
            push_error("Failed to save physics snapshot: " + file)
            quit(1)
            return false
        print("PASS: real physics screenshot ", SHOTS[shot_index],
            " tick=", ticks)
        shot_index += 1
    if finished and shot_index == SHOTS.size():
        print("PASS: physical stack prototype all assertions and four renders")
        quit()
    return false
