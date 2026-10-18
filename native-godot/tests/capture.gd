extends SceneTree

## Captures the REAL Godot Compatibility renderer, not an HTML mockup.
## Intended for a virtual X display and Mesa's software OpenGL renderer.
var frames: int = 0
var game: Node = null
# Lock the reference product camera between the two animation frames.
# Otherwise the slow Mesa renderer can rotate by ~90 degrees between them,
# obscuring the extremely subtle (and intentional) real Jelly sway.
var locked_reference_angle: float = 0.0

func _process(_delta: float) -> bool:
    if frames == 0:
        var packed: PackedScene = load("res://scenes/main.tscn")
        if packed == null:
            push_error("Cannot load the native preview scene")
            quit(1)
            return false
        game = packed.instantiate()
        root.add_child(game)
        # Run every level, even when a previous test left fewer unlocked.
        game.unlocked = game.levels.size() - 1
        # The logic tests run against Godot's dummy RenderingServer, which
        # returns identity/zero from MultiMesh buffer readback. Under Mesa's
        # real OpenGL driver verify every stage's actual GPU-side instance
        # coordinates and candy colors BEFORE taking the visual screenshot.
        for level_index in range(game.levels.size()):
            game._open_level(level_index)
            var floor: MultiMeshInstance3D = null
            var targets: MultiMeshInstance3D = null
            for child in game.board.get_children():
                if child is MultiMeshInstance3D and not child.is_queued_for_deletion():
                    if child.name == "FloorBatch":
                        floor = child
                    elif child.name == "TargetBatch":
                        targets = child
            if floor == null or targets == null \
                    or floor.multimesh.instance_count != game.size * game.size \
                    or targets.multimesh.instance_count != game.wanted.size():
                push_error("OpenGL QA: wrong GPU stage instance count at level " + str(level_index))
                quit(1)
                return false
            var marked: int = 0
            for row in range(game.size):
                for col in range(game.size):
                    var idx: int = row * game.size + col
                    var expected := Vector3(col + .5 - game.size / 2.0,
                        .022, row + .5 - game.size / 2.0)
                    var actual: Vector3 = floor.multimesh.get_instance_transform(idx).origin
                    if actual.distance_to(expected) > .001:
                        push_error("OpenGL QA: floor cell moved " + str(Vector2i(row, col)) +
                            ": " + str(actual) + " != " + str(expected))
                        quit(1)
                        return false
                    var cell := Vector2i(row, col)
                    var expected_tint := Color("#edf0f5")
                    if game.wanted.has(cell):
                        expected_tint = Color(game.PALETTE[game.wanted[cell]]).lerp(Color.WHITE, .59)
                    var actual_tint: Color = floor.multimesh.get_instance_color(idx)
                    if absf(actual_tint.r - expected_tint.r) > .02 \
                            or absf(actual_tint.g - expected_tint.g) > .02 \
                            or absf(actual_tint.b - expected_tint.b) > .02:
                        push_error("OpenGL QA: floor candy color changed at " + str(cell))
                        quit(1)
                        return false
                    if game.wanted.has(cell):
                        var marker_at: Vector3 = targets.multimesh.get_instance_transform(
                            marked).origin
                        if marker_at.distance_to(expected + Vector3(0, .025, 0)) > .001:
                            push_error("OpenGL QA: target marker moved at " + str(cell))
                            quit(1)
                            return false
                        var mark_color := Color(game.PALETTE[game.wanted[cell]]).lerp(Color.WHITE, .18)
                        var actual_mark: Color = targets.multimesh.get_instance_color(marked)
                        if absf(actual_mark.r - mark_color.r) > .02 \
                                or absf(actual_mark.g - mark_color.g) > .02 \
                                or absf(actual_mark.b - mark_color.b) > .02:
                            push_error("OpenGL QA: target marker color changed at " + str(cell))
                            quit(1)
                            return false
                        marked += 1
        print("PASS: Mesa OpenGL 3D instancing verified for all 21 colored puzzle grids")
        # Render an unfinished interactive scene regardless of progress
        # from a preceding headless test in the same GitHub runner.
        game.saved_sessions.clear()
        game.resume_session.clear()
        game._open_level(0)
        game._try_place("A", Vector2i(0, 1))
        game._try_place("B", Vector2i(1, 0))
    frames += 1
    # Software OpenGL frame times vary greatly between runners. Leaving
    # Gallery auto-orbit enabled during a screenshot makes before/after
    # comparisons misleading: changes in camera angle overpower the optics.
    # Pin only the QA camera, not the live product animation or gameplay.
    if frames > 145 and frames <= 265 and game.stack_studio.photo_mode:
        game.stack_studio.photo_angle = 0.34 \
            if game.stack_studio.gallery_demo_active else 0.28
        game.stack_studio._update_photo_camera()
    if frames == 64:
        # Check the *real Mesa GPU* MultiMesh buffer. Headless Godot tests
        # cannot reliably read instance transforms/colors on the dummy
        # RenderingServer, so this must run in the OpenGL visual pipeline.
        var projection: MultiMesh = game.stack_studio.caustic_batch.multimesh
        if projection.instance_count != 3:
            push_error("OpenGL QA: ground Jelly lost its three pooled caustics")
            quit(1)
            return false
        for i in range(3):
            var expected_color := Color(
                game.stack_studio.COLORS[[0, 2, 4][i]]).lerp(Color.WHITE, .12)
            var measured_color: Color = projection.get_instance_color(i)
            var origin: Vector3 = projection.get_instance_transform(i).origin
            if origin.y < -.300 or origin.y > -.285 \
                    or absf(measured_color.r - expected_color.r) > .02 \
                    or absf(measured_color.g - expected_color.g) > .02 \
                    or absf(measured_color.b - expected_color.b) > .02:
                push_error("OpenGL QA: colored studio caustic is not grounded correctly")
                quit(1)
                return false
        print("PASS: Real OpenGL GPU light transmission: 3 pigmented ground instances")
        # On REAL Mesa OpenGL the first three-cell brick must have six
        # low-profile studs in two lanes, not twelve inflated bumps.
        # Check actual GPU transforms: position must rotate with the bar.
        var studio_studs: MultiMesh = game.stack_studio.brick_nodes[0].get_node(
            "GelStuds").multimesh
        if studio_studs.instance_count != 6 \
                or studio_studs.mesh != game.stack_studio.studio_stud_mesh \
                or studio_studs.mesh == game.stud_mesh:
            push_error("OpenGL QA: no GPU-instanced, flat studio tenons")
            quit(1)
            return false
        var first_stud_pos: Vector3 = studio_studs.get_instance_transform(0).origin
        if first_stud_pos.distance_to(Vector3(.5, 0, .265)) > .003:
            push_error("OpenGL QA: first molded stud was not positioned correctly")
            quit(1)
            return false
        print("PASS: Mesa OpenGL reference two-lane stud buffer and flat-cap mesh")
    # Compare the same material in three physical product-camera views.
    if frames != 30 and frames != 65 and frames != 100 \
            and frames != 135 and frames != 145 and frames != 185 \
            and frames != 225 and frames != 265:
        return false
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Native 3D screenshot has no pixels")
        quit(1)
        return false
    image.resize(540, 960, Image.INTERPOLATE_LANCZOS)
    if frames == 185:
        # A renderer can report shadows enabled yet produce a white-out
        # gallery with no actual grounding. Inspect REAL Mesa OpenGL pixels,
        # choosing floor samples below the known six-brick showcase.
        # Relative brightness avoids depending on a particular LCD gamma.
        var white_background: float = image.get_pixel(270, 850).get_luminance()
        var darkest_neutral_floor: float = 1.0
        # A lower or orbiting product camera changes the shadow's screen
        # coordinates. Search the actual floor across the bottom half
        # instead of falsely requiring a shadow at one hard-coded pixel.
        # Discard colored bricks by requiring nearly neutral RGB, and
        # disregard dark UI/geometry by requiring a bright floor sample.
        for yy in range(545, 850, 10):
            for xx in range(70, 470, 10):
                var floor_pixel: Color = image.get_pixel(xx, yy)
                if floor_pixel.r > .52 and floor_pixel.g > .52 \
                        and floor_pixel.b > .52 \
                        and absf(floor_pixel.r - floor_pixel.g) < .14 \
                        and absf(floor_pixel.g - floor_pixel.b) < .14:
                    darkest_neutral_floor = minf(darkest_neutral_floor,
                        floor_pixel.get_luminance())
        if white_background - darkest_neutral_floor < .025:
            push_error("Real gallery QA has no visible soft ground contact: %.3f" % (
                white_background - darkest_neutral_floor))
            quit(1)
            return false
        print("PASS: OpenGL studio floor has visible shadow (luminance drop %.3f)" % (
            white_background - darkest_neutral_floor))
    # Capture each mode to its OWN output exactly once. Otherwise the
    # second frame overwrites the puzzle PNG and disguises screenshot drift.
    var file_name := ""
    match frames:
        30:
            file_name = "jelly-native-preview.png"
        65:
            file_name = "jelly-stack-preview.png"
        100:
            file_name = "jelly-stack-side-preview.png"
        135:
            file_name = "jelly-stack-top-preview.png"
        145:
            file_name = "jelly-stack-impact-preview.png"
        185:
            file_name = "jelly-stack-gallery-preview.png"
        225:
            file_name = "jelly-stack-reference-tower-preview.png"
        265:
            file_name = "jelly-stack-reference-sway-preview.png"
    var output := ProjectSettings.globalize_path(
        "res://../build/" + file_name)
    var result := image.save_png(output)
    if result != OK:
        push_error("Screenshot PNG writing failed: " + str(result))
        quit(1)
        return false
    if frames == 30:
        print("PASS: Native 3D Jelly Bricks rendering screenshot: ", output)
        game._enter_stack_mode()
        # QA must show the intended stacked sculpture even if the headless
        # test runner left behind an empty user:// studio save.
        game.stack_studio._seed_showcase()
        game.stack_studio._rebuild()
        if game.stack_studio.bricks.size() != 6:
            push_error("Studio QA has no representative vertical sculpture")
            quit(1)
            return false
        if not game.stack_mode_active or not game.stack_studio.active:
            push_error("Native visual QA cannot enter the actual stacking studio")
            quit(1)
            return false
        return false
    print("PASS: Real OpenGL stacking studio capture from preset %d: %s" % [
        game.stack_studio.camera_mode, output])
    if frames == 65 or frames == 100:
        game.stack_studio._cycle_camera()
        return false
    if frames == 135:
        # A fifth actual OpenGL frame freezes the live vertex spring, not a
        # static mockup. Keep the photographed product angle.
        game.stack_studio._cycle_camera()
        game.stack_studio.selected_cell = Vector2i(2, 2)
        game.stack_studio.selected_length = 0
        game.stack_studio._commit()
        if game.stack_studio.bricks.size() != 7:
            push_error("QA landing snapshot failed to place a real seventh brick")
            quit(1)
            return false
        return false
    if frames == 145:
        print("PASS: Studio physical-gel impact captured from live Godot shader")
        game.stack_studio._enter_photo_mode()
        if not game.stack_studio.photo_mode or game.stack_studio.hud.visible:
            push_error("Premium gallery did not hide edit controls in OpenGL render")
            quit(1)
            return false
        return false
    if frames == 185:
        print("PASS: Studio cinematic Jelly photo gallery screenshot: ", output)
        # The seventh OpenGL screenshot is a true 3D construction with
        # nine supported layers, not a pre-render or a modified user save.
        game.stack_studio._toggle_gallery_demo()
        if not game.stack_studio.gallery_demo_active \
                or game.stack_studio.gallery_demo_nodes.size() != 12 \
                or game.stack_studio.caustic_batch.multimesh.instance_count != 4:
            push_error("Reference photo did not build the genuine vertical studio demo")
            quit(1)
            return false
        return false
    if not game.stack_studio.gallery_demo_active:
        push_error("The gallery demo was deactivated before its OpenGL screenshot")
        quit(1)
        return false
    if frames == 225:
        # Protect the USER'S brightly pigmented candy reference. A Godot
        # Compatibility CLEARCOAT experiment rendered every 3D Jelly
        # piece opaque grey while all scene and solver tests still passed.
        # Count REAL screenshot pixels, not material parameters: the core
        # of the nine-layer color tower must remain vividly dyed. The
        # rectangle excludes UI chrome and low floor caustics.
        var colored_tower_samples: int = 0
        for py in range(280, 585, 8):
            for px in range(160, 445, 8):
                var candy_pixel: Color = image.get_pixel(px, py)
                var chroma: float = maxf(candy_pixel.r,
                    maxf(candy_pixel.g, candy_pixel.b)) - minf(
                    candy_pixel.r, minf(candy_pixel.g, candy_pixel.b))
                if chroma > .20 and maxf(candy_pixel.r,
                        maxf(candy_pixel.g, candy_pixel.b)) > .47:
                    colored_tower_samples += 1
        if colored_tower_samples < 250:
            push_error("Reference Jelly became gray/desaturated in real OpenGL: %d dyed pixels" %
                colored_tower_samples)
            quit(1)
            return false
        print("PASS: Reference Jelly remains saturated in %d real OpenGL photo samples" %
            colored_tower_samples)
        # Real visual QA: every foreground Jelly brick must fit the
        # portrait photo. The yellow piece used to be cut in half at x=0
        # after the tighter interlocking step made auto-framing zoom in.
        for py in range(300, 820, 12):
            for px in range(0, 8, 2):
                var border_pixel: Color = image.get_pixel(px, py)
                var color_range: float = maxf(border_pixel.r,
                    maxf(border_pixel.g, border_pixel.b)) - minf(
                    border_pixel.r, minf(border_pixel.g, border_pixel.b))
                if color_range > .24:
                    push_error("Gallery photo clips a colorful foreground brick at the left edge")
                    quit(1)
                    return false
        print("PASS: All foreground Jelly bricks fit inside portrait camera borders")
        # Keep the same real nine-level showcase alive for another 40 frames.
        # Fix only the camera pose: the tower itself keeps moving with the
        # normal Godot _process() and analytical spring motion.
        locked_reference_angle = game.stack_studio.photo_angle
        print("PASS: Real nine-floor Jelly tower showcase: ", output)
        return false
    if absf(game.stack_studio.photo_angle - locked_reference_angle) > .0001:
        push_error("OpenGL sway QA changed camera angle between comparison frames")
        quit(1)
        return false
    if game.stack_studio.gallery_sway_time <= 0.5:
        push_error("Animated reference tower did not advance in real OpenGL time")
        quit(1)
        return false
    print("PASS: Real OpenGL nine-floor Jelly sway photograph: ", output)
    quit(0)
    return false
