extends SceneTree
## End-to-end real GPU material review. Four posed states and a settled shot
## are produced by the actual project renderer, never by mock images.
var rig: Node3D
var ticks: int = 0
const PHASES := ["rest", "flight", "impact", "rebound", "settled"]
const DURATION := 28
const OUTPUT := "res://../build/single-brick"

func _initialize() -> void:
    var script: Script = load("res://prototypes/single_brick/scene.gd")
    if script == null:
        push_error("Prototype script unavailable")
        quit(1)
        return
    rig = script.new()
    root.add_child(rig)
    rig.time_enabled = false
    var folder := ProjectSettings.globalize_path(OUTPUT)
    var error := DirAccess.make_dir_recursive_absolute(folder)
    if error != OK:
        push_error("Cannot create sample directory: " + str(error))
        quit(1)
        return
func _process(_dt: float) -> bool:
    ticks += 1
    if ticks == 8:
        if rig.shell == null or rig.studs == null \
                or rig.studs.multimesh.instance_count != 4:
            push_error("Prototype has no actual molded volume with four studs")
            quit(1)
            return false
        rig.sample("rest")
    if ticks % DURATION != 0:
        return false
    var index: int = int(ticks / DURATION) - 1
    if index < 0 or index >= PHASES.size():
        quit()
        return false
    var phase: String = PHASES[index]
    var shot: Image = root.get_texture().get_image()
    if shot == null or shot.is_empty():
        push_error("OpenGL did not render the single brick")
        quit(1)
        return false
    shot.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
    var red_pixels: int = 0
    var bright_pixels: int = 0
    for y in range(230, 980, 4):
        for x in range(120, 600, 4):
            var pixel: Color = shot.get_pixel(x, y)
            if pixel.r > pixel.g * 1.24 and pixel.r > pixel.b * 1.22 \
                    and pixel.r > 0.18:
                red_pixels += 1
            if pixel.r > 0.80 and pixel.g > 0.80 and pixel.b > 0.80:
                bright_pixels += 1
    if red_pixels < 90 or bright_pixels < 300:
        push_error("Missing colored volume or photographic background: " +
            phase + " reds=" + str(red_pixels) +
            " whites=" + str(bright_pixels))
        quit(1)
        return false
    var target := ProjectSettings.globalize_path(
        OUTPUT + "/" + str(index + 1).pad_zeros(2) + "-" + phase + ".png")
    if shot.save_png(target) != OK:
        push_error("Failed saving actual GPU capture: " + phase)
        quit(1)
        return false
    print("PASS: real single-brick %s red=%d neutral=%d: %s" %
        [phase, red_pixels, bright_pixels, target])
    if index + 1 >= PHASES.size():
        print("PASS: five captured real Godot single-brick states")
        quit()
    else:
        rig.sample(PHASES[index + 1])
    return false
