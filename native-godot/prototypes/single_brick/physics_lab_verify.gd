extends SceneTree
## Actual rendered Godot 4.6 smoke test of the separately-installable lab.
## Validates controls, contact-local waves, pause/resume and three GPU frames.
const LAB_SCENE = preload("res://prototypes/single_brick/physics_lab.tscn")
const SHOTS := ["01-idle.png", "02-local-contact.png", "03-collapse.png"]
# A wall-clock tick is not a collision. Capture the middle frame ONLY
# after a real solver impulse, or the "local contact" image is dishonest.
const IDLE_TICK := 35
const SETTLED_TICK := 195
var lab: Node3D
var ticks: int = 0
var shots: int = 0
var completed: bool = false

func _initialize() -> void:
    lab = LAB_SCENE.instantiate() as Node3D
    root.add_child(lab)
    var path := ProjectSettings.globalize_path("res://../build/physics-lab")
    if DirAccess.make_dir_recursive_absolute(path) != OK:
        push_error("Cannot create Physics Lab capture output")
        quit(1)

func _press(node_path: String) -> void:
    var button := lab.get_node(node_path) as Button
    if button == null or button.disabled:
        push_error("Missing functional Physics Lab button: " + node_path)
        quit(1)
        return
    button.pressed.emit()

func _physics_process(_delta: float) -> bool:
    ticks += 1
    if ticks == 6:
        if lab.bodies.size() != 3 or lab.hud == null or lab.is_simulating:
            push_error("The touch lab must start at rest with three bricks")
            quit(1)
            return false
        var root_path := "MobileExperimentControls/InteractionOverlay/"
        if not lab.has_node(root_path + "StatusPanel/HeaderContent/LivePhysicsMetrics"):
            push_error("HUD missing real physics performance metrics")
            quit(1)
            return false
        if not lab.has_node(root_path + "PhysicsControls/ControlContent/PlaybackActions/ResetImpact"):
            push_error("HUD missing physical controls")
            quit(1)
            return false
    if ticks == 45:
        _press("MobileExperimentControls/InteractionOverlay/PhysicsControls/ControlContent/ImpactModes/ImpactPreset2")
        if lab.current_profile != 2 or absf(lab.impact_multiplier - 1.48) > 0.0001 or \
                lab.bodies[2].freeze or not lab.is_simulating:
            push_error("INTENSE should restart using a stronger real torque impulse")
            quit(1)
            return false
    if ticks == 70:
        _press("MobileExperimentControls/InteractionOverlay/PhysicsControls/ControlContent/PlaybackActions/PauseImpact")
        if not lab.paused_by_user or not lab.bodies[2].freeze:
            push_error("PAUSE must actually freeze the physics solver")
            quit(1)
            return false
    if ticks == 75:
        _press("MobileExperimentControls/InteractionOverlay/PhysicsControls/ControlContent/PlaybackActions/PauseImpact")
        if lab.paused_by_user or lab.bodies[2].freeze:
            push_error("REPRENDRE must release the same physical bodies")
            quit(1)
            return false
    if ticks == 95:
        _press("MobileExperimentControls/InteractionOverlay/PhysicsControls/ControlContent/PlaybackActions/ResetImpact")
        if lab.is_simulating or lab.contact_count != 0 or not lab.bodies[2].freeze:
            push_error("REPOS did not reset and freeze the experiment")
            quit(1)
            return false
    if ticks == 105:
        _press("MobileExperimentControls/InteractionOverlay/PhysicsControls/ControlContent/ImpactModes/ImpactPreset1")
        if lab.current_profile != 1 or absf(lab.impact_multiplier - 1.0) > 0.0001:
            push_error("NORMAL did not restore the reference impulse")
            quit(1)
            return false
    if ticks == 225:
        if lab.interbrick_contacts < 1 or lab.peak_drop < 0.30 or \
                lab.peak_edge_flex < 0.1 or lab.peak_stud_shift < 0.002 or \
                lab.total_local_hits < 1 or lab.peak_local_impact < 0.24:
            push_error("The touch lab is not driving actual Jelly collisions")
            quit(1)
            return false
        var metrics := lab.metrics as Label
        if metrics == null or not metrics.text.contains("FPS") or \
                not metrics.text.contains("CONTACTS"):
            push_error("The live HUD is not showing measured engine data")
            quit(1)
            return false
        completed = true
        print("PASS: Physics Lab Android controls + live HUD, contacts=",
            lab.interbrick_contacts, " stud recoil=", lab.peak_stud_shift)
    return false

func _process(_delta: float) -> bool:
    var capture_now := false
    if shots == 0:
        capture_now = ticks >= IDLE_TICK
    elif shots == 1:
        var active_local_wave := false
        for i in range(lab.impact_local_energy.size()):
            if lab.impact_local_energy[i] > 0.20 and \
                    lab.impact_local_age[i] <= 0.13:
                active_local_wave = true
        capture_now = lab.total_local_hits > 0 and active_local_wave
    elif shots == 2:
        capture_now = ticks >= SETTLED_TICK
    if shots < SHOTS.size() and capture_now:
        var frame: Image = root.get_texture().get_image()
        if frame == null or frame.is_empty():
            push_error("No GPU screenshot for the Android lab")
            quit(1)
            return false
        frame.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
        # Reject the empty first frames produced before OpenGL has finished
        # drawing the scene; an all-white PNG is not meaningful visual QA.
        var colored := 0
        var dark_hud := 0
        for yy in range(20, 1240, 16):
            for xx in range(20, 700, 16):
                var c: Color = frame.get_pixel(xx, yy)
                if maxf(c.r, maxf(c.g, c.b)) - \
                        minf(c.r, minf(c.g, c.b)) > 0.14:
                    colored += 1
                if yy < 160 or yy > 1050:
                    if c.r < 0.34 and c.g < 0.36 and c.b < 0.45:
                        dark_hud += 1
        if colored < 85 or dark_hud < 60:
            push_error("Physics Lab screenshot was blank or missing its HUD")
            quit(1)
            return false
        var path := ProjectSettings.globalize_path(
            "res://../build/physics-lab/" + SHOTS[shots])
        if frame.save_png(path) != OK:
            push_error("Could not save Physics Lab screenshot")
            quit(1)
            return false
        if shots == 1 and lab.total_local_hits < 1:
            push_error("False positive: local-contact image has no solver contact")
            quit(1)
            return false
        shots += 1
        print("PASS: touch-screen HUD screenshot ", path,
            " solver_contact_count=", lab.total_local_hits)
    if completed and shots == SHOTS.size():
        print("PASS: complete Physics Lab interaction and rendering")
        quit()
    return false
