extends SceneTree
const RIG = preload("res://prototypes/single_brick/three_stack.gd")
var stage: Node3D
var count: int = 0
const STATES := ["rest", "approach", "contact", "wave", "settled"]
func _initialize() -> void:
    stage = RIG.new()
    root.add_child(stage)
    var dir := ProjectSettings.globalize_path("res://../build/three-stack")
    if DirAccess.make_dir_recursive_absolute(dir) != OK:
        push_error("Could not prepare output")
        quit(1)

func _process(_delta: float) -> bool:
    count += 1
    if count == 10:
        if stage.layers.size() != 3 or stage.paints.size() != 3:
            push_error("Three independent molded layers were not constructed")
            quit(1)
            return false
        stage.sample_stack("rest")
        if stage.layer_energy[0] > 0.0001 or stage.layer_energy[1] > 0.0001 or stage.layer_energy[2] > 0.0001:
            push_error("Rest pose should have no compression")
            quit(1)
            return false
        stage.set_stack_time(0.76)
        if stage.layer_energy[2] <= 0.01 or stage.layer_energy[1] > 0.001                 or stage.layer_energy[0] > 0.001:
            push_error("Upper layer impulse must precede support response")
            quit(1)
            return false
        stage.set_stack_time(0.81)
        if stage.layer_energy[1] <= 0.01 or stage.layer_energy[0] > 0.001:
            push_error("Wave must reach middle layer before base")
            quit(1)
            return false
        stage.set_stack_time(0.89)
        if stage.layer_energy[0] <= 0.01:
            push_error("Support wave never reached base")
            quit(1)
            return false
        stage.sample_stack(STATES[0])
    if count % 25 != 0:
        return false
    var index: int = int(count / 25) - 1
    if index < 0 or index >= STATES.size():
        return false
    var shot: Image = root.get_texture().get_image()
    if shot == null or shot.is_empty():
        push_error("No GPU image")
        quit(1)
        return false
    shot.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
    var vivid := 0
    for y in range(200, 1040, 5):
        for x in range(100, 620, 5):
            var col := shot.get_pixel(x, y)
            if maxf(col.r, maxf(col.g, col.b)) > 0.40 and                     maxf(col.r, maxf(col.g, col.b)) > minf(col.r, minf(col.g, col.b)) * 1.4:
                vivid += 1
    if vivid < 250:
        push_error("Three colorful volumes not visible: " + STATES[index])
        quit(1)
        return false
    var name: String = "%02d-%s.png" % [index + 1, STATES[index]]
    if shot.save_png(ProjectSettings.globalize_path(
            "res://../build/three-stack/" + name)) != OK:
        push_error("Unable to save actual OpenGL capture " + name)
        quit(1)
        return false
    print("PASS: three layers ", STATES[index], " pixels=", vivid)
    if index + 1 == STATES.size():
        print("PASS: reproducible three-brick GPU + delayed wave")
        quit()
    else:
        stage.sample_stack(STATES[index + 1])
    return false
