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
        var center_piece: Node3D = stage.layers[1]
        var center_shell: MeshInstance3D = center_piece.get_node("CurvedShellWithSocket")
        var center_studs: MultiMeshInstance3D = center_piece.get_node("ActualFourMoldedStuds")
        if center_studs.multimesh.instance_count != 2 or \
                absf(center_shell.mesh.get_aabb().size.x - 1.072) > 0.03 or \
                absf(center_piece.position.x - 0.5) > 0.001:
            push_error("Center support must be a one-cell Jelly with two short studs")
            quit(1)
            return false
        stage.sample_stack("rest")
        if stage.layer_energy[0] > 0.0001 or stage.layer_energy[1] > 0.0001 or stage.layer_energy[2] > 0.0001:
            push_error("Rest pose should have no compression")
            quit(1)
            return false
        stage.set_stack_time(0.76)
        var actual_paint: ShaderMaterial = stage.paints[2]
        var top_coat: ShaderMaterial = stage.layers[2].get_node(
            "ThinOpticalClearcoat").material_override as ShaderMaterial
        var actual_squash: float = float(actual_paint.get_shader_parameter("deformation"))
        if actual_squash <= 0.0 or absf(actual_squash -
                float(top_coat.get_shader_parameter("deformation"))) > 0.0001:
            push_error("Impact skin detached from compressed core")
            quit(1)
            return false
        var shell_ripple: float = float(actual_paint.get_shader_parameter("ripple_energy"))
        if shell_ripple <= 0.0 or absf(shell_ripple -
                float(top_coat.get_shader_parameter("ripple_energy"))) > 0.0001:
            push_error("Ripple energy not shared by the colored body and reflective skin")
            quit(1)
            return false
        if absf(stage.layers[2].get_node("ActualFourMoldedStuds").scale.y -
                (1.0 - actual_squash * 0.19)) > 0.0001:
            push_error("Studs did not compress with underlying gel")
            quit(1)
            return false
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
        stage.set_stack_time(0.94)
        if absf(stage.layer_sway[1]) < 0.05 or stage.layer_sway[2] == 0.0:
            push_error("Visible delayed wobble not propagated through support")
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
