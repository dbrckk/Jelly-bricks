extends SceneTree

## Captures the REAL Godot Compatibility renderer, not an HTML mockup.
## Intended for a virtual X display and Mesa's software OpenGL renderer.
var frames: int = 0
var game: Node = null

func _process(_delta: float) -> bool:
    if frames == 0:
        var packed: PackedScene = load("res://scenes/main.tscn")
        if packed == null:
            push_error("Cannot load the native preview scene")
            quit(1)
            return false
        game = packed.instantiate()
        root.add_child(game)
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
                    var expected_tint := Color("#101e37")
                    if game.wanted.has(cell):
                        expected_tint = Color(game.PALETTE[game.wanted[cell]]).darkened(.68)
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
                        var mark_color := Color(game.PALETTE[game.wanted[cell]]).darkened(.24)
                        var actual_mark: Color = targets.multimesh.get_instance_color(marked)
                        if absf(actual_mark.r - mark_color.r) > .02 \
                                or absf(actual_mark.g - mark_color.g) > .02 \
                                or absf(actual_mark.b - mark_color.b) > .02:
                            push_error("OpenGL QA: target marker color changed at " + str(cell))
                            quit(1)
                            return false
                        marked += 1
        print("PASS: Mesa OpenGL 3D instancing verified for all 21 colored puzzle grids")
        # Capture a real interactive scene with visible volumetric jelly,
        # not the flat empty board left by the preceding level tests.
        game._open_level(0)
        game._try_place("A", Vector2i(0, 1))
        game._try_place("B", Vector2i(1, 0))
    frames += 1
    if frames < 30:
        return false
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Native 3D screenshot has no pixels")
        quit(1)
        return false
    image.resize(540, 960, Image.INTERPOLATE_LANCZOS)
    var output := ProjectSettings.globalize_path(
        "res://../build/jelly-native-preview.png")
    var result := image.save_png(output)
    if result != OK:
        push_error("Screenshot PNG writing failed: " + str(result))
        quit(1)
        return false
    print("PASS: Native 3D Jelly Bricks rendering screenshot: ", output)
    quit(0)
    return false
