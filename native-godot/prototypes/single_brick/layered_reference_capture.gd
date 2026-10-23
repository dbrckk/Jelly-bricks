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
    if stage.upper_triangles_eco != 2048 or \
            stage.upper_triangles_detail != 8192 or \
            stage.upper_triangles != stage.upper_triangles_eco:
        push_error("Blue gel must start ECO with 2048 vs DETAIL 8192 triangles")
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
            stage.quality_toggle == null or stage.impact_button == null or \
            stage.force_slider == null or stage.force_readout == null:
        push_error("Android multi-brick HUD missing live controls and FPS")
        return false
    if absf(stage.visual_gain - 1.9) > 0.001 or \
            not stage.force_readout.text.contains("190%"):
        push_error("Android gel visual gain defaults are not readable")
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
        var eco_triangles: int = stage.upper_triangles
        stage.quality_toggle.pressed.emit()
        if stage.lightweight_mode or \
                stage.foreground_viewport.size.x <= eco_width or \
                stage.upper_triangles != 8192 or \
                stage.upper_shell.mesh != stage.upper_coat.mesh:
            push_error("GPU detail button failed to restore all geometry")
            quit(1)
            return false
        stage.quality_toggle.pressed.emit()
        if not stage.lightweight_mode or \
                stage.foreground_viewport.size.x != eco_width or \
                stage.upper_triangles != eco_triangles or \
                stage.upper_shell.mesh != stage.upper_coat.mesh:
            push_error("GPU ECO mode did not restore the full mobile budget")
            quit(1)
            return false
        print("PASS: blue gel LOD detail=8192 eco=", eco_triangles,
            " triangles; optical coat stays geometrically matched")
    if ticks == 117:
        _capture("04-two-gels-compression.png")
    if ticks == 125:
        if float(stage.gel_material.get_shader_parameter(
                "volume_conservation")) < 0.85 or \
                float(stage.upper_paint.get_shader_parameter(
                "volume_conservation")) < 0.85 or \
                float((stage.upper_coat.material_override as ShaderMaterial
                ).get_shader_parameter("volume_conservation")) < 0.85:
            push_error("Gel volume restoration is not enabled in both shaders")
            quit(1)
            return false
        # Compare the exact same numerical spring at different DISPLAY
        # strengths: the model's physical state must not change.
        stage.preview_elastic_sample(0.09)
        var physics_red: float = stage.elastic_pair.red
        var original_visual: float = float(
            stage.gel_material.get_shader_parameter("deformation"))
        stage.force_slider.value = 2.1
        if absf(stage.visual_gain - 2.1) > 0.001 or \
                not stage.force_readout.text.contains("210%") or \
                float(stage.gel_material.get_shader_parameter(
                    "deformation")) <= original_visual + 0.02 or \
                absf(physics_red - float(stage.elastic_pair.red)) > 0.0001:
            push_error("Strength slider changed spring energy or failed to flex gel")
            quit(1)
            return false
        stage.force_slider.value = 1.9
        stage.preview_elastic_sample(0.09)
        if stage.elastic_pair.red < 0.22 or \
                stage.elastic_pair.blue < 0.16 or \
                float(stage.gel_material.get_shader_parameter(
                    "deformation")) < 0.42 or \
                float(stage.upper_paint.get_shader_parameter(
                    "deformation")) < 0.32:
            push_error("v10 squash is still too rigid at measured contact")
            quit(1)
            return false
        var wave: float = float(stage.gel_material.get_shader_parameter(
            "impact_local_energy"))
        var coat_wave: float = float(
            (stage.wet_coat.material_override as ShaderMaterial
            ).get_shader_parameter("impact_local_energy"))
        var blue_wave: float = float(stage.upper_paint.get_shader_parameter(
            "impact_local_energy"))
        var blue_coat_wave: float = float(
            stage.upper_coat_paint.get_shader_parameter(
                "impact_local_energy"))
        if wave < 0.3 or blue_wave < 0.3 or \
                absf(wave - coat_wave) > 0.0001 or \
                absf(blue_wave - blue_coat_wave) > 0.0001:
            push_error("Interface wave missing or detached from wet coat")
            quit(1)
            return false
    if ticks == 132:
        _capture("05-coupled-impact.png")
    if ticks == 140:
        stage.preview_elastic_sample(0.26)
        if stage.elastic_pair.red > -0.10 or \
                stage.elastic_pair.blue > -0.028:
            push_error("The timed elastic rebound is not negative")
            quit(1)
            return false
        var red_mat: ShaderMaterial = stage.gel_material
        var red_coat := stage.wet_coat.material_override as ShaderMaterial
        var blue_mat: ShaderMaterial = stage.upper_paint
        var blue_coat := stage.upper_coat.material_override as ShaderMaterial
        if absf(float(red_mat.get_shader_parameter("deformation")) -
                float(red_coat.get_shader_parameter("deformation"))) > 0.0001 or \
                absf(float(blue_mat.get_shader_parameter("deformation")) -
                float(blue_coat.get_shader_parameter("deformation"))) > 0.0001:
            push_error("Optical coat detached from viscoelastic spring shape")
            quit(1)
            return false
    if ticks == 148:
        _capture("06-coupled-rebound.png")
    if ticks == 156:
        stage.preview_elastic_sample(2.65)
        if absf(stage.elastic_pair.red) > 0.010 or \
                absf(stage.elastic_pair.blue) > 0.010 or \
                float(stage.gel_material.get_shader_parameter(
                    "impact_local_energy")) > 0.001 or \
                float(stage.upper_paint.get_shader_parameter(
                    "impact_local_energy")) > 0.001:
            push_error("Gel wave persisted after the real spring settled")
            quit(1)
            return false
    if ticks == 162:
        _capture("07-coupled-settled.png")
    if ticks == 170:
        # Unlike the stable photographic captures, the Android button must
        # also really start a NEW continuous spring simulation.
        stage.impact_button.pressed.emit()
        if not stage.motion_active or not stage.elastic_pair.active:
            push_error("Android CHOC GEL button did not start live animation")
            quit(1)
            return false
    if ticks == 177:
        var before: int = stage.elastic_pair.impact_count
        stage.impact_button.pressed.emit()
        if stage.elastic_pair.impact_count != before + 1 or \
                stage.elastic_pair.simulation_time <= 0.0 or \
                stage.last_impact_time <= 0.0:
            push_error("Repeated taps must ADD impulse, not reset the scene")
            quit(1)
            return false
        print("PASS: repeated Android CHOC GEL adds another physical impulse")
    if ticks >= 185:
        if stage.elastic_pair.peak_red_compression < 0.22 or \
                stage.elastic_pair.peak_blue_compression < 0.18 or \
                stage.peak_live_lag < 0.03:
            push_error("Touch-triggered gel dynamics did not actually animate")
            quit(1)
            return false
        if shots != 7:
            push_error("Incomplete seven-stage genuine GPU and spring proof")
            quit(1)
            return false
        print("PASS: live and deterministic coupled gel red=",
            stage.elastic_pair.peak_red_compression,
            " blue=", stage.elastic_pair.peak_blue_compression,
            " visible_red=", stage.peak_visual_red,
            " visible_blue=", stage.peak_visual_blue,
            " inertial lag=", stage.peak_live_lag)
        # The user can exit an elastic animation through REPOS, IMPACT
        # or REBOND. Ensure the old shock never remains stuck on the gel.
        stage.sample_reference("rest")
        if stage.motion_active or \
                float(stage.gel_material.get_shader_parameter(
                    "impact_local_energy")) > 0.0001 or \
                float(stage.upper_paint.get_shader_parameter(
                    "impact_local_energy")) > 0.0001 or \
                absf(stage.upper_studs.scale.y - 1.0) > 0.0001 or \
                stage.peak_visual_red != 0.0 or \
                stage.peak_visual_blue != 0.0:
            push_error("Manual REPOS did not reset waves, studs and solver")
            quit(1)
            return false
        print("PASS: manual pose clears local waves and molded stud distortion")
        print("PASS: real multilayer optics and 3 individually sampled ",
            "elastic GPU frames (impact/rebound/rest)")
        quit()
    return false
