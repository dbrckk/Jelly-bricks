extends SceneTree
## Real GPU, real Godot 4.6: red 2x1 base + blue 1x1 on top,
## each with independent opaque-depth transmission from a staged viewport.
const STAGE = preload("res://prototypes/single_brick/layered_reference.tscn")
var stage: Node3D
var ticks := 0
var shots := 0
var transmitted: Image

func _initialize() -> void:
    stage = STAGE.instantiate() as Node3D
    root.add_child(stage)
    var path := ProjectSettings.globalize_path(
        "res://../build/layered-optics")
    if DirAccess.make_dir_recursive_absolute(path) != OK:
        push_error("Could not create multibrick render folder")
        quit(1)

func _validate_stages() -> bool:
    if stage.base_triangles < 100 or stage.fine_triangles != 8192 or \
            stage.upper_triangles < 1000:
        push_error("Multi-brick optically dense meshes not constructed")
        return false
    if stage.upper_shell.mesh != stage.upper_coat.mesh:
        push_error("Blue gel and blue coat have disconnected geometry")
        return false
    if stage.upper_studs.multimesh.instance_count != 2:
        push_error("Blue 1x1 requires exactly two molded studs")
        return false
    if stage.shell.layers != 2 or stage.upper_shell.layers != 4 or \
            stage.foreground_camera.cull_mask != 3 or \
            stage.backdrop_camera.cull_mask != 1:
        push_error("Optical layers cannot isolate red from blue")
        return false
    if stage.gel_material.get_shader_parameter(
            "backdrop_tex") != stage.backdrop_viewport.get_texture() or \
            stage.upper_paint.get_shader_parameter(
                "backdrop_tex") != stage.foreground_viewport.get_texture():
        push_error("Two layered textures not bound to their intended gels")
        return false
    if stage.foreground_viewport.render_target_update_mode != \
            SubViewport.UPDATE_ALWAYS:
        push_error("Upper refractive layer is not being rendered")
        return false
    if stage.foreground_viewport.size.x > 540 or \
            stage.foreground_viewport.size.y > 960:
        push_error("Mobile background render exceeds GPU budget")
        return false
    if stage.perf_label == null or stage.stack_toggle == null or \
            stage.quality_toggle == null:
        push_error("Android multi-brick HUD missing live controls and FPS")
        return false
    print("PASS: layered opaque-depth viewport masks=1/3/4, red=",
        stage.fine_triangles, " blue=", stage.upper_triangles,
        " background size=", stage.foreground_viewport.size)
    return true

func _capture(name: String) -> Image:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Actual Godot layered scene was not rendered")
        quit(1)
        return null
    image.resize(720, 1280, Image.INTERPOLATE_LANCZOS)
    var dest := ProjectSettings.globalize_path(
        "res://../build/layered-optics/" + name)
    if image.save_png(dest) != OK:
        push_error("Failed to archive real multi-brick GPU capture " + name)
        quit(1)
        return null
    print("PASS: multilayer real GPU screenshot ", name)
    shots += 1
    return image

func _process(_delta: float) -> bool:
    ticks += 1
    if ticks == 7 and not _validate_stages():
        quit(1)
        return false
    if ticks == 28:
        transmitted = _capture("01-two-gels-transmitted.png")
    if ticks == 36:
        stage.upper_paint.set_shader_parameter("backdrop_strength", 0.0)
    if ticks == 58:
        var opaque: Image = _capture("02-blue-optics-off.png")
        if opaque == null or transmitted == null:
            quit(1)
            return false
        var blue_pixels := 0
        var difference := 0.0
        for y in range(220, 870, 6):
            for x in range(130, 630, 6):
                var on: Color = transmitted.get_pixel(x, y)
                var off: Color = opaque.get_pixel(x, y)
                if on.b > on.r * 1.12 and on.b > on.g * 1.05 and \
                        on.b > 0.15:
                    blue_pixels += 1
                    difference += absf(on.r - off.r) + \
                        absf(on.g - off.g) + absf(on.b - off.b)
        if blue_pixels < 30 or difference / float(blue_pixels) < 0.012:
            push_error("Blue gel did not sample meaningful red-underlayer pixels")
            quit(1)
            return false
        print("PASS: blue-on-red composition changes real blue pixels ",
            "blue samples=", blue_pixels,
            " avg sum-RGB delta=", difference / float(blue_pixels))
    if ticks == 65:
        stage.upper_paint.set_shader_parameter("backdrop_strength", 0.76)
        stage.stack_toggle.pressed.emit()
        if stage.stack_enabled or \
                stage.foreground_viewport.render_target_update_mode != \
                SubViewport.UPDATE_DISABLED:
            push_error("Hidden blue gel must also stop its render pass")
            quit(1)
            return false
    if ticks == 89:
        _capture("03-red-only-gpu-saved.png")
    if ticks == 96:
        stage.stack_toggle.pressed.emit()
        stage.sample_reference("compression")
        if not stage.stack_enabled or \
                stage.foreground_viewport.render_target_update_mode != \
                SubViewport.UPDATE_ALWAYS:
            push_error("Blue stage could not resume from energy-saving mode")
            quit(1)
            return false
    if ticks == 108:
        var eco_width: int = stage.foreground_viewport.size.x
        stage.quality_toggle.pressed.emit()
        if stage.lightweight_mode or \
                stage.foreground_viewport.size.x <= eco_width:
            push_error("GPU detail button failed to increase pass resolution")
            quit(1)
            return false
        stage.quality_toggle.pressed.emit()
        if not stage.lightweight_mode or \
                stage.foreground_viewport.size.x != eco_width:
            push_error("GPU ECO mode failed to restore the frame budget")
            quit(1)
            return false
    if ticks == 117:
        _capture("04-two-gels-compression.png")
    if ticks >= 121:
        if shots != 4:
            push_error("Incomplete four-stage GPU multilayer proof")
            quit(1)
            return false
        print("PASS: real independent optical red+blue stacking all QA")
        quit()
    return false
