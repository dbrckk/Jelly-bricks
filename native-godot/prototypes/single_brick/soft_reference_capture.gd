extends SceneTree
## Three actual GPU captures of the ONE dense red 2x1 molded gel volume.
## Compiles against Godot 4.6 GL Compatibility; no Blender frame is passed
## off as a game render. The film reference is assessed separately.
const STUDY = preload("res://prototypes/single_brick/soft_reference.tscn")
var study: Node3D
var ticks := 0
var captures := 0

func _initialize() -> void:
    study = STUDY.instantiate() as Node3D
    root.add_child(study)
    var out := ProjectSettings.globalize_path("res://../build/soft-reference")
    if DirAccess.make_dir_recursive_absolute(out) != OK:
        push_error("Could not create dedicated dense-mesh capture folder")
        quit(1)

func _process(_delta: float) -> bool:
    ticks += 1
    if ticks == 5:
        if study.base_triangles <= 100 or \
                study.fine_triangles != study.base_triangles * 16:
            push_error("Fourfold-per-level triangle subdivision is incorrect")
            quit(1)
            return false
        if study.shell.mesh != study.wet_coat.mesh:
            push_error("Dense core and glossy coating are no longer identical")
            quit(1)
            return false
        if study.gel_material.shader != study.OPAQUE_GEL or \
                float(study.gel_material.get_shader_parameter(
                    "interior_scatter")) < 0.60:
            push_error("Opaque optical reference lost volume scattering preset")
            quit(1)
            return false
        print("PASS: single red 2x1 studio body tessellation ",
            study.base_triangles, " to ", study.fine_triangles,
            " triangles; reusable mesh for coat")
    if ticks == 25:
        study.sample_reference("compression")
    if ticks == 48:
        study.sample_reference("rebound")
    if ticks in [20, 43, 68]:
        var name := ""
        match captures:
            0: name = "01-red-rest.png"
            1: name = "02-red-compression.png"
            2: name = "03-red-rebound.png"
        var frame: Image = root.get_texture().get_image()
        if frame == null or frame.is_empty():
            push_error("OpenGL did not render the 2x1 studio brick")
            quit(1)
            return false
        frame.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
        var colored := 0
        for y in range(180, 1080, 8):
            for x in range(70, 650, 8):
                var pixel := frame.get_pixel(x, y)
                if pixel.r > 0.20 and pixel.r > pixel.g * 1.20 and \
                        pixel.r > pixel.b * 1.15:
                    colored += 1
        if colored < 40:
            push_error("Reference frame has no visible red gel volume: " + name)
            quit(1)
            return false
        var path := ProjectSettings.globalize_path(
            "res://../build/soft-reference/" + name)
        if frame.save_png(path) != OK:
            push_error("Unable to save dense Godot render: " + name)
            quit(1)
            return false
        captures += 1
        print("PASS: dense red gel real GPU capture: ", name,
            " pixels=", colored)
    if ticks >= 70:
        if captures != 3:
            push_error("Incomplete dense red brick comparison frames")
            quit(1)
            return false
        print("PASS: isolated high-density red gel study all assertions")
        quit()
    return false
