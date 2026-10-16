extends SceneTree
const GEL_MESH = preload("res://scripts/gel_mesh.gd")

## Headless native engine test: all 21 original layouts, one fully interactive
## level, remaining solutions placed in one batch to avoid expensive no-GPU CI.
var has_started: bool = false

func _process(_delta: float) -> bool:
    if has_started:
        return false
    has_started = true
    print("TEST: initializing Jelly Bricks Godot scene")
    _run()
    return false

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("Main native scene failed loading")
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    if game.levels.size() != 21:
        push_error("The 21 authored levels were not imported")
        quit(1)
        return
    if game.background.visible and game.background.color.a > 0.05:
        push_error("Opaque CanvasLayer background hides the entire 3D game")
        quit(1)
        return
    # Validate rounded contour skin before exercising the existing gameplay.
    var ring_cells: Array = []
    for row in range(3):
        for col in range(3):
            if row != 1 or col != 1:
                ring_cells.append(Vector2i(row, col))
    if GEL_MESH._contours(ring_cells).size() != 2:
        push_error("Continuous jelly body lost an enclosed hole")
        quit(1)
        return
    if GEL_MESH._contours([Vector2i(0, 0), Vector2i(1, 1)]).size() != 2:
        push_error("Diagonally touching gel islands must not be joined")
        quit(1)
        return
    var round_mesh: ArrayMesh = GEL_MESH.build(ring_cells)
    if round_mesh == null or round_mesh.get_surface_count() != 1:
        push_error("Continuous candy skin did not produce a 3D surface")
        quit(1)
        return
    var surface: Array = round_mesh.surface_get_arrays(0)
    var positions: PackedVector3Array = surface[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = surface[Mesh.ARRAY_NORMAL]
    if positions.size() < 80 or normals.size() != positions.size():
        push_error("Rounded candy bevel rings or normals are missing")
        quit(1)
        return
    for normal in normals:
        if not normal.is_finite() or absf(normal.length() - 1.0) > .015:
            push_error("Native gel surface has invalid or non-unit normals")
            quit(1)
            return
    if round_mesh.get_aabb().size.y < .37:
        push_error("Jelly volume has lost its pillowy top or thick rounded sides")
        quit(1)
        return
    print("TEST: smooth rounded jelly rings, holes and proper 3D thickness")
    print("TEST: native scene created successfully; verifying each puzzle")
    game.unlocked = 20
    var solved := 0
    for level_index in range(game.levels.size()):
        game._open_level(level_index)
        var level: Dictionary = game.levels[level_index]
        var rows: Array = level["rows"]
        var expected_count := 0
        var poses := {}
        for id_variant in game.pieces.keys():
            var id := String(id_variant)
            var origin := Vector2i(game.size, game.size)
            for r in range(game.size):
                for c in range(game.size):
                    if String(rows[r]).substr(c, 1) == id:
                        origin.x = mini(origin.x, r)
                        origin.y = mini(origin.y, c)
                        expected_count += 1
            if not game._can_place(id, origin, 0):
                push_error("Native level validation failed at " + str(level_index)
                    + " piece " + id)
                quit(1)
                return
            poses[id] = {"row": origin.x, "col": origin.y, "turns": 0}
        if level_index == 0:
            var ids: Array = game.pieces.keys()
            ids.sort()
            var first_id := String(ids[0])
            var first_pose: Dictionary = poses[first_id]
            var first_position := Vector2i(int(first_pose["row"]), int(first_pose["col"]))
            # Geometrically fitting is NOT the same as matching the color
            # reference. The old green ghost lied about wrong placements.
            var wrong_position := Vector2i(1, 0)
            if not game._can_place(first_id, wrong_position, 0) \
                    or game._matches_model(first_id, wrong_position, 0) \
                    or not game._matches_model(first_id, first_position, 0):
                push_error("Model matching cannot distinguish wrong and right shape")
                quit(1)
                return
            if not game._preview_tint(first_id, wrong_position, 0).is_equal_approx(Color("#ffc46a")):
                push_error("Wrong but possible placement should show amber, not mint")
                quit(1)
                return
            if not game._preview_tint(first_id, first_position, 0).is_equal_approx(Color("#76ffd4")):
                push_error("Correct model match is not highlighted mint")
                quit(1)
                return
            if not game._preview_tint(first_id, Vector2i(-3, -3), 0).is_equal_approx(Color("#ff537e")):
                push_error("Impossible placement has no danger tint")
                quit(1)
                return
            game._try_place(first_id, wrong_position)
            if game.placements.size() != 1 or not game.status_label.text.contains("différent du modèle"):
                push_error("Incorrect geometry match did not warn the player")
                quit(1)
                return
            game._undo()
            if not game.placements.is_empty():
                push_error("Undo failed after an incorrect color placement")
                quit(1)
                return
            # Stage squares must share resources. No per-cell duplicate GPU
            # meshes and materials when drawing seven-by-seven candy boards.
            var duplicate_a = game._box_mesh(Vector3(.936, .016, .936), Color("#101e37"), .55)
            var duplicate_b = game._box_mesh(Vector3(.936, .016, .936), Color("#101e37"), .55)
            if duplicate_a.mesh != duplicate_b.mesh \
                    or duplicate_a.material_override != duplicate_b.material_override:
                push_error("Native stage resources are allocated anew per cell")
                quit(1)
                return
            duplicate_a.free()
            duplicate_b.free()
            # Regression: the first piece must be undoable, even when the
            # previous snapshot was the EMPTY board.
            game._try_place(first_id, first_position)
            if game.placements.size() != 1 or not game.has_undo_snapshot:
                push_error("First-placement undo snapshot is unavailable")
                quit(1)
                return
            game._undo()
            if not game.placements.is_empty() or game.has_undo_snapshot:
                push_error("Undo did not restore the completely empty board")
                quit(1)
                return
            # A reusable volume mesh should be shared by copies of the
            # same rotated shape, including the placement ghost.
            var preview_a = game._piece_node(first_id, game.pieces[first_id],
                first_position, 0, false)
            var preview_b = game._piece_node(first_id, game.pieces[first_id],
                first_position, 0, true)
            if preview_a.get_child(0).mesh != preview_b.get_child(0).mesh:
                push_error("Duplicate native jelly meshes are still generated")
                quit(1)
                return
            var gel_mesh: ArrayMesh = preview_a.get_child(0).mesh
            if gel_mesh.get_aabb().size.y < .40:
                push_error("Jelly volumes have lost their 3D depth")
                quit(1)
                return
            var gel_arrays: Array = gel_mesh.surface_get_arrays(0)
            var gel_vertices: PackedVector3Array = gel_arrays[Mesh.ARRAY_VERTEX]
            var gel_indices: PackedInt32Array = gel_arrays[Mesh.ARRAY_INDEX]
            # Godot now indexes shared vertices to save GPU memory. Triangle
            # index count, not duplicate-vertex count, measures bevel detail.
            var triangle_vertices := gel_indices.size() if not gel_indices.is_empty() else gel_vertices.size()
            if triangle_vertices <= game.pieces[first_id].size() * 30:
                push_error("Rounded jelly bevel triangles are missing from the mesh")
                quit(1)
                return
            var ghost_mat: ShaderMaterial = preview_b.get_child(0).material_override
            if float(ghost_mat.get_shader_parameter("gel_opacity")) >= .6:
                push_error("Preview jelly is not translucent")
                quit(1)
                return
            preview_a.free()
            preview_b.free()
            var first_button: Button = game.tray.get_child(0)
            var thumbnail: Control = first_button.get_node("ShapeThumbnail")
            if thumbnail.get_child_count() != game.pieces[first_id].size() + 1:
                push_error("Native piece tray does not display the real shape")
                quit(1)
                return
            # Regression: a hint must not place pieces on behalf of the player.
            game._show_hint()
            if game.selected_id != first_id or not game.placements.is_empty() \
                    or game.ghost.get_child_count() != 1:
                push_error("Hint failed to reveal an unplaced shape safely")
                quit(1)
                return
            var first_ghost: Node3D = game.ghost.get_child(0)
            if not first_ghost.visible or game._snap_placement(first_id, first_position, 0) != first_position:
                push_error("Hint preview or magnetic snap has incorrect position")
                quit(1)
                return
            game._draw_preview(first_position + Vector2i(1, 0))
            if game.ghost.get_child_count() != 1 or game.ghost.get_child(0) != first_ghost:
                push_error("Dragging still recreates the jelly ghost every frame")
                quit(1)
                return
            game._draw_preview(Vector2i(-1, -1))
            if first_ghost.visible:
                push_error("Touch release failed to hide jelly ghost")
                quit(1)
                return

            # Multiple moves must be undoable, including the empty board.
            game._try_place(first_id, first_position)
            var second_id := String(ids[1])
            var second_pose: Dictionary = poses[second_id]
            game._try_place(second_id, Vector2i(int(second_pose["row"]),
                int(second_pose["col"])))
            if game.placements.size() != 2 or game.undo_history.size() != 2:
                push_error("Multi-move undo stack or placement is broken")
                quit(1)
                return
            game._undo()
            if game.placements.size() != 1 or not game.has_undo_snapshot:
                push_error("Undo did not restore the previous move")
                quit(1)
                return
            game._undo()
            if not game.placements.is_empty() or game.has_undo_snapshot:
                push_error("Multi-undo did not recover the empty starting board")
                quit(1)
                return
            print("TEST: stage GPU sharing, truthful previews, wrong-placement feedback,")
            print("TEST: first undo, reusable ghost, hint, multi-undo and rounded shape previews")
            for variant in ids:
                var id := String(variant)
                var pose: Dictionary = poses[id]
                game._try_place(id, Vector2i(int(pose["row"]), int(pose["col"])))
        else:
            game.placements = poses
            game._rebuild_placements()
            game._check_win()
        if not game.completed or game.wanted.size() != expected_count:
            push_error("Native puzzle solution failed at " + str(level_index))
            quit(1)
            return
        solved += 1
        print("TEST: solved level ", solved, "/21")
    print("PASS: real Godot 4.6 loads native game and solves all ", solved,
        " levels; touch-equivalent actions solve the first.")
    quit(0)
