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
            var core := rig.bodies[i].get_node("CollisionCore") as CollisionShape3D
            if core == null or core.shape == null or                     rig.layers[i].get_parent() != rig.bodies[i]:
                push_error("A displayed molded brick is missing collision geometry")
                quit(1)
                return false
        rig.replay_stack()
        if rig.bodies[1].freeze or rig.bodies[2].freeze:
            push_error("Tap must release the two upper bodies")
            quit(1)
            return false
    if ticks == 194:
        if rig.contact_count < 1 or rig.impact_peak <= 0.2:
            push_error("No observed physical collision / no contact-driven gel")
            quit(1)
            return false
        if rig.first_contact_at < 0.0 or rig.first_contact_at > 3.2:
            push_error("Collision time is not physical")
            quit(1)
            return false
        if rig.bodies[2].position.y >= 1.82 - 0.30:
            push_error("The upper piece failed to fall under gravity")
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
            " first-contact=", rig.first_contact_at)
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
