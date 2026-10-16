extends SceneTree
const GEL_MESH = preload("res://scripts/gel_mesh.gd")
const CANDY_AUDIO = preload("res://scripts/candy_audio.gd")
const SAVE_TRANSFER = preload("res://scripts/save_transfer.gd")

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
    # The optional studio must NOT interfere with the puzzle on launch.
    var studio: Node3D = game.stack_studio
    if studio == null or game.stack_mode_active or studio.active \
            or studio.hud.visible or not game.overlay.visible or not game.board.visible:
        push_error("Stacking studio has hijacked the classic puzzle startup")
        quit(1)
        return
    if studio.bricks.size() != 6 or studio.get_node_or_null("CandyStackStage") == null:
        push_error("Stack studio has no first-play sample or real 3D stage")
        quit(1)
        return
    # The short yellow brick is on top of the long coral brick.
    var atop: Dictionary = studio._drop_candidate(2, 2, 0, 0)
    if not atop.get("ok", false) or int(atop["layer"]) != 3:
        push_error("Stack support does not resolve a stable third layer")
        quit(1)
        return
    if studio._drop_candidate(-1, 2, 2, 0).get("ok", true) \
            or studio._drop_candidate(2, 5, 2, 0).get("ok", true):
        push_error("Stack lets a dragged brick float beyond its base")
        quit(1)
        return
    var old_camera: Transform3D = game.camera.transform
    var old_size: float = game.camera.size
    game._enter_stack_mode()
    if not game.stack_mode_active or not studio.active or not studio.hud.visible \
            or game.overlay.visible or game.board.visible:
        push_error("Stack studio cannot be entered from the running puzzle")
        quit(1)
        return
    var finger_first := InputEventScreenTouch.new()
    finger_first.pressed = true
    finger_first.index = 5
    finger_first.position = Vector2(360, 540)
    studio.handle_input(finger_first)
    if studio.active_touch_index != 5:
        push_error("Stack touch cannot capture the first mobile finger")
        quit(1)
        return
    var finger_second := InputEventScreenTouch.new()
    finger_second.pressed = true
    finger_second.index = 6
    finger_second.position = Vector2(360, 540)
    studio.handle_input(finger_second)
    finger_second.pressed = false
    studio.handle_input(finger_second)
    if studio.active_touch_index != 5 or studio.bricks.size() != 6:
        push_error("Second finger hijacked or committed a stacking drag")
        quit(1)
        return
    finger_first.pressed = false
    finger_first.canceled = true
    studio.handle_input(finger_first)
    if studio.active_touch_index != -1 or studio.bricks.size() != 6:
        push_error("Cancelled mobile touch should not place a stack brick")
        quit(1)
        return
    studio._reset()
    if not studio.bricks.is_empty():
        push_error("Stack reset did not clear the standalone studio")
        quit(1)
        return
    studio.selected_cell = Vector2i(2, 2)
    studio.selected_length = 2
    studio._commit()
    if studio.bricks.size() != 1 or not studio.occupancy.has(Vector3i(2, 2, 0)):
        push_error("First stacked 3D brick was not placed on the plinth")
        quit(1)
        return
    studio.selected_length = 0
    studio._commit()
    if studio.bricks.size() != 2 or int(studio.bricks[1]["layer"]) != 1:
        push_error("Second brick did not snap onto the first")
        quit(1)
        return
    if studio._load_entries([{"row": -20, "col": 2, "length": 0,
            "turns": 0, "color": 0, "layer": 1}]):
        push_error("Stack save importer accepted out-of-bounds geometry")
        quit(1)
        return
    studio._reset()
    studio._commit()
    studio._undo()
    if not studio.bricks.is_empty():
        push_error("Stack undo failed after a new placement")
        quit(1)
        return
    game._leave_stack_mode()
    if studio.active or studio.hud.visible or game.stack_mode_active \
            or not game.board.visible or not game.overlay.visible \
            or game.camera.transform != old_camera or not is_equal_approx(game.camera.size, old_size):
        push_error("Leaving the studio did not restore the running puzzle")
        quit(1)
        return
    print("TEST: free 3D stacking, multi-layer support, pointer capture, undo, modes and save validation")
    if game.background.visible and game.background.color.a > 0.05:
        push_error("Opaque CanvasLayer background hides the entire 3D game")
        quit(1)
        return
    # Pure Godot PCM synthesis produces non-silent, correctly sized clips.
    # The voice pool and opt-out must work without any external file.
    if game.audio_voices.size() != 3 or game.audio_bank.size() != CANDY_AUDIO.EVENTS.size():
        push_error("Native candy feedback audio bank or polyphonic pool is missing")
        quit(1)
        return
    for event_name in CANDY_AUDIO.EVENTS:
        var sound: AudioStreamWAV = game.audio_bank[event_name]
        if sound == null or sound.format != AudioStreamWAV.FORMAT_16_BITS \
                or sound.mix_rate != CANDY_AUDIO.SAMPLE_RATE \
                or sound.stereo or sound.data.size() < 1200 \
                or sound.data.size() % 2 != 0:
            push_error("Invalid 16-bit PCM asset for: " + event_name)
            quit(1)
            return
        var audible := false
        for offset in range(100, mini(sound.data.size(), 1200), 2):
            if abs(sound.data.decode_s16(offset)) > 100:
                audible = true
                break
        if not audible:
            push_error("Synthetic feedback is silent: " + event_name)
            quit(1)
            return
    if game.feedback_button == null or game.feedback_button.text != "FX : ON":
        push_error("Native audio accessibility toggle is missing or mislabeled")
        quit(1)
        return
    game.feedback_enabled = false
    game._update_feedback_button()
    var cursor_before: int = game.audio_voice_cursor
    game._play_feedback("place")
    if game.audio_voice_cursor != cursor_before or game.feedback_button.text != "FX : OFF":
        push_error("Muted feedback still consumes audio voices")
        quit(1)
        return
    game.feedback_enabled = true
    game._update_feedback_button()
    game._play_feedback("place")
    if game.audio_voice_cursor != cursor_before + 1:
        push_error("Audio feedback does not play when enabled")
        quit(1)
        return
    print("TEST: synthesized PCM, pooled sounds and mutable sound/haptic setting")
    # New renderer polish is still bounded: a single reusable 3D effect
    # root and four low-count CPU particle emitters, not particle objects
    # created each time the user taps an Android screen.
    var fx: Node3D = game.candy_fx
    if fx == null or fx.name != "CandyEffects" \
            or fx.landing_emitters.size() != 3 or fx.get_child_count() != 4:
        push_error("Native 3D candy sparkle pool did not initialise")
        quit(1)
        return
    if fx.victory_emitter == null or fx.victory_emitter.amount > 40 \
            or fx.victory_emitter.amount < 25:
        push_error("Victory sparkles are missing or excessive for Android")
        quit(1)
        return
    var first_shared_mesh: Mesh = fx.landing_emitters[0].mesh
    for emitter in fx.landing_emitters:
        if emitter.amount != 12 or not emitter.one_shot \
                or emitter.fixed_fps != 30 or emitter.mesh != first_shared_mesh:
            push_error("Candy effects are not shared, bounded CPU particle bursts")
            quit(1)
            return
    var glint_mat: StandardMaterial3D = first_shared_mesh.material
    if glint_mat == null or not glint_mat.vertex_color_use_as_albedo:
        push_error("Candy particle tints and alpha fade are invisible")
        quit(1)
        return
    fx.landing(Vector3.ZERO, Color("#ff537f"), true)
    fx.landing(Vector3.ONE, Color("#51e9c2"), false)
    if fx.landing_cursor != 2 or fx.landing_emitters[1].position.x < 1.0:
        push_error("The pooled landing emitters failed to advance and move")
        quit(1)
        return
    fx.victory()
    fx.reset()
    if fx.landing_cursor != 0 or fx.victory_emitter.emitting:
        push_error("Changing levels fails to stop the prior candy celebration")
        quit(1)
        return
    print("TEST: original compatibility CPU glints share one mesh; four emitters bounded")
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
    # Product-quality LEGO-like gel studs are smooth bevelled 3D bodies,
    # created once and instanced rather than one mesh node per stud.
    var stud_surface: ArrayMesh = GEL_MESH.build_stud()
    if stud_surface == null or stud_surface.get_surface_count() != 1:
        push_error("Premium jelly stud has no generated 3D surface")
        quit(1)
        return
    var stud_vertices: PackedVector3Array = stud_surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var stud_normals: PackedVector3Array = stud_surface.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    # The stud uses indexed triangles: ~70 distinct vertices draw >300
    # triangle indices. Duplicated triangle vertices are not a quality metric.
    var stud_indices: PackedInt32Array = stud_surface.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
    if stud_vertices.size() < 55 or stud_indices.size() < 300 \
            or stud_normals.size() != stud_vertices.size():
        push_error("Jelly stud bevel triangles or smooth normals are missing")
        quit(1)
        return
    var stud_bounds: AABB = stud_surface.get_aabb()
    if stud_bounds.size.y < .18 or stud_bounds.size.y > .24 \
            or stud_bounds.size.x < .26 or stud_bounds.size.x > .33:
        push_error("Jelly stud dimensions are not premium/proportional")
        quit(1)
        return
    var measured_normal_variation: bool = false
    for normal in stud_normals:
        if not normal.is_finite() or absf(normal.length() - 1.0) > .015:
            push_error("The stud normals are not unit-length or valid")
            quit(1)
            return
        if normal.y > .2 and normal.y < .85:
            measured_normal_variation = true
    if not measured_normal_variation:
        push_error("Jelly stud rim has no smooth bevel")
        quit(1)
        return
    if game.stud_mesh == null or game.stud_mesh.get_surface_count() != 1 \
            or game.contact_shadow_material == null \
            or game.contact_shadow_material.shader == null:
        push_error("Premium soft stud / fake shadow GPU resources are missing")
        quit(1)
        return
    print("TEST: premium shared beveled jelly studs and soft studio contact shadows")
    print("TEST: smooth rounded jelly rings, holes and proper 3D thickness")
    print("TEST: native scene created successfully; verifying each puzzle")
    game.unlocked = 20
    var solved := 0
    for level_index in range(game.levels.size()):
        game._open_level(level_index)
        # GPU batching regression: on the largest 7x7 board 49 colored
        # squares + as many target marks must submit only TWO static
        # instanced draws, never 98 separate MeshInstance3D draw objects.
        var batches: Dictionary = {}
        var static_meshes: int = 0
        for child in game.board.get_children():
            if child.is_queued_for_deletion():
                continue
            if child is MultiMeshInstance3D:
                batches[child.name] = child
            elif child is MeshInstance3D:
                static_meshes += 1
        if batches.size() != 2 or not batches.has("FloorBatch") \
                or not batches.has("TargetBatch") or static_meshes > 7:
            push_error("Stage no longer uses two GPU batches and at most seven frame meshes")
            quit(1)
            return
        var floor_batch: MultiMeshInstance3D = batches["FloorBatch"]
        var target_batch: MultiMeshInstance3D = batches["TargetBatch"]
        if floor_batch.multimesh == null or target_batch.multimesh == null \
                or floor_batch.multimesh.instance_count != game.size * game.size \
                or target_batch.multimesh.instance_count != game.wanted.size() \
                or not floor_batch.multimesh.use_colors \
                or not target_batch.multimesh.use_colors:
            push_error("Instanced native grid lost positions or per-cell candy colors")
            quit(1)
            return
        var floor_material: StandardMaterial3D = floor_batch.material_override
        var marker_material: StandardMaterial3D = target_batch.material_override
        if not floor_material.vertex_color_use_as_albedo \
                or not marker_material.vertex_color_use_as_albedo:
            push_error("Instanced candy tiles ignore their individual vertex colors")
            quit(1)
            return
        # The dummy RenderingServer used for headless puzzle tests does not
        # retain per-instance transform/color buffers: getters yield zeros.
        # Pixel/instance validation runs with Mesa OpenGL in capture.gd.
        if DisplayServer.get_name() != "headless":
            for row in range(game.size):
                for col in range(game.size):
                    var flat_idx: int = row * game.size + col
                    var grid_pos: Vector3 = floor_batch.multimesh.get_instance_transform(
                        flat_idx).origin
                    var expected_pos := Vector3(col + .5 - game.size / 2.0,
                        .022, row + .5 - game.size / 2.0)
                    if grid_pos.distance_to(expected_pos) > .001:
                        push_error("Instanced board level %d cell (%d,%d) index %d: got %s expected %s" % [
                            level_index, row, col, flat_idx, str(grid_pos), str(expected_pos)])
                        quit(1)
                        return
                    var cell := Vector2i(row, col)
                    var tint := Color("#101e37")
                    if game.wanted.has(cell):
                        tint = Color(game.PALETTE[game.wanted[cell]]).darkened(.68)
                    if not floor_batch.multimesh.get_instance_color(flat_idx).is_equal_approx(tint):
                        push_error("GPU batch lost authored target color at " + str(cell))
                        quit(1)
                        return
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
            # The target-aware magnet must favour a correct neighbouring
            # pose over a physically valid but incorrect direct touch.
            var nearby_wrong := Vector2i(1, 1)
            if not game._can_place(first_id, nearby_wrong, 0) \
                    or game._matches_model(first_id, nearby_wrong, 0) \
                    or game._snap_placement(first_id, nearby_wrong, 0) != first_position:
                push_error("Magnet did not prioritise the authored target nearby")
                quit(1)
                return
            if game._snap_placement(first_id, wrong_position, 0) != wrong_position:
                push_error("Magnet teleported a deliberately distant wrong move")
                quit(1)
                return
            game._try_place(first_id, wrong_position)
            if game.placements.size() != 1 or not game.status_label.text.contains("différent du modèle"):
                push_error("Incorrect geometry match did not warn the player")
                quit(1)
                return
            var misplaced_node: Node3D = null
            for child in game.board.get_children():
                if child.name == "Piece_" + first_id and not child.is_queued_for_deletion():
                    misplaced_node = child
            if misplaced_node == null:
                push_error("No real Godot node for the misplaced candy")
                quit(1)
                return
            var misplaced_shader: ShaderMaterial = misplaced_node.get_child(0).material_override
            if float(misplaced_shader.get_shader_parameter("mismatch")) < .95:
                push_error("Misplaced candy has no persistent amber border")
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
            var fx_counter_before: int = fx.landing_cursor
            game._try_place(first_id, first_position)
            if fx.landing_cursor != fx_counter_before + 1:
                push_error("A real completed placement did not trigger candy glints")
                quit(1)
                return
            if game.placements.size() != 1 or not game.has_undo_snapshot:
                push_error("First-placement undo snapshot is unavailable")
                quit(1)
                return
            # Re-tapping an identical pose must not inflate the move count,
            # overwrite undo state, or replay a landing effect.
            var count_before: int = game.moves
            var history_before: int = game.undo_history.size()
            game.selected_id = first_id
            game.selected_turns = 0
            game._try_place(first_id, first_position)
            if game.moves != count_before or game.undo_history.size() != history_before:
                push_error("Repeated identical touch created a fake game move")
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
            # Every part of the same candy polyomino must render glossy
            # stud geometry with ONE shared shader material.
            var preview_studs: MultiMeshInstance3D = preview_b.get_node("SoftGelStuds")
            if preview_studs.multimesh.instance_count != game.pieces[first_id].size() * 4 \
                    or preview_studs.multimesh.mesh != game.stud_mesh \
                    or preview_studs.material_override != preview_b.get_child(0).material_override:
                push_error("Glossy studs are missing, duplicated or not shaded like the jelly")
                quit(1)
                return
            var placed_studs: MultiMeshInstance3D = preview_a.get_node("SoftGelStuds")
            if placed_studs.multimesh.instance_count != preview_studs.multimesh.instance_count \
                    or preview_a.get_node_or_null("SoftContactShadow") == null \
                    or preview_b.get_node_or_null("SoftContactShadow") != null:
                push_error("Preview/placed studio geometry and contact shadow disagree")
                quit(1)
                return
            var ghost_mat: ShaderMaterial = preview_b.get_child(0).material_override
            if float(ghost_mat.get_shader_parameter("sheen")) > .22:
                push_error("Jelly preview reflection is too distracting")
                quit(1)
                return
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
            if game.preview_cell != first_position + Vector2i(1, 0):
                push_error("Touch cursor was not retained during preview")
                quit(1)
                return
            if game.ghost.get_child_count() != 1 or game.ghost.get_child(0) != first_ghost:
                push_error("Dragging still recreates the jelly ghost every frame")
                quit(1)
                return
            game._draw_preview(Vector2i(-1, -1))
            if first_ghost.visible:
                push_error("Touch release failed to hide jelly ghost")
                quit(1)
                return

            # The shape outline is reused across fast drag callbacks, with
            # exactly one cached rotated shape for each distinct orientation.
            game.rotated_cells_cache.clear()
            var outline_one: Array = game._pose_cells(first_id, 1)
            var outline_again: Array = game._pose_cells(first_id, 1)
            if game.rotated_cells_cache.size() != 1 \
                    or outline_one.size() != game.pieces[first_id].size() \
                    or outline_again != outline_one:
                push_error("Rotation cache does not reuse stable native puzzle outlines")
                quit(1)
                return

            # Android can send multiple fingers at the same time. Only
            # the finger that pressed first owns this placement gesture.
            var visible_size: Vector2 = game.get_viewport().get_visible_rect().size
            var upper: float = game.top_panel.get_global_rect().end.y
            var lower: float = game.bottom_panel.get_global_rect().position.y
            var touch_point := Vector2(visible_size.x * 0.5, (upper + lower) * 0.5)
            if lower <= upper + 12.0 \
                    or not game._inside_board_input_area(touch_point) \
                    or game._inside_board_input_area(Vector2(10, upper - 5)) \
                    or game._inside_board_input_area(Vector2(10, lower + 5)):
                push_error("Playable touch bounds are not aligned with live native HUD")
                quit(1)
                return
            var finger_a := InputEventScreenTouch.new()
            finger_a.index = 3
            finger_a.position = touch_point
            finger_a.pressed = true
            game._unhandled_input(finger_a)
            if not game.touch_started_on_board or game.active_touch_index != 3:
                push_error("First mobile finger failed to acquire a board gesture")
                quit(1)
                return
            var finger_b := InputEventScreenTouch.new()
            finger_b.index = 4
            finger_b.position = touch_point
            finger_b.pressed = true
            game._unhandled_input(finger_b)
            finger_b.pressed = false
            game._unhandled_input(finger_b)
            if game.active_touch_index != 3 or not game.placements.is_empty():
                push_error("Secondary Android contact hijacked or committed a board gesture")
                quit(1)
                return
            var finger_cancel := InputEventScreenTouch.new()
            finger_cancel.index = 3
            finger_cancel.position = touch_point
            finger_cancel.pressed = false
            finger_cancel.canceled = true
            game._unhandled_input(finger_cancel)
            if game.active_touch_index != -1 or game.touch_started_on_board \
                    or not game.placements.is_empty() or game.preview_cell.x >= 0:
                push_error("Cancelled Android touch committed jelly or left a stale ghost")
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
            # Save midway, create a fresh scene and assert that restarting the
            # Android process preserves poses, selection, rotation and undo.
            game._try_place(first_id, first_position)
            game.selected_id = second_id
            game.selected_turns = 1
            game._save_progress()
            var persisted: Variant = JSON.parse_string(
                FileAccess.get_file_as_string(game.SAVE_FILE))
            if not persisted is Dictionary or not persisted.has("session") \
                    or not persisted.has("sessions") or int(persisted.get("format", 0)) != 2:
                push_error("Native Android progress lacks versioned per-level saves")
                quit(1)
                return
            if not persisted["sessions"].has("0") \
                    or persisted["sessions"]["0"]["placements"].size() != 1:
                push_error("Mid-game save was not indexed by level")
                quit(1)
                return
            if FileAccess.file_exists(game.TEMP_SAVE_FILE):
                push_error("Temporary save was not committed through rename")
                quit(1)
                return
            var reopened = scene.instantiate()
            root.add_child(reopened)
            if reopened.placements.size() != 1 \
                    or not reopened.placements.has(first_id) \
                    or reopened.selected_id != second_id \
                    or reopened.selected_turns != 1 \
                    or reopened.undo_history.size() != 1 \
                    or not reopened.has_undo_snapshot:
                push_error("Reopening Android loses a partial puzzle or undo history")
                quit(1)
                return
            reopened._undo()
            if not reopened.placements.is_empty():
                push_error("Restored undo is unusable after process restart")
                quit(1)
                return
            # Preserve two partially completed levels simultaneously across
            # level navigation instead of overwriting a single session.
            reopened._try_place(first_id, first_position)
            reopened._open_level(1)
            var other_level_id: String = String(reopened.pieces.keys()[0])
            var other_origin := Vector2i(reopened.size, reopened.size)
            var other_rows: Array = reopened.levels[1]["rows"]
            for rr in range(reopened.size):
                for cc in range(reopened.size):
                    if String(other_rows[rr]).substr(cc, 1) == other_level_id:
                        other_origin.x = mini(other_origin.x, rr)
                        other_origin.y = mini(other_origin.y, cc)
            reopened.selected_id = other_level_id
            reopened.selected_turns = 0
            reopened._try_place(other_level_id, other_origin)
            if not reopened.placements.has(other_level_id):
                push_error("Second puzzle move was rejected during session test")
                quit(1)
                return
            reopened._open_level(0)
            if reopened.placements.size() != 1 or not reopened.placements.has(first_id):
                push_error("Switching levels erased a partially completed first puzzle")
                quit(1)
                return
            reopened._open_level(1)
            if reopened.placements.size() != 1 \
                    or not reopened.placements.has(other_level_id):
                push_error("Switching back erased the second puzzle")
                quit(1)
                return
            if not FileAccess.file_exists(game.BACKUP_SAVE_FILE):
                push_error("Save protocol never wrote a backup generation")
                quit(1)
                return
            reopened.queue_free()

            # A truncated primary JSON should recover the previous complete
            # generation rather than silently erase progress or settings.
            var known_good := FileAccess.get_file_as_string(game.SAVE_FILE)
            var safe_backup := FileAccess.open(game.BACKUP_SAVE_FILE, FileAccess.WRITE)
            safe_backup.store_string(known_good)
            safe_backup.close()
            var truncated := FileAccess.open(game.SAVE_FILE, FileAccess.WRITE)
            truncated.store_string("{\"sessions\":")
            truncated.close()
            var backup_reopen = scene.instantiate()
            root.add_child(backup_reopen)
            if backup_reopen.saved_sessions.size() < 2 \
                    or backup_reopen.current_level != 1 \
                    or backup_reopen.placements.size() != 1:
                push_error("Truncated active save failed to recover backup session")
                quit(1)
                return
            backup_reopen.queue_free()
            # Restore the original save so the older invalid-position
            # regression still tests semantic validation, not JSON parsing.
            var restore_primary := FileAccess.open(game.SAVE_FILE, FileAccess.WRITE)
            restore_primary.store_string(JSON.stringify(persisted))
            restore_primary.close()

            # Inject an impossible row into a structurally valid JSON snapshot.
            # It must not render out-of-bounds shapes or partially restore.
            var broken: Dictionary = persisted.duplicate(true)
            var session: Dictionary = broken["session"]
            var saved_poses: Dictionary = session["placements"]
            var invalid_pose: Dictionary = saved_poses[first_id]
            invalid_pose["row"] = -50
            saved_poses[first_id] = invalid_pose
            session["placements"] = saved_poses
            broken["session"] = session
            # v0.9.8 restores indexed sessions first. Corrupt BOTH the
            # legacy alias and canonical indexed entry to test rejection.
            var broken_sessions: Dictionary = broken["sessions"]
            broken_sessions["0"] = session.duplicate(true)
            broken["sessions"] = broken_sessions
            var corrupted_file := FileAccess.open(game.SAVE_FILE, FileAccess.WRITE)
            corrupted_file.store_string(JSON.stringify(broken))
            corrupted_file.close()
            var clean_reopen = scene.instantiate()
            root.add_child(clean_reopen)
            if not clean_reopen.placements.is_empty() \
                    or clean_reopen.has_undo_snapshot:
                push_error("Out-of-range saved puzzle was not discarded")
                quit(1)
                return
            clean_reopen.queue_free()
            game._undo()
            if not game.placements.is_empty():
                push_error("Persistence smoke test altered the original puzzle")
                quit(1)
                return
            # Portable Android backup: real serialize/parse roundtrip, strict
            # checksum, malformed level validation and transactional restoration.
            if game.export_picker == null or game.import_picker == null \
                    or game.import_confirmation == null \
                    or not game.export_picker.use_native_dialog \
                    or game.export_picker.access != FileDialog.ACCESS_FILESYSTEM \
                    or game.import_picker.access != FileDialog.ACCESS_FILESYSTEM:
                push_error("Godot 4.6 Android SAF export/import controls are missing")
                quit(1)
                return
            var before_portable: Dictionary = game._read_progress_data()
            var portable_string: String = SAVE_TRANSFER.encode(before_portable)
            var portable: Dictionary = SAVE_TRANSFER.decode(portable_string, game.levels)
            if not portable.get("ok", false) \
                    or portable["progress"]["sessions"].size() < 1:
                push_error("Portable Android backup roundtrip invalid: " + str(portable))
                quit(1)
                return
            var decoded_envelope: Dictionary = JSON.parse_string(portable_string)
            decoded_envelope["sha256"] = "tampered"
            if SAVE_TRANSFER.decode(JSON.stringify(decoded_envelope), game.levels).get("ok", false):
                push_error("Tampered SHA-256 was not rejected")
                quit(1)
                return
            var geometry_tampered: Dictionary = portable["progress"].duplicate(true)
            var first_saved: Dictionary = geometry_tampered["sessions"]["0"]
            var damaged_poses: Dictionary = first_saved["placements"]
            damaged_poses[first_id] = {"row": -999, "col": 0, "turns": 0}
            first_saved["placements"] = damaged_poses
            geometry_tampered["sessions"]["0"] = first_saved
            if SAVE_TRANSFER.validate_progress(geometry_tampered, game.levels).get("ok", false):
                push_error("Checksum-valid but geometrically corrupt backup accepted")
                quit(1)
                return
            var primary_before: String = FileAccess.get_file_as_string(game.SAVE_FILE)
            if game._install_backup(geometry_tampered) \
                    or FileAccess.get_file_as_string(game.SAVE_FILE) != primary_before:
                push_error("Rejected imported save damaged current player progress")
                quit(1)
                return
            var previous_player_save: String = FileAccess.get_file_as_string(game.SAVE_FILE)
            if not game._install_backup(portable["progress"]):
                push_error("Known-good backup import could not commit")
                quit(1)
                return
            if FileAccess.get_file_as_string(game.PRE_IMPORT_SAVE_FILE) != previous_player_save:
                push_error("Import rollback backup was overwritten by subsequent autosave")
                quit(1)
                return
            if game._read_progress_data().get("format", 0) != 2 \
                    or not game._read_progress_data().has("sessions"):
                push_error("Restored Android backup did not persist")
                quit(1)
                return
            print("TEST: Android SAF dialogs, portable JSON SHA-256 and safe import rollback")
            print("TEST: atomic save swap, JSON backup recovery and multi-level sessions")
            print("TEST: resume incomplete native game with undo; reject damaged saves")
            print("TEST: target-aware magnet, no-op guard, amber shader, smooth ghost tracking")
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
