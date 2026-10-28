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
    # The Android launcher must ship with the branded Jelly icon rather
    # than fall back to the platform's generic default application badge.
    var icon_path: String = String(ProjectSettings.get_setting(
        "application/config/icon", ""))
    if icon_path != "res://icon.svg" or not FileAccess.file_exists(icon_path):
        push_error("Native Android project has no installable branded launcher icon")
        quit(1)
        return
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("Main native scene failed loading")
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    # New Android installs must show actual 3D content without taking
    # away the puzzle screen from returning players or desktop QA.
    if not game._prefer_studio_mode(false, true, "") \
            or game._prefer_studio_mode(true, true, "") \
            or game._prefer_studio_mode(false, false, "") \
            or not game._prefer_studio_mode(true, true, "studio") \
            or game._prefer_studio_mode(false, true, "puzzle"):
        push_error("First-run mobile 3D entry or mode persistence is wrong")
        quit(1)
        return
    if not game.moves_label.text.contains("v" + game.APP_VERSION):
        push_error("Current APK version is not visible inside puzzle screen")
        quit(1)
        return
    var mastery_api = load("res://scripts/figure_challenges.gd")
    var empty_collection: Dictionary = mastery_api.collection_summary(
        mastery_api.fresh_progress())
    if empty_collection["completed"] != 0 or empty_collection["stars"] != 0 \
            or empty_collection["mastery"]["title"] != "Novice":
        push_error("Empty collection should start at novice rank")
        quit(1)
        return
    var full_collection: Dictionary = mastery_api.fresh_progress()
    full_collection["xp"] = 3500
    for figure_i in range(20):
        full_collection["best"][str(figure_i)] = 100 + figure_i
        full_collection["stars"][str(figure_i)] = 3
    # The fifth cosmetic rank is not an unreachable UI promise.
    # Earn XP only once for each of the 20 genuinely solvable figures.
    var campaign_wins: Dictionary = mastery_api.fresh_progress()
    for figure_id in range(20):
        var win: Dictionary = mastery_api.grant(
            campaign_wins, figure_id, mastery_api.par_bricks(figure_id))
        campaign_wins = win["progress"]
    var earned_collection: Dictionary = mastery_api.collection_summary(
        campaign_wins)
    if earned_collection["completed"] != 20 \
            or earned_collection["stars"] != 60 \
            or campaign_wins["unlocked"] != 20 \
            or earned_collection["mastery"]["title"] != "Artiste Jelly" \
            or int(campaign_wins["xp"]) < 3500:
        push_error("Campaign's 20 first wins cannot unlock the final mastery rank")
        quit(1)
        return
    var completed_collection: Dictionary = mastery_api.collection_summary(
        full_collection)
    if completed_collection["completed"] != 20 \
            or completed_collection["stars"] != 60 \
            or completed_collection["mastery"]["title"] != "Artiste Jelly" \
            or completed_collection["mastery"]["next_xp"] != -1:
        push_error("Figure collection, stars or mastery progression is wrong")
        quit(1)
        return
    if game.levels.size() != 21:
        push_error("The 21 authored levels were not imported")
        quit(1)
        return
    var figures = load("res://scripts/figure_challenges.gd")
    if not figures.validate_catalog():
        push_error("Invalid 20-figure challenge catalog")
        quit(1)
        return
    for figure_id in range(20):
        var goal: Dictionary = figures.target(figure_id)
        var placements: Array = []
        for rr in range(6):
            for cc in range(6):
                var cell: String = String(goal["rows"][rr]).substr(cc, 1)
                if cell != ".":
                    placements.append({"row": rr, "col": cc, "length": 0,
                        "turns": 0, "layer": 0, "color": int(cell)})
        if not figures.evaluate(figure_id, placements)["won"]:
            push_error("Unsolvable figure: " + str(figure_id))
            quit(1)
            return
    print("PASS: all 20 authored figure silhouettes are solvable")
    # The 3-star benchmark is built from LEGAL 1/2/3-cell runs;
    # even the 30-cell penguin can genuinely earn all three stars.
    for figure_id in range(20):
        var par: int = figures.par_bricks(figure_id)
        if par <= 0 or par > 32 \
                or int(figures.reward(figure_id, par)["stars"]) != 3 \
                or int(figures.reward(figure_id, par + 4)["stars"]) != 1:
            push_error("Unreachable or non-discriminative star benchmark")
            quit(1)
            return
    var campaign: Dictionary = figures.fresh_progress()
    var first: Dictionary = figures.grant(campaign, 0, 20)
    campaign = first["progress"]
    var first_xp: int = int(campaign["xp"])
    var first_points: int = int(campaign["total_score"])
    var replay: Dictionary = figures.grant(campaign, 0, 20)
    if not first["first_win"] or replay["first_win"] \
            or int(replay["earned"]) != 0 \
            or int(campaign["xp"]) != first_xp \
            or int(campaign["total_score"]) != first_points:
        push_error("Campaign rewards can be farmed by replay")
        quit(1)
        return
    var campaign_session: Array = [{"row": 2, "col": 2,
        "length": 0, "turns": 0, "layer": 0, "color": 0}]
    campaign["sessions"] = {"0": campaign_session}
    campaign["active"] = 0
    if not figures.save_progress(campaign):
        push_error("Campaign checkpoint failed")
        quit(1)
        return
    var restored: Dictionary = figures.load_progress()
    if restored["sessions"]["0"].size() != 1 \
            or int(restored["xp"]) != first_xp \
            or int(restored["stars"].get("0", 0)) < 1:
        push_error("Campaign checkpoint lost construction, XP or stars")
        quit(1)
        return
    if not figures.save_progress(campaign):
        push_error("Campaign backup save failed")
        quit(1)
        return
    # An interrupted mobile filesystem write must not erase the last
    # good checkpoint. Recover from the local second-generation backup.
    var damaged_campaign_file := FileAccess.open(figures.SAVE, FileAccess.WRITE)
    if damaged_campaign_file == null:
        push_error("Campaign corruption regression fixture failed")
        quit(1)
        return
    damaged_campaign_file.store_string("{bad-json")
    damaged_campaign_file.close()
    var recovered: Dictionary = figures.load_progress()
    if recovered["sessions"]["0"].size() != 1:
        push_error("Campaign did not recover from damaged primary save")
        quit(1)
        return
    print("PASS: attainable 3 stars, XP anti-farming and crash-safe sessions")

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
    # A figure must remain visible while playing, and the free studio
    # must return untouched after several campaign/autosave round trips.
    var free_before: String = JSON.stringify(studio._export_entries())
    var selection_color_before: int = studio.selected_color
    var selection_length_before: int = studio.selected_length
    var selection_cell_before: Vector2i = studio.selected_cell
    if studio.figure_mini_cells.size() != 36:
        push_error("Campaign figure model is not available as a live HUD")
        quit(1)
        return
    studio._toggle_figures()
    if not studio.figure_active or studio.figure_index != 0 \
            or not studio.figure_mini_row.visible \
            or studio.bricks.size() != 0:
        push_error("Figure campaign did not enter the correct first blank level")
        quit(1)
        return
    studio.selected_cell = Vector2i(1, 1)
    studio.selected_length = 0
    studio.selected_color = 0
    studio._commit()
    if studio.bricks.size() != 1:
        push_error("Campaign figure did not accept the first valid 3D brick")
        quit(1)
        return
    studio._toggle_figures()
    if studio.figure_active or JSON.stringify(studio._export_entries()) != free_before:
        push_error("Campaign entry corrupted the original free Studio")
        quit(1)
        return
    studio._toggle_figures()
    if studio.bricks.size() != 1 \
            or int(studio.bricks[0]["row"]) != 1 \
            or int(studio.bricks[0]["col"]) != 1:
        push_error("Campaign did not resume an autosaved in-progress figure")
        quit(1)
        return
    studio._toggle_figures()
    if studio.figure_active or JSON.stringify(studio._export_entries()) != free_before:
        push_error("Campaign resume corrupted free-mode saves")
        quit(1)
        return
    # Restore all mutable input state: later tests intentionally assert
    # that Color #1 and Medium are highlighted on first launch.
    studio._choose_color(selection_color_before)
    studio._choose_length(selection_length_before)
    studio.selected_cell = selection_cell_before
    studio._refresh_preview()
    print("PASS: in-game 20-figure HUD, autosave and separate free-studio scene")

    var caustic: MultiMeshInstance3D = studio.caustic_batch
    if caustic == null or caustic.name != "CandyLightTransmission" \
            or caustic.multimesh.instance_count != 3 \
            or not caustic.multimesh.use_colors \
            or caustic.multimesh.mesh == null \
            or not caustic.material_override is ShaderMaterial:
        push_error("Studio transmission has lost its pooled, colored GPU instances")
        quit(1)
        return
    if studio.get_node("CandyStackStage/CandyLightTransmission") != caustic:
        push_error("The floor caustic resource is duplicated or detached")
        quit(1)
        return
    var caustic_paint: ShaderMaterial = caustic.material_override
    if absf(float(caustic_paint.get_shader_parameter("transmission_energy")) -
            .74) > .001:
        push_error("Real-time construction Jelly lost its low-cost ground pigmentation")
        quit(1)
        return
    # The stacking bars now have original rounded single-body geometry,
    # not the previous cell-by-cell square silhouette. Verify every size
    # and horizontal/vertical orientation on the *actual* Godot mesh.
    for molded_length in [1, 2, 3]:
        for molded_turn in [0, 1]:
            var molded: ArrayMesh = GEL_MESH.build_studio(
                molded_length, molded_turn)
            if molded == null or molded.get_surface_count() != 1:
                push_error("Molded studio candy has no native 3D skin")
                quit(1)
                return
            if not _clockwise_exterior(molded):
                push_error("Studio exterior faces point into the cavity")
                quit(1)
                return
            var width_expected: float = float(
                molded_length if molded_turn == 0 else 1)
            var depth_expected: float = float(
                1 if molded_turn == 0 else molded_length)
            var bound: AABB = molded.get_aabb()
            if absf(bound.size.x - (width_expected + .072)) > .02 \
                    or absf(bound.size.z - (depth_expected + .072)) > .02 \
                    or absf(bound.size.y - (GEL_MESH.TOP + .018 - GEL_MESH.BASE)) > .02:
                push_error("Soft rounded silhouette has incorrect molded dimensions")
                quit(1)
                return
            var arrays: Array = molded.surface_get_arrays(0)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            var face_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
            var found_arc := false
            var found_continuous_crown := false
            var curved_crown_normal := false
            var flat_upper := false
            var flat_lower := false
            var recessed_roof := false
            var recessed_rim := false
            var old_flat_underside := false
            var middle_wall_vertices := 0
            var long_wall_vertices := 0
            var inner_crown_vertices := 0
            for vertex_id in range(vertices.size()):
                var v: Vector3 = vertices[vertex_id]
                var n: Vector3 = face_normals[vertex_id]
                if absf(n.y) < .01:
                    if absf(v.y - GEL_MESH.STUDIO_RING_HEIGHTS[3]) < .001:
                        flat_upper = true
                    if absf(v.y - GEL_MESH.STUDIO_RING_HEIGHTS[5]) < .001:
                        flat_lower = true
                    # The straight wall now has real intermediate vertices
                    # along BOTH height and length: waves cannot travel
                    # through a single planar quad with only corner verts.
                    if absf(v.y - GEL_MESH.STUDIO_RING_HEIGHTS[4]) < .001:
                        middle_wall_vertices += 1
                        var along: float = v.x if molded_turn == 0 else v.z
                        if along > .30 and along < float(molded_length) - .30:
                            long_wall_vertices += 1
                if absf(v.y - GEL_MESH.TOP) < .001 \
                        and v.x > width_expected - .01 \
                        and v.z > depth_expected - .15 \
                        and v.z < depth_expected - .06:
                    found_arc = true
                # Crown should have a full extra tessellated row ON the
                # old neutral surface: per-frame bending now reaches its
                # interior rather than only the outer rim and centre.
                if absf(v.y - (GEL_MESH.TOP +
                        .018 * GEL_MESH.STUDIO_CROWN_TESSELLATION)) < .0006 \
                        and v.x > .07 and v.x < width_expected - .07 \
                        and v.z > .07 and v.z < depth_expected - .07:
                    inner_crown_vertices += 1
                if absf(v.y - (GEL_MESH.TOP + .018)) < .001 \
                        and absf(v.x - width_expected * .5) < .001 \
                        and absf(v.z - depth_expected * .5) < .001 \
                        and n.y > .99:
                    found_continuous_crown = true
                if absf(v.y - GEL_MESH.TOP) < .001 \
                        and n.y > .90 and n.y < .98 \
                        and Vector2(n.x, n.z).length() > .20:
                    curved_crown_normal = true
                if absf(v.x - width_expected * .5) < .001 \
                        and absf(v.z - depth_expected * .5) < .001:
                    if absf(v.y - GEL_MESH.STUDIO_SOCKET_ROOF) < .001:
                        recessed_roof = true
                    if absf(v.y - GEL_MESH.BASE) < .001:
                        old_flat_underside = true
                if absf(v.y - GEL_MESH.STUDIO_SOCKET_ROOF) < .001 \
                        and absf(v.x - GEL_MESH.STUDIO_UNDERSIDE_INSET) < .015:
                    recessed_rim = true
            if not found_arc or not found_continuous_crown \
                    or not curved_crown_normal \
                    or not flat_upper or not flat_lower or not recessed_roof \
                    or not recessed_rim or old_flat_underside \
                    or face_normals.size() != vertices.size() \
                    or vertices.size() < 400 or vertices.size() > 1000 \
                    or middle_wall_vertices < 4 \
                    or inner_crown_vertices < 8 \
                    or long_wall_vertices < (2 if molded_length == 1 else 4):
                push_error("Studio geometry invalid: length=%d turn=%d verts=%d mid=%d long=%d arc=%s crown=%s normals=%s upper=%s lower=%s roof=%s rim=%s flat_bottom=%s" % [
                    molded_length, molded_turn, vertices.size(),
                    middle_wall_vertices, long_wall_vertices,
                    str(found_arc), str(found_continuous_crown),
                    str(curved_crown_normal), str(flat_upper),
                    str(flat_lower), str(recessed_roof),
                    str(recessed_rim), str(old_flat_underside)])
                quit(1)
                return
    if GEL_MESH.STUDIO_CORNER_RADIUS < .140 \
            or GEL_MESH.STUDIO_CORNER_RADIUS > .155 \
            or GEL_MESH.STUDIO_CROWN_TESSELLATION < .50 \
            or GEL_MESH.STUDIO_CROWN_TESSELLATION > .58 \
            or GEL_MESH.STUDIO_CORNER_STEPS < 10 \
            or GEL_MESH.STUDIO_STRAIGHT_SEGMENT_MAX > .68 \
            or GEL_MESH.STUDIO_RING_OFFSETS.max() > .040 \
            or GEL_MESH.STUDIO_RING_HEIGHTS.size() < 8 \
            or absf(GEL_MESH.STUDIO_RING_OFFSETS[3] -
                GEL_MESH.STUDIO_RING_OFFSETS[5]) > .0001 \
            or GEL_MESH.STUDIO_RING_HEIGHTS[3] - GEL_MESH.STUDIO_RING_HEIGHTS[5] < .26 \
            or absf(GEL_MESH.STUDIO_RING_VERTICALS[3]) > .001 \
            or absf(GEL_MESH.STUDIO_RING_VERTICALS[5]) > .001 \
            or GEL_MESH.STUDIO_RING_VERTICALS[0] < .965 \
            or GEL_MESH.STUDIO_RING_VERTICALS[0] > .975:
        push_error("Studio Jelly sides must retain a substantial planar wall")
        quit(1)
        return
    # Reference video: a long straight wall and low, almost flat crown
    # are visually more important than a high inflated bevel.
    if GEL_MESH.STUDIO_RING_HEIGHTS[3] - GEL_MESH.STUDIO_RING_HEIGHTS[5] < .33 \
            or GEL_MESH.STUDIO_CORNER_RADIUS < .097 \
            or (GEL_MESH.TOP + .018) >= GEL_MESH.STUDIO_STUD_BASE:
        push_error("Video reference requires upright walls and a level crown below studs")
        quit(1)
        return
    print("TEST: all six molded Jelly bars have wave-ready wall rows, length tessellation and original socket")

    # New studio-only tenons must look like the supplied reference:
    # nearly flat caps and upright sides, not the puzzle's domed nubs.
    var studio_stud: ArrayMesh = studio.studio_stud_mesh
    if studio_stud == null or studio_stud.get_surface_count() != 1 \
            or studio_stud == game.stud_mesh:
        push_error("Studio has no separate flat-top stud mesh")
        quit(1)
        return
    if not _clockwise_exterior(studio_stud) or not _clockwise_exterior(GEL_MESH.build_stud()):
        push_error("Stud caps must face outside with clockwise winding")
        quit(1)
        return
    var flat_mold_bounds: AABB = studio_stud.get_aabb()
    if absf(flat_mold_bounds.size.x - GEL_MESH.STUDIO_STUD_RADIUS * 2.0) > .002 \
            or absf(flat_mold_bounds.size.z - GEL_MESH.STUDIO_STUD_RADIUS * 2.0) > .002 \
            or absf(flat_mold_bounds.position.y - GEL_MESH.STUDIO_STUD_BASE) > .002 \
            or absf(flat_mold_bounds.end.y - GEL_MESH.STUDIO_STUD_TOP) > .002:
        push_error("Studio flat stud has incorrect radius or layer contact height")
        quit(1)
        return
    var stud_arrays: Array = studio_stud.surface_get_arrays(0)
    var flat_stud_vertices: PackedVector3Array = stud_arrays[Mesh.ARRAY_VERTEX]
    var flat_stud_normals: PackedVector3Array = stud_arrays[Mesh.ARRAY_NORMAL]
    var stud_cap := false
    var stud_shoulder := false
    for vi in range(flat_stud_vertices.size()):
        var vertex: Vector3 = flat_stud_vertices[vi]
        if absf(vertex.x) < .001 and absf(vertex.z) < .001 \
                and absf(vertex.y - GEL_MESH.STUDIO_STUD_TOP) < .001 \
                and flat_stud_normals[vi].y > .99:
            stud_cap = true
        if absf(vertex.y - .781) < .001 \
                and absf(Vector2(vertex.x, vertex.z).length() \
                    - GEL_MESH.STUDIO_STUD_RADIUS) < .002:
            stud_shoulder = true
    if not stud_cap or not stud_shoulder \
            or flat_stud_normals.size() != flat_stud_vertices.size():
        push_error("Studio stud cap is ballooned or missing its crisp shoulder")
        quit(1)
        return
    if game.stud_mesh.get_aabb().size.x <= flat_mold_bounds.size.x:
        push_error("Legacy puzzle studs were accidentally replaced or reshaped")
        quit(1)
        return
    print("TEST: physically flat studio tenons and unchanged classic puzzle studs")

    if studio.brick_nodes.size() != studio.bricks.size() \
            or studio.contact_material == null:
        push_error("Studio bricks or shared contact resources were not built")
        quit(1)
        return
    # The backdrop is a physical scene, not just a nearly invisible box.
    if studio.get_node_or_null("CandyStackStage/SatinPlinthEdge") == null \
            or studio.get_node_or_null("CandyStackStage/StudioGroundContact") == null:
        push_error("Studio is missing its grounded white product-stage details")
        quit(1)
        return
    var plinth: MeshInstance3D = studio.get_node("CandyStackStage/SatinPlinth")
    var plinth_material: StandardMaterial3D = plinth.material_override
    if plinth_material.albedo_color.r < .84 or plinth_material.albedo_color.r > .99:
        push_error("Studio plinth loses its restrained pearl-white material")
        quit(1)
        return
    var ground_shadow: MeshInstance3D = studio.get_node(
        "CandyStackStage/StudioGroundContact")
    var ground_material: ShaderMaterial = ground_shadow.material_override
    if float(ground_material.get_shader_parameter("strength")) < .20:
        push_error("Studio support has no legible diffuse contact shadow")
        quit(1)
        return
    for studio_node in studio.brick_nodes:
        if studio_node.get_node_or_null("GelContact") == null:
            push_error("Studio brick has no soft contact shading")
            quit(1)
            return
        var glass_material: ShaderMaterial = studio_node.get_node("GelBody").material_override
        if float(glass_material.get_shader_parameter("studio_glass")) < .95:
            push_error("Native stack glass should be optically distinct from puzzle gel")
            quit(1)
            return
        var solid_alpha: float = float(glass_material.get_shader_parameter("gel_opacity"))
        if float(glass_material.get_shader_parameter("studio_pigment")) < .85 \
                or solid_alpha < .93 or solid_alpha > .95:
            push_error("Studio Jelly must retain saturated dye and visible optical transmission")
            quit(1)
            return
        if float(glass_material.get_shader_parameter("studio_finish")) < .9:
            push_error("Studio candy is missing its high-pigment photographic finish")
            quit(1)
            return
        if float(glass_material.get_shader_parameter("studio_wet_edge")) < .90:
            push_error("Solid studio bricks lost their wet optical bevel")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter("optical_depth")) - .54) > .001:
            push_error("Ordinary studio Jelly should use medium-cost optical absorption")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter("gel_depth_optics")) - .78) > .001:
            push_error("Placed studio Jelly lost its opt-in dyed-depth profile")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter("studio_light_card")) - .88) > .001:
            push_error("Interactive studio Jelly lost its molded sidewall softbox")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter("studio_transmission")) - .86) > .001:
            push_error("Studio brick lacks the video-directed pigmented translucent core")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter(
                "studio_pressure_strength")) - .96) > .001:
            push_error("Solid Jelly body lost localized contact-pressure deformation")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter(
                "studio_strain_optics")) - .88) > .001:
            push_error("Solid Jelly body lost strain-linked optical depth")
            quit(1)
            return
        # Guard the video-derived per-pigment optics against accidental
        # removal during future shader cleanup. This shader is shared by
        # puzzles, but only the studio has nonzero studio_transmission.
        var jelly_shader_source: String = glass_material.shader.code
        for required_optic in ["golden_pigment", "royal_pigment",
                "ruby_pigment", "stud_cap", "optical_dye",
                "gel_depth_optics", "through_gel", "base_roughness",
                "studio_contact_dye", "joining_height", "overlap_falloff",
                "jelly_surface_normal.y < -.985",
                "jelly_local.y < .267", "discard;",
                "radial_slope", "ripple_intensity", "tinted_wave_glint",
                "contact_radius", "local_squash", "studio_wave_center",
                "stud_filled", "ALPHA = mix(ALPHA, .998, stud_filled)",
                "studio_jiggle_phase", "studio_jiggle_gain",
                "viscous_decay", "anchored_wall", "transient_wet",
                "INSTANCE_CUSTOM.rg", "stud_domain", "tip_weight",
                "footprint_xz", "delayed_mode", "upper_weight",
                "studio_pressure_strength", "pressure_well",
                "volume_return", "pressure_footprint", "pressure_crown",
                "jelly_optic_strain", "studio_strain_optics",
                "thinner_cap", "denser_wall", "refracted_dye"]:
            if not jelly_shader_source.contains(required_optic):
                push_error("Missing video-calibrated Jelly optic: " + required_optic)
                quit(1)
                return
        var studio_shell: MeshInstance3D = studio_node.get_node("GelBody")
        var soft_studs: MultiMeshInstance3D = studio_node.get_node("GelStuds")
        if not studio_shell.sorting_use_aabb_center \
                or not soft_studs.sorting_use_aabb_center:
            push_error("Translucent Jelly is sorted by the brick corner, not its bounds")
            quit(1)
            return
        if soft_studs.material_override != glass_material:
            push_error("Studs no longer share the pigmented glass coating")
            quit(1)
            return
        # The full stud (y=.592..798) must be optically filled while the
        # actual shell top (below y=.599) remains gently translucent.
        # The same shader material is shared with the transparent ghost,
        # whose low pigment must NOT trigger the filled-stud branch.
        if GEL_MESH.TOP > .600 \
                or GEL_MESH.STUDIO_STUD_BASE >= .605 \
                or GEL_MESH.STUDIO_STUD_TOP <= .655 \
                or not jelly_shader_source.contains(
                    "studio_glass > .001 && studio_pigment > .82") \
                or not jelly_shader_source.contains(
                    "jelly_local.y > .599"):
            push_error("Filled gel stud boundary overlaps the transparent body or ghost")
            quit(1)
            return
        var piece_index: int = studio.brick_nodes.find(studio_node)
        # The gel collar pattern must match physical 2-lane stud instances,
        # including rotated 1/2/3-cell bricks; otherwise optical roots float.
        var actual_entry: Dictionary = studio.bricks[piece_index]
        var expected_contact: Dictionary = studio._contact_profile(
            actual_entry, studio.bricks)
        var actual_dye: Color = glass_material.get_shader_parameter(
            "studio_contact_dye")
        if expected_contact.is_empty():
            if actual_dye.a > .001:
                push_error("Loose/ground Jelly inherited a fake lower contact dye")
                quit(1)
                return
        else:
            var expected_dye: Color = expected_contact["dye"]
            if not actual_dye.is_equal_approx(expected_dye) \
                    or not Vector2(glass_material.get_shader_parameter(
                        "studio_contact_center")).is_equal_approx(
                            expected_contact["center"]):
                push_error("Restored Jelly lost its real supporting pigment and contact position")
                quit(1)
                return
        var expected_axis: float = float(posmod(int(actual_entry["turns"]), 2))
        if absf(float(glass_material.get_shader_parameter("studio_interlock")) - .84) > .001 \
                or absf(float(glass_material.get_shader_parameter("studio_stud_axis")) -
                    expected_axis) > .001:
            push_error("Studio gel menisci do not match their real stud orientation")
            quit(1)
            return
        var expected_studs: int = (int(studio.bricks[piece_index]["length"]) + 1) * 2
        var expected_length: int = studio.LENGTHS[int(actual_entry["length"])]
        var expected_span := Vector2(
            float(expected_length) if expected_axis == 0.0 else 1.0,
            1.0 if expected_axis == 0.0 else float(expected_length))
        var live_span: Vector2 = glass_material.get_shader_parameter("studio_span")
        # A 3-cell bar's world origin is its first grid cell, but its
        # transparent sorting pivot should be the actual volume centre.
        # This is invariant under camera orbit and brick direction.
        var actual_bounds_center: Vector3 = studio_shell.get_aabb().get_center()
        var expected_pivot: Vector2 = expected_span * .5
        if Vector2(actual_bounds_center.x,
                actual_bounds_center.z).distance_to(expected_pivot) > .08:
            push_error("Studio Jelly mesh bounds are not centered on the 3D bar")
            quit(1)
            return
        if not live_span.is_equal_approx(expected_span) \
                or absf(float(glass_material.get_shader_parameter("studio_squash"))) > .001 \
                or absf(float(glass_material.get_shader_parameter("studio_wave_phase"))) > .001 \
                or absf(float(glass_material.get_shader_parameter("studio_wave_gain"))) > .001:
            push_error("Resting Jelly has incorrect mesh-center spans or residual squash")
            quit(1)
            return
        if soft_studs.multimesh.mesh != studio_stud \
                or soft_studs.multimesh.instance_count != expected_studs \
                or not soft_studs.multimesh.use_custom_data \
                or expected_studs < 2 or expected_studs > 6:
            push_error("Studio stud layout diverged from reference 2-lane Jelly blocks")
            quit(1)
            return
        # Gallery-only meshes must never be created just because a
        # user starts or resumes a build. This saves 3 hidden 3D objects
        # per brick (96 at maximum stack size) before Photo is requested.
        if studio_node.get_node_or_null("OpticalBody") != null \
                or studio_node.get_node_or_null("OpticalStuds") != null \
                or studio_node.get_node_or_null("PhotoShadowCaster") != null:
            push_error("Interactive Jelly eagerly allocated photo-only GPU nodes")
            quit(1)
            return
        if absf(float(glass_material.get_shader_parameter("gel_spring"))) > .001:
            push_error("Reloaded studio bricks must have settled spring deformation")
            quit(1)
            return
        var contact: MeshInstance3D = studio_node.get_node("GelContact")
        var contact_index: int = studio.brick_nodes.find(studio_node)
        var contact_layer: int = int(studio.bricks[contact_index]["layer"])
        var expected_contact_y: float = GEL_MESH.STUDIO_SOCKET_ROOF + .004 \
            if contact_layer > 0 else .035
        if absf(contact.position.y - expected_contact_y) > .002:
            push_error("Gel contact must track the new underside socket or ground rim")
            quit(1)
            return
    # The portable backup now includes the REAL 3D studio, with strict
    # replay validation and backward compatibility for puzzle-only v1.
    game._save_progress()
    var save_before_studio: Dictionary = game._read_progress_data()
    var legacy_string: String = SAVE_TRANSFER.encode(save_before_studio)
    var legacy_result: Dictionary = SAVE_TRANSFER.decode(legacy_string, game.levels)
    if not legacy_result.get("ok", false) or legacy_result.get("has_studio", true):
        push_error("Legacy puzzle-only backup was not preserved")
        quit(1)
        return
    var all_in_one: String = SAVE_TRANSFER.encode(
        save_before_studio, studio._export_entries())
    var comprehensive: Dictionary = SAVE_TRANSFER.decode(all_in_one, game.levels)
    if not comprehensive.get("ok", false) \
            or not comprehensive.get("has_studio", false) \
            or comprehensive["studio"].size() != 6:
        push_error("Combined Android puzzles + studio backup failed roundtrip: "
            + str(comprehensive) + " / raw-check="
            + str(SAVE_TRANSFER.validate_studio(studio._export_entries())))
        quit(1)
        return
    var changed: Dictionary = JSON.parse_string(all_in_one)
    var manipulated: Dictionary = JSON.parse_string(changed["payload_json"])
    manipulated["studio"][0]["layer"] = 8
    # An attacker could recompute the SHA. The validator must still reject
    # the unsupported 8th-floor brick and keep the local pile untouched.
    changed["payload_json"] = JSON.stringify(manipulated)
    changed["sha256"] = String(changed["payload_json"]).sha256_text()
    if SAVE_TRANSFER.decode(JSON.stringify(changed), game.levels).get("ok", false):
        push_error("Checksum-valid but physically impossible studio was imported")
        quit(1)
        return
    if studio._install_entries(manipulated["studio"]) \
            or studio.bricks.size() != 6:
        push_error("Rejected studio data modified the local construction")
        quit(1)
        return
    if not studio._install_entries(comprehensive["studio"]):
        push_error("Verified portable studio data could not be restored")
        quit(1)
        return
    print("TEST: portable studio+puzzle backup v2, v1 compatibility, tamper rejection")
    # The gel body must meet the studio plinth, not levitate over it.
    var test_ground: Dictionary = studio._entry(2, 2, 0, 0, 0, 0)
    var ground_bottom: float = studio._world_position(test_ground).y + GEL_MESH.BASE
    if absf(ground_bottom - (-.30)) > .04:
        push_error("Ground studio bricks float above the plinth")
        quit(1)
        return
    var upper_pose: Dictionary = studio._entry(2, 2, 0, 0, 0, 1)
    var measured_step: float = studio._world_position(upper_pose).y - studio._world_position(test_ground).y
    # The socket ceiling sits just ABOVE a supporting stud top, while the
    # upper shell's exterior rim is close to the lower crown. The former
    # 0.74 step left a visibly huge, unsupported gap between jelly faces.
    var socket_clearance: float = measured_step + GEL_MESH.STUDIO_SOCKET_ROOF \
        - GEL_MESH.STUDIO_STUD_TOP
    var visible_body_gap: float = measured_step + GEL_MESH.BASE - GEL_MESH.TOP
    # This is the perceptual test: the old 0.095-unit gap produced a
    # disconnected plastic-block tower instead of nearly touching gelatin.
    if absf(measured_step - .55) > .001 \
            or absf(GEL_MESH.STUDIO_SOCKET_DEPTH - .21) > .001 \
            or socket_clearance < .012 or socket_clearance > .023 \
            or visible_body_gap > .050 or visible_body_gap < .038:
        push_error("Jelly layers must nearly meet while studs remain inside deep sockets")
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
    if not game.candy_fx.visible or studio.camera_button == null:
        push_error("Stacking studio 3D FX or orbit-camera control is missing")
        quit(1)
        return
    # The original mobile HUD had five nearly flat color slabs and length
    # choices differentiated only by text dimming. Selected values must
    # remain obvious in screenshots and after changing colors/lengths.
    var chosen_color: StyleBoxFlat = studio.color_buttons[
        studio.selected_color].get_theme_stylebox("normal") as StyleBoxFlat
    var idle_color: StyleBoxFlat = studio.color_buttons[
        0].get_theme_stylebox("normal") as StyleBoxFlat
    var chosen_length: StyleBoxFlat = studio.length_buttons[
        studio.selected_length].get_theme_stylebox("normal") as StyleBoxFlat
    if chosen_color == null or idle_color == null or chosen_length == null \
            or chosen_color.border_width_left < 3 \
            or idle_color.border_width_left > 1 \
            or chosen_length.border_width_left < 3 \
            or chosen_length.shadow_size <= idle_color.shadow_size:
        push_error("Android studio no longer highlights color and size selections")
        quit(1)
        return
    studio._choose_color(0)
    var swapped: StyleBoxFlat = studio.color_buttons[
        0].get_theme_stylebox("normal") as StyleBoxFlat
    var previous_color: StyleBoxFlat = studio.color_buttons[
        1].get_theme_stylebox("normal") as StyleBoxFlat
    if swapped.border_width_left < 3 or previous_color.border_width_left > 1:
        push_error("Studio color choice failed to update its tactile outline")
        quit(1)
        return
    studio._choose_color(1)
    var camera_front: Transform3D = game.camera.transform
    studio._cycle_camera()
    if studio.camera_mode != 1 or game.camera.transform == camera_front:
        push_error("Studio camera preset did not rotate the view")
        quit(1)
        return
    studio._cycle_camera()
    if studio.camera_mode != 2 or game.camera.size < 11.0:
        push_error("Overhead product camera is not available")
        quit(1)
        return
    studio._cycle_camera()
    if studio.camera_mode != 0 or game.camera.transform != camera_front:
        push_error("Product-camera cycle failed to restore original view")
        quit(1)
        return

    # Cinematic gallery must hide the editing UI, never commit a touch and
    # reuse the *existing* body + stud buffers for its clear optical coat.
    var first_gallery_brick: Node3D = studio.brick_nodes[0]
    if first_gallery_brick.get_node_or_null("OpticalBody") != null \
            or first_gallery_brick.get_node_or_null("OpticalStuds") != null \
            or first_gallery_brick.get_node_or_null("PhotoShadowCaster") != null:
        push_error("Photo-only meshes were allocated before entering Gallery")
        quit(1)
        return
    studio._enter_photo_mode()
    var optical_shell: MeshInstance3D = first_gallery_brick.get_node_or_null(
        "OpticalBody")
    var optical_studs: MultiMeshInstance3D = first_gallery_brick.get_node_or_null(
        "OpticalStuds")
    var shadow_proxy: MeshInstance3D = first_gallery_brick.get_node_or_null(
        "PhotoShadowCaster")
    var native_shell: MeshInstance3D = first_gallery_brick.get_node("GelBody")
    var native_studs: MultiMeshInstance3D = first_gallery_brick.get_node("GelStuds")
    if optical_shell == null or optical_studs == null or shadow_proxy == null:
        push_error("Gallery did not allocate photo-only meshes on demand")
        quit(1)
        return
    if optical_shell.mesh != native_shell.mesh \
            or optical_studs.multimesh != native_studs.multimesh \
            or optical_shell.material_override != studio.gallery_coat \
            or not optical_shell.sorting_use_aabb_center \
            or not optical_studs.sorting_use_aabb_center:
        push_error("Photo clearcoat allocated duplicate meshes or materials")
        quit(1)
        return
    if shadow_proxy.mesh != native_shell.mesh \
            or shadow_proxy.material_override != studio.gallery_shadow_material \
            or shadow_proxy.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
            or not studio.gallery_shadow_key.shadow_enabled:
        push_error("Photo shadow proxy lost the shared rounded shell")
        quit(1)
        return
    if not studio.photo_mode or studio.hud.visible or not studio.photo_layer.visible \
            or studio.preview_node.visible or not optical_shell.visible \
            or not optical_studs.visible:
        push_error("Photo mode failed to hide editing controls or enable premium optics")
        quit(1)
        return
    var first_photo_paint: ShaderMaterial = first_gallery_brick.get_node(
        "GelBody").material_override
    if absf(float(first_photo_paint.get_shader_parameter("optical_depth")) - .93) > .001:
        push_error("Gallery photo mode failed to raise the optical absorption")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("gel_depth_optics")) - .90) > .001:
        push_error("Photo mode did not enhance the existing single-pass dyed gel")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("studio_light_card")) - 1.0) > .001:
        push_error("Gallery failed to enable the full product lightbox")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("studio_transmission")) - 1.0) > .001:
        push_error("Gallery is missing the video-directed inner light transmission")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("studio_interlock")) - 1.0) > .001:
        push_error("Gallery failed to enhance the contact meniscus")
        quit(1)
        return
    var gallery_floor: MeshInstance3D = game.get_node("StudioCyclorama")
    if absf(gallery_floor.position.y - (-.30)) > .001 \
            or studio.get_node("CandyStackStage/SatinPlinth").visible \
            or studio.get_node("CandyStackStage/SatinPlinthEdge").visible:
        push_error("Photo studio still shows distracting plinth edges")
        quit(1)
        return
    var gallery_contact: MeshInstance3D = studio.get_node(
        "CandyStackStage/StudioGroundContact")
    var gallery_shade: ShaderMaterial = gallery_contact.material_override
    if not studio.gallery_shadow_key.visible or not shadow_proxy.visible \
            or not gallery_contact.visible or absf(gallery_contact.position.y + .297) > .001 \
            or float(gallery_shade.get_shader_parameter("strength")) < .35 \
            or absf(float(studio.contact_material.get_shader_parameter("strength")) - .44) > .001:
        push_error("Photo gallery must combine real shadowing with visible soft ground contact")
        quit(1)
        return
    if absf(float(caustic_paint.get_shader_parameter("transmission_energy")) -
            1.0) > .001:
        push_error("The photo gallery failed to enhance actual transmitted Jelly color")
        quit(1)
        return
    # Lower eye angle and more focused frame are deliberate art direction:
    # otherwise the photo mode shows mainly brick crowns, unlike the
    # glossy rectangular sidewalls in the supplied Jelly Bricks video.
    var photo_target: float = maxf(1.20, studio._studio_height() * .38)
    var photo_raise: float = game.camera.position.y - photo_target
    var photo_radius: float = Vector2(game.camera.position.x,
        game.camera.position.z).length()
    var expected_photo_size: float = maxf(
        maxf(8.8, studio._studio_height() * 1.4 + 4.5),
        studio._photo_horizontal_frame_size())
    if absf(photo_raise - 5.8) > .05 \
            or absf(photo_radius - 12.4) > .05 \
            or absf(game.camera.size - expected_photo_size) > .05:
        push_error("Cinematic gallery reverted to high/top-heavy camera angle")
        quit(1)
        return
    var scene_before: int = studio.bricks.size()
    var before_photo_camera: Transform3D = game.camera.transform
    var angle_before: float = studio.photo_angle
    studio._process(.2)
    if absf(studio.photo_angle - angle_before - .028) > .0001:
        push_error("Gallery orbit loses time on low-FPS Android devices")
        quit(1)
        return
    if game.camera.transform == before_photo_camera or game.camera.size > 12.0:
        push_error("Photo turntable failed to frame and orbit the stacked sculpture")
        quit(1)
        return
    if studio.photo_pause_button.size_flags_horizontal \
            != Control.SIZE_SHRINK_END:
        push_error("Gallery Pause button expanded across the portrait header")
        quit(1)
        return
    studio._toggle_photo_pause()
    var frozen_angle: float = studio.photo_angle
    var frozen_transform: Transform3D = game.camera.transform
    studio._process(.2)
    if not studio.photo_paused or absf(studio.photo_angle - frozen_angle) > .00001 \
            or game.camera.transform != frozen_transform \
            or studio.photo_pause_button.text != "▶ Reprise":
        push_error("Gallery pause must freeze rotation for screenshots")
        quit(1)
        return
    studio._toggle_photo_pause()
    studio._process(.2)
    if studio.photo_paused or absf(studio.photo_angle - frozen_angle) < .02:
        push_error("Gallery resume must restore the previous orbit speed")
        quit(1)
        return
    var gallery_touch := InputEventScreenTouch.new()
    gallery_touch.index = 7
    gallery_touch.position = Vector2(360, 540)
    gallery_touch.pressed = true
    studio.handle_input(gallery_touch)
    var before_drag_angle: float = studio.photo_angle
    var gallery_drag := InputEventScreenDrag.new()
    gallery_drag.index = 7
    gallery_drag.position = Vector2(410, 540)
    gallery_drag.relative = Vector2(50, 0)
    studio.handle_input(gallery_drag)
    if is_equal_approx(studio.photo_angle, before_drag_angle):
        push_error("One-finger Gallery rotation did not respond to touch")
        quit(1)
        return
    var manual_angle: float = studio.photo_angle
    studio._process(.2)
    if not is_equal_approx(studio.photo_angle, manual_angle):
        push_error("Automatic orbit fought the user's active touch")
        quit(1)
        return
    # Two fingers zoom without committing or changing the authored stack.
    var second_gallery_touch := InputEventScreenTouch.new()
    second_gallery_touch.index = 8
    second_gallery_touch.position = Vector2(460, 540)
    second_gallery_touch.pressed = true
    studio.handle_input(second_gallery_touch)
    var pinch_drag := InputEventScreenDrag.new()
    pinch_drag.index = 8
    pinch_drag.position = Vector2(520, 540)
    pinch_drag.relative = Vector2(60, 0)
    studio.handle_input(pinch_drag)
    if studio.photo_zoom >= 1.0 or studio.photo_zoom < .70 \
            or game.camera.size >= 10.0:
        push_error("Two-finger Gallery pinch failed to zoom toward the Jelly")
        quit(1)
        return
    second_gallery_touch.pressed = false
    studio.handle_input(second_gallery_touch)
    gallery_touch.pressed = false
    studio.handle_input(gallery_touch)
    if studio.bricks.size() != scene_before or studio.active_touch_index != -1 \
            or not studio.photo_touch_points.is_empty() \
            or studio.photo_pinch_span != 0.0:
        push_error("Gallery gestures placed a brick or left stale touch state")
        quit(1)
        return
    # The Gallery should remain at the user's exact chosen view for 2.5 s
    # after fingers lift; only elapsed time beyond the timeout may rotate it.
    var resuming_angle: float = studio.photo_angle
    studio._process(2.4)
    if not is_equal_approx(studio.photo_angle, resuming_angle) \
            or studio.photo_resume_wait < 0.09:
        push_error("Gallery resumed too early after a touch/pinch gesture")
        quit(1)
        return
    studio._process(.2)
    if is_equal_approx(studio.photo_angle, resuming_angle) \
            or studio.photo_resume_wait > .0001:
        push_error("Gallery orbit did not resume after 2.5 seconds of inactivity")
        quit(1)
        return
    # Desktop testing needs the identical behavior for mouse drag/release.
    var gallery_mouse := InputEventMouseButton.new()
    gallery_mouse.button_index = MOUSE_BUTTON_LEFT
    gallery_mouse.pressed = true
    studio.handle_input(gallery_mouse)
    var mouse_motion := InputEventMouseMotion.new()
    mouse_motion.relative = Vector2(35.0, 0.0)
    studio.handle_input(mouse_motion)
    gallery_mouse.pressed = false
    studio.handle_input(gallery_mouse)
    var mouse_released_angle: float = studio.photo_angle
    studio._process(2.0)
    if not is_equal_approx(studio.photo_angle, mouse_released_angle):
        push_error("Gallery orbit resumed too early after mouse release")
        quit(1)
        return
    studio._process(.6)
    if is_equal_approx(studio.photo_angle, mouse_released_angle):
        push_error("Gallery orbit failed to resume after a mouse gesture")
        quit(1)
        return
    # The reference tower must obey the REAL support rules. It lives in a
    # separate scene graph and must never change player progress on disk.
    var verified_demo: Dictionary = SAVE_TRANSFER.validate_studio(
        studio._gallery_reference_entries())
    if not verified_demo.get("ok", false) \
            or verified_demo["bricks"].size() != 12:
        push_error("Nine-floor showcase failed to pass studio support validation")
        quit(1)
        return
    var personal_arrangement: String = JSON.stringify(studio.bricks)
    var saved_before_gallery: String = FileAccess.get_file_as_string(
        studio.SAVE_PATH) if FileAccess.file_exists(studio.SAVE_PATH) else ""
    # Keep a deliberately customized view to check the demo restores
    # the exact user's camera pose and pinch zoom without damaging saves.
    var personal_photo_angle: float = studio.photo_angle
    var personal_photo_zoom: float = studio.photo_zoom
    studio._toggle_gallery_demo()
    if not studio.gallery_demo_active or studio.gallery_demo_root == null \
            or studio.gallery_demo_nodes.size() != 12 \
            or studio.gallery_demo_entries.size() != 12 \
            or not studio.gallery_demo_root.visible \
            or studio.brick_nodes[0].visible \
            or studio.caustic_batch.multimesh.instance_count != 4 \
            or absf(studio._studio_height() - \
                (float(studio.MAX_LAYERS) * studio.STEP + .50)) > .01 \
            or not studio.gallery_shadow_key.visible \
            or studio.gallery_demo_button.text != "Ma pile":
        push_error("Reference Gallery did not render its real vertical tower")
        quit(1)
        return
    if absf(studio.photo_angle - .34) > .001 \
            or absf(studio.photo_zoom - 1.0) > .001 \
            or absf(game.camera.position.x - sin(.34) * 12.4) > .03:
        push_error("Reference tower lost its intentional three-quarter product camera")
        quit(1)
        return
    # Portrait QA must fit all three loose foreground bricks, regardless
    # of frame-rate-dependent orbit angle. A circular 3D footprint bounds
    # every projected horizontal extent without resizing as the camera turns.
    var full_reference_width: float = studio._photo_horizontal_frame_size()
    var studio_photo_size: float = game.camera.size
    if studio_photo_size + .001 < full_reference_width:
        push_error("Reference Gallery does not fit the real foreground brick widths")
        quit(1)
        return
    studio.photo_angle = 1.1
    studio._update_photo_camera()
    if absf(game.camera.size - studio_photo_size) > .001:
        push_error("Gallery camera zoom pulses as the tower rotates")
        quit(1)
        return
    studio.photo_angle = .34
    studio._update_photo_camera()
    for display_brick in studio.gallery_demo_nodes:
        var polished_paint: ShaderMaterial = display_brick.get_node(
            "GelBody").material_override
        if float(polished_paint.get_shader_parameter("studio_wet_edge")) < .90:
            push_error("Curated reference tower bypasses the actual wet-gel material")
            quit(1)
            return
        var photographed_entry: Dictionary = studio.gallery_demo_entries[
            studio.gallery_demo_nodes.find(display_brick)]
        if absf(float(polished_paint.get_shader_parameter("studio_interlock")) - 1.0) > .001 \
                or absf(float(polished_paint.get_shader_parameter("studio_stud_axis")) -
                    float(posmod(int(photographed_entry["turns"]), 2))) > .001:
            push_error("Reference tower lost physically oriented Jelly contact optics")
            quit(1)
            return
        if absf(float(polished_paint.get_shader_parameter("studio_transmission")) - 1.0) > .001:
            push_error("Reference tower lost its translucent dyed interior")
            quit(1)
            return
        if absf(float(polished_paint.get_shader_parameter("gel_depth_optics")) - .90) > .001:
            push_error("Reference tower lost its single-pass sidewall absorption")
            quit(1)
            return
    for i in range(studio.gallery_demo_entries.size()):
        var gallery_profile: Dictionary = studio._contact_profile(
            studio.gallery_demo_entries[i], studio.gallery_demo_entries)
        var gallery_paint: ShaderMaterial = studio.gallery_demo_nodes[i].get_node(
            "GelBody").material_override
        var gallery_dye: Color = gallery_paint.get_shader_parameter(
            "studio_contact_dye")
        if gallery_profile.is_empty():
            if gallery_dye.a > .001:
                push_error("Gallery loose candy incorrectly borrows a neighbor's dye")
                quit(1)
                return
        elif not gallery_dye.is_equal_approx(gallery_profile["dye"]):
            push_error("Reference tower lost adjacent pigment transmission")
            quit(1)
            return
    var foreground_poses: Array[Vector2i] = []
    for photo_entry in studio.gallery_demo_entries:
        if int(photo_entry["layer"]) == 0 and int(photo_entry["row"]) >= 4:
            foreground_poses.append(Vector2i(int(photo_entry["row"]),
                int(photo_entry["col"])))
    if foreground_poses.size() != 3 \
            or not foreground_poses.has(Vector2i(4, 0)) \
            or not foreground_poses.has(Vector2i(4, 4)) \
            or not foreground_poses.has(Vector2i(5, 2)):
        push_error("Reference scene foreground bricks are clipped or wrongly distributed")
        quit(1)
        return
    # The 12-piece curated reference must retain every lacquer layer;
    # only player-built scenes larger than the optical budget are thinned.
    for reference_piece in studio.gallery_demo_nodes:
        if not reference_piece.get_node("OpticalBody").visible \
                or not reference_piece.get_node("OpticalStuds").visible \
                or not reference_piece.get_node("PhotoShadowCaster").visible:
            push_error("Reference tower lost full gallery lacquer or shadows")
            quit(1)
            return
    if JSON.stringify(studio.bricks) != personal_arrangement \
            or FileAccess.get_file_as_string(studio.SAVE_PATH) != saved_before_gallery:
        push_error("Reference Gallery silently modified the player's own build")
        quit(1)
        return
    # Real reference-video animation: ground pieces must NEVER slide;
    # the upper tower sways coherently and only by a few centimeters.
    var swaying_top := -1
    var grounded_sample := -1
    for idx in range(studio.gallery_demo_entries.size()):
        var level: int = int(studio.gallery_demo_entries[idx]["layer"])
        if level == 0 and grounded_sample < 0:
            grounded_sample = idx
        if level == 8:
            swaying_top = idx
    if swaying_top < 0 or grounded_sample < 0:
        push_error("Gallery reference lost its support and nine-floor peak")
        quit(1)
        return
    var top_neutral: Vector3 = studio._world_position(
        studio.gallery_demo_entries[swaying_top])
    var ground_neutral: Vector3 = studio._world_position(
        studio.gallery_demo_entries[grounded_sample])
    studio._process(.25)
    var top_displacement: Vector3 = studio.gallery_demo_nodes[swaying_top].position
    var ground_displacement: Vector3 = studio.gallery_demo_nodes[grounded_sample].position
    if top_displacement.distance_to(top_neutral) < .006 \
            or top_displacement.distance_to(top_neutral) > .10 \
            or ground_displacement.distance_to(ground_neutral) > .0001 \
            or absf(top_displacement.y - top_neutral.y) > .0001:
        push_error("Elastic reference sway is absent, too strong or moves the base")
        quit(1)
        return
    var elastic_top: ShaderMaterial = studio.gallery_demo_nodes[
        swaying_top].get_node("GelBody").material_override
    var stationary_base: ShaderMaterial = studio.gallery_demo_nodes[
        grounded_sample].get_node("GelBody").material_override
    var live_breath: float = float(elastic_top.get_shader_parameter("studio_squash"))
    if absf(live_breath) < .04 \
            or absf(float(stationary_base.get_shader_parameter("studio_squash"))) > .0001:
        push_error("Reference Jelly has no soft upper-tier compression or deforms the footing")
        quit(1)
        return
    studio._toggle_photo_pause()
    var paused_position: Vector3 = studio.gallery_demo_nodes[swaying_top].position
    studio._process(.24)
    if not studio.photo_paused \
            or studio.gallery_demo_nodes[swaying_top].position.distance_to(
                paused_position) > .00001:
        push_error("Photo Pause must freeze the real Jelly reference tower")
        quit(1)
        return
    if absf(float(elastic_top.get_shader_parameter("studio_squash")) - live_breath) > .0001:
        push_error("Pausing Gallery did not freeze deformation of the gel volume")
        quit(1)
        return
    studio._toggle_photo_pause()
    studio._process(.23)
    if studio.photo_paused \
            or studio.gallery_demo_nodes[swaying_top].position.distance_to(
                paused_position) < .01:
        push_error("Resuming Gallery must resume the elastic tower movement")
        quit(1)
        return
    if JSON.stringify(studio.bricks) != personal_arrangement \
            or FileAccess.get_file_as_string(studio.SAVE_PATH) != saved_before_gallery:
        push_error("Animated reference tower changed the user's stored construction")
        quit(1)
        return
    print("TEST: coherent nine-floor Jelly spring motion, rooted base and photo pause")
    # Video-inspired destruction preview is explicitly opt-in. The real
    # save/occupancy must remain byte-for-byte unchanged while nine
    # temporary glossy bricks tip, detach and settle onto the photo floor.
    if studio.gallery_fall_button == null or not studio.gallery_fall_button.visible \
            or studio.gallery_fall_button.text != "↘ Chute":
        push_error("Real Jelly gallery has no replayable video-style collapse control")
        quit(1)
        return
    var neutral_gallery_camera_y: float = game.camera.position.y
    studio._start_gallery_fall()
    if not studio.gallery_fall_active or studio.gallery_fall_finished:
        push_error("Reference gallery failed to initiate temporary Jelly tumble")
        quit(1)
        return
    # The airborne crown must describe a genuine upward launch before
    # gravity wins. Impact compression must not fire while airborne.
    studio._apply_gallery_fall(.92)
    var flight_top: Node3D = studio.gallery_demo_nodes[swaying_top]
    var airborne_squash: float = float(flight_top.get_node(
        "GelBody").material_override.get_shader_parameter("studio_squash"))
    if flight_top.position.y <= top_neutral.y + .04 \
            or airborne_squash >= -.015:
        push_error("Reference Jelly lost its gravity arc or airborne stretch")
        quit(1)
        return
    studio._apply_gallery_fall(1.58)
    var falling_top: Node3D = studio.gallery_demo_nodes[swaying_top]
    if falling_top.position.y >= top_neutral.y - .35 \
            or falling_top.rotation.length() < .3 \
            or studio.gallery_demo_nodes[grounded_sample].position.distance_to(
                ground_neutral) > .0001:
        push_error("Jelly topple did not detach the crown or moved its planted base")
        quit(1)
        return
    var fall_pause_time: float = studio.gallery_fall_time
    var fall_pause_pose: Transform3D = falling_top.transform
    studio._toggle_photo_pause()
    studio._process(.25)
    if not studio.photo_paused \
            or absf(studio.gallery_fall_time - fall_pause_time) > .00001 \
            or falling_top.transform != fall_pause_pose:
        push_error("Photo Pause did not freeze active falling Jelly geometry")
        quit(1)
        return
    studio._toggle_photo_pause()
    studio._apply_gallery_fall(studio.GALLERY_FALL_DURATION)
    if not studio.gallery_fall_finished or studio.gallery_fall_active \
            or studio.gallery_fall_button.text != "↻ Rejouer":
        push_error("Jelly topple did not settle into a replayable final pose")
        quit(1)
        return
    studio._update_photo_camera()
    if game.camera.position.y > neutral_gallery_camera_y - .60:
        push_error("Photo camera failed to follow the colorful Jelly onto the floor")
        quit(1)
        return
    for idx in range(studio.gallery_demo_nodes.size()):
        var ref_entry: Dictionary = studio.gallery_demo_entries[idx]
        var fallen_piece: Node3D = studio.gallery_demo_nodes[idx]
        if int(ref_entry["layer"]) == 0:
            if fallen_piece.position.distance_to(studio._world_position(ref_entry)) > .0001:
                push_error("A loose reference brick shifted during optional collapse")
                quit(1)
                return
            continue
        var body_mesh: MeshInstance3D = fallen_piece.get_node("GelBody")
        var limits: AABB = body_mesh.mesh.get_aabb()
        # Test ACTUAL rotated 3D body corners against the physical floor,
        # rather than assuming rotation cannot cause ground penetration.
        for edge_x in [0.0, 1.0]:
            for edge_y in [0.0, 1.0]:
                for edge_z in [0.0, 1.0]:
                    var corner := limits.position + Vector3(
                        limits.size.x * edge_x,
                        limits.size.y * edge_y,
                        limits.size.z * edge_z)
                    if (fallen_piece.transform * corner).y < -.32:
                        push_error("Reference fall pushed a rotated Jelly shell through the studio floor")
                        quit(1)
                        return
        var skin: ShaderMaterial = body_mesh.material_override
        if absf(float(skin.get_shader_parameter("studio_squash"))) > .001:
            push_error("Settled fallen Jelly kept a permanently deformed skin")
            quit(1)
            return
    if JSON.stringify(studio.bricks) != personal_arrangement \
            or FileAccess.get_file_as_string(studio.SAVE_PATH) != saved_before_gallery:
        push_error("Gallery collapse modified the player's persisted construction")
        quit(1)
        return
    studio._start_gallery_fall()
    if not studio.gallery_fall_active or studio.gallery_fall_time != 0.0 \
            or falling_top.position.distance_to(top_neutral) > .0001:
        push_error("Replaying reference fall did not restore its exact neutral tower")
        quit(1)
        return
    print("TEST: replayable video-style Jelly fall, 3D floor clearance, pause, save isolation")
    studio._toggle_gallery_demo()
    if studio.gallery_sway_time != 0.0 \
            or studio.gallery_demo_nodes[swaying_top].position.distance_to(
                top_neutral) > .0001:
        push_error("Exiting animated Gallery left the reference tower deformed")
        quit(1)
        return
    if absf(float(elastic_top.get_shader_parameter("studio_squash"))) > .0001:
        push_error("Exiting Gallery retained a stretched Jelly tower material")
        quit(1)
        return
    if studio.gallery_demo_active or studio.gallery_demo_root.visible \
            or not studio.brick_nodes[0].visible \
            or studio.gallery_demo_button.text != "Vitrine" \
            or studio.caustic_batch.multimesh.instance_count != 3 \
            or absf(studio.photo_angle - personal_photo_angle) > .001 \
            or absf(studio.photo_zoom - personal_photo_zoom) > .001:
        push_error("Returning from demo did not restore the personal studio and camera")
        quit(1)
        return
    # Test the harder exit: user closes Photo *while* the demo is showing.
    studio._toggle_gallery_demo()
    studio._leave_photo_mode()
    if studio.gallery_demo_active or studio.gallery_demo_root != null \
            or not studio.gallery_demo_nodes.is_empty() \
            or not studio.gallery_demo_entries.is_empty() \
            or not studio.brick_nodes[0].visible \
            or studio.caustic_batch.multimesh.instance_count != 3 \
            or JSON.stringify(studio.bricks) != personal_arrangement:
        push_error("Exiting demo Photo leaked preview meshes or lost personal bricks")
        quit(1)
        return
    if absf(float(caustic_paint.get_shader_parameter("transmission_energy")) -
            .74) > .001:
        push_error("Gallery caustic intensity leaked into normal mobile play")
        quit(1)
        return
    print("TEST: validated 9-floor demo, personal build untouched, reversible photo gallery")
    if studio.photo_mode or studio.photo_layer.visible or not studio.hud.visible \
            or optical_shell.visible or optical_studs.visible \
            or not studio.preview_node.visible \
            or game.camera.transform != camera_front:
        push_error("Leaving photo mode failed to restore low-cost playable studio")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("optical_depth")) - .54) > .001 \
            or absf(float(first_photo_paint.get_shader_parameter("gel_depth_optics")) - .78) > .001 \
            or absf(float(studio.contact_material.get_shader_parameter("strength")) - .35) > .001:
        push_error("Leaving Gallery did not restore the mobile optical/contact settings")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("studio_light_card")) - .88) > .001:
        push_error("Gallery product lightbox strength leaked into Android editing")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("studio_transmission")) - .86) > .001:
        push_error("Photo-only transmission effect leaked into mobile editing")
        quit(1)
        return
    if absf(float(first_photo_paint.get_shader_parameter("studio_interlock")) - .84) > .001:
        push_error("Photo meniscus intensity leaked into live stacking mode")
        quit(1)
        return
    if absf(gallery_floor.position.y - studio.photo_floor_before) > .001 \
            or not studio.get_node("CandyStackStage/SatinPlinth").visible \
            or not studio.get_node("CandyStackStage/SatinPlinthEdge").visible:
        push_error("Leaving Gallery did not restore the construction pedestal")
        quit(1)
        return
    if shadow_proxy.visible or studio.gallery_shadow_key.visible \
            or not gallery_contact.visible \
            or float(gallery_shade.get_shader_parameter("strength")) > .25:
        push_error("Photo light or stronger photo-only contact remains active after exit")
        quit(1)
        return
    # Stress test the photo-only GPU budget without altering the player's
    # six actual bricks, geometry, occupancy or save. Past 14 objects
    # the soft fake contact must replace directional shadow atlas passes.
    var original_brick_count: int = studio.brick_nodes.size()
    for unused in range(studio.MAX_GALLERY_SHADOW_BRICKS + 1 -
            original_brick_count):
        studio.brick_nodes.append(first_gallery_brick)
    studio._enter_photo_mode()
    var large_shadow: MeshInstance3D = studio.get_node(
        "CandyStackStage/StudioGroundContact")
    if studio.gallery_shadow_key.visible or shadow_proxy.visible \
            or not large_shadow.visible or absf(large_shadow.position.y + .297) > .001:
        push_error("Large gallery failed to substitute bounded fake contact shadows")
        quit(1)
        return
    studio._leave_photo_mode()
    studio.brick_nodes.resize(original_brick_count)
    if studio.gallery_shadow_key.visible or shadow_proxy.visible \
            or absf(large_shadow.position.y + .545) > .001:
        push_error("Large photo fallback did not restore original shadow resources")
        quit(1)
        return
    # Exercise a genuinely independent 32-piece set, not 32 references to
    # one mesh node (which would mask a per-object optical budget regression).
    # No synthetic brick enters the live scene or a player save.
    var gallery_synthetic: Array[Node3D] = []
    for synthetic_index in range(studio.MAX_BRICKS - original_brick_count):
        var synthetic: Node3D = studio._build_piece(
            studio.bricks[synthetic_index % studio.bricks.size()], false)
        # Equal footprint/orientation MUST reuse the exact same GPU mesh.
        var original_piece: Node3D = studio.brick_nodes[
            synthetic_index % original_brick_count]
        var original_patch: MeshInstance3D = original_piece.get_node("GelContact")
        var repeated_patch: MeshInstance3D = synthetic.get_node("GelContact")
        if original_patch.mesh != repeated_patch.mesh:
            push_error("Studio allocated duplicate contact-shadow meshes for one footprint")
            quit(1)
            return
        if synthetic.get_child_count() != 3 \
                or synthetic.get_node_or_null("OpticalBody") != null \
                or synthetic.get_node_or_null("OpticalStuds") != null \
                or synthetic.get_node_or_null("PhotoShadowCaster") != null:
            push_error("32-brick playable studio still allocates dormant Gallery GPU nodes")
            quit(1)
            return
        gallery_synthetic.append(synthetic)
        studio.brick_nodes.append(synthetic)
    studio._set_gallery_coat(true)
    var visible_body_coats: int = 0
    var visible_stud_coats: int = 0
    var first_coated: int = studio.brick_nodes.size() - studio.MAX_GALLERY_COATED_BRICKS
    for index in range(studio.brick_nodes.size()):
        var inspected: Node3D = studio.brick_nodes[index]
        var body_coat: MeshInstance3D = inspected.get_node_or_null("OpticalBody")
        var stud_coat: MultiMeshInstance3D = inspected.get_node_or_null("OpticalStuds")
        var shadow_coat: MeshInstance3D = inspected.get_node_or_null(
            "PhotoShadowCaster")
        var body_visible: bool = body_coat != null and body_coat.visible
        if body_visible:
            visible_body_coats += 1
        if stud_coat != null and stud_coat.visible:
            visible_stud_coats += 1
        if body_visible != (index >= first_coated):
            push_error("Large Gallery coated wrong bricks instead of newest upper layers")
            quit(1)
            return
        if index >= original_brick_count and index < first_coated \
                and (body_coat != null or stud_coat != null or shadow_coat != null):
            push_error("Large Android Gallery allocated photo meshes below the LOD cutoff")
            quit(1)
            return
        if index >= original_brick_count and index >= first_coated \
                and (body_coat == null or stud_coat != null or shadow_coat != null):
            push_error("Large Gallery created unnecessary stud coats or shadow casters")
            quit(1)
            return
        var underlying_body: MeshInstance3D = inspected.get_node("GelBody")
        var underlying_paint: ShaderMaterial = underlying_body.material_override
        if absf(float(underlying_paint.get_shader_parameter("optical_depth")) - .93) > .001:
            push_error("Reduced clearcoat also weakened the underlying Jelly material")
            quit(1)
            return
        if absf(float(underlying_paint.get_shader_parameter("gel_depth_optics")) - .90) > .001:
            push_error("Large Gallery lost native one-pass dyed-depth material")
            quit(1)
            return
        if absf(float(underlying_paint.get_shader_parameter("studio_light_card")) - 1.0) > .001:
            push_error("Large Gallery lost its non-overdraw studio lightbox reflection")
            quit(1)
            return
        if absf(float(underlying_paint.get_shader_parameter("studio_transmission")) - 1.0) > .001:
            push_error("Large Gallery lost translucent Jelly in the original draw pass")
            quit(1)
            return
        if absf(float(underlying_paint.get_shader_parameter("studio_interlock")) - 1.0) > .001:
            push_error("Large Gallery lost its one-pass Jelly interlock shading")
            quit(1)
            return
    if visible_body_coats != studio.MAX_GALLERY_COATED_BRICKS \
            or visible_stud_coats != 0 or studio.gallery_shadow_key.visible:
        push_error("Large Android Gallery exceeded its bounded lacquer/shadow draw budget")
        quit(1)
        return
    studio._set_gallery_coat(false)
    for brick in studio.brick_nodes:
        var body_shell: MeshInstance3D = brick.get_node_or_null("OpticalBody")
        var stud_shell: MultiMeshInstance3D = brick.get_node_or_null("OpticalStuds")
        var shadow_shell: MeshInstance3D = brick.get_node_or_null(
            "PhotoShadowCaster")
        if (body_shell != null and body_shell.visible) \
                or (stud_shell != null and stud_shell.visible) \
                or (shadow_shell != null and shadow_shell.visible):
            push_error("Gallery optical meshes still draw during interactive play")
            quit(1)
            return
    for temporary_piece in gallery_synthetic:
        temporary_piece.free()
    studio.brick_nodes.resize(original_brick_count)
    print("TEST: 32-brick Gallery caps lacquer at 18 bodies, zero studs and zero shadows")
    print("TEST: native shadow-map gallery, shared shadow-only hull and GPU-budget fallback")
    print("TEST: cinematic turntable, clearcoat mesh reuse and safe photo-mode exit")

    # A touch drag must reuse the same glint mesh, studs and material. Old
    # behavior built and queued a complete 3D brick on every finger event.
    var reused_preview: Node3D = studio.preview_node
    if reused_preview == null or reused_preview.get_node_or_null("GelContact") != null:
        push_error("Studio preview missing or incorrectly casting floor shadows")
        quit(1)
        return
    studio.selected_cell = Vector2i(3, 2)
    studio._refresh_preview()
    if studio.preview_node != reused_preview:
        push_error("Dragging a candy piece rebuilt its complete 3D ghost")
        quit(1)
        return
    studio._choose_color(4)
    if studio.preview_node != reused_preview or studio.preview_signature.is_empty():
        push_error("Changing candy tint needlessly reallocated its geometry")
        quit(1)
        return
    if studio.preview_node.get_node_or_null("OpticalBody") != null \
            or studio.preview_node.get_node_or_null("OpticalStuds") != null:
        push_error("Android ghost unnecessarily allocates hidden Gallery-only optical meshes")
        quit(1)
        return
    var ghost_optics: ShaderMaterial = studio.preview_node.get_node("GelBody").material_override
    if not studio.preview_node.get_node("GelBody").sorting_use_aabb_center \
            or not studio.preview_node.get_node("GelStuds").sorting_use_aabb_center:
        push_error("Android studio placement ghost is transparently sorted from a corner")
        quit(1)
        return
    if float(ghost_optics.get_shader_parameter("studio_glass")) < .95:
        push_error("Translucent studio ghost has lost its gel refraction cues")
        quit(1)
        return
    if float(ghost_optics.get_shader_parameter("studio_pigment")) > .79 \
            or float(ghost_optics.get_shader_parameter("gel_opacity")) > .5:
        push_error("Studio ghost is no longer distinguishable from solid jelly")
        quit(1)
        return
    if float(ghost_optics.get_shader_parameter("studio_finish")) > .55:
        push_error("Placement ghost wrongly shares the fully opaque candy finish")
        quit(1)
        return
    if float(ghost_optics.get_shader_parameter("studio_wet_edge")) > .20:
        push_error("Translucent studio placement ghost became a bright solid")
        quit(1)
        return
    if float(ghost_optics.get_shader_parameter("optical_depth")) > .20:
        push_error("Unplaced ghost is too optically dense for accurate Android placement")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("gel_depth_optics"))) > .001:
        push_error("Placement ghost incorrectly inherited dense opaque-sidewall optics")
        quit(1)
        return
    var ghost_contact: Color = ghost_optics.get_shader_parameter(
        "studio_contact_dye")
    if ghost_contact.a > .001:
        push_error("Placement ghost incorrectly inherits contact pigment transmission")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("studio_light_card"))) > .001:
        push_error("Placement ghost received an opaque studio reflection window")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("studio_interlock"))) > .001:
        push_error("Placement ghost received opaque molded-gel stud collars")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("studio_transmission"))) > .001:
        push_error("Placement ghost inherited the solid-body transmission effect")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("studio_pressure_strength"))) > .001:
        push_error("Placement ghost wrongly inherited solid-gel pressure dents")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("studio_strain_optics"))) > .001:
        push_error("Placement ghost inherited solid optical strain")
        quit(1)
        return
    if absf(float(ghost_optics.get_shader_parameter("studio_squash"))) > .001:
        push_error("Transparent placement ghost inherited solid impact deformation")
        quit(1)
        return
    studio.preview_motion_energy = .34
    ghost_optics.set_shader_parameter("gel_spring", .34)
    studio._process(.1)
    var drag_energy: float = float(ghost_optics.get_shader_parameter("gel_spring"))
    if drag_energy >= .34 or drag_energy <= 0.0:
        push_error("Dragged Jelly ghost has no transient finger wobble")
        quit(1)
        return
    # GDQuest-inspired damping must be time-based, not frame-count-based.
    # Two .05 s updates and one .10 s update should give the same result.
    studio.preview_motion_energy = .48
    studio._process(.1)
    var one_tick: float = float(ghost_optics.get_shader_parameter("gel_spring"))
    studio.preview_motion_energy = .48
    studio._process(.05)
    studio._process(.05)
    var two_ticks: float = float(ghost_optics.get_shader_parameter("gel_spring"))
    if absf(one_tick - two_ticks) > .003 \
            or one_tick < .26 or one_tick > .30:
        push_error("Android ghost damping changes with frame rate")
        quit(1)
        return
    # A fast two-cell swipe creates a bounded directional lag. It must
    # follow the physical X/Z axis and settle with no permanent deformation.
    studio._apply_preview_drag(Vector2i(2, 1), Vector2i(2, 3))
    var initial_drag: Vector2 = ghost_optics.get_shader_parameter("studio_drag")
    if initial_drag.distance_to(Vector2(1.0, 0.0)) > .001 \
            or studio.preview_motion_energy > .65:
        push_error("Studio ghost has no bounded horizontal finger inertia")
        quit(1)
        return
    studio._process(.1)
    var decaying_drag: Vector2 = ghost_optics.get_shader_parameter("studio_drag")
    if decaying_drag.length() >= initial_drag.length() \
            or decaying_drag.length() <= .0:
        push_error("Studio ghost did not ease away from last finger position")
        quit(1)
        return
    # A northward finger move must bend on world Z, not X. Confirm the
    # vector is reset without replacing the ghost material.
    studio._apply_preview_drag(Vector2i(3, 3), Vector2i(1, 3))
    if ghost_optics.get_shader_parameter("studio_drag") != Vector2(0.0, -1.0):
        push_error("Vertical studio swipe incorrectly bends the Jelly on X")
        quit(1)
        return
    studio._reset_preview_inertia()
    if studio.preview_drag_bend != Vector2.ZERO \
            or ghost_optics.get_shader_parameter("studio_drag") != Vector2.ZERO:
        push_error("Cancelled studio swipe left a deformed ghost")
        quit(1)
        return
    studio._apply_preview_drag(Vector2i(2, 1), Vector2i(2, 3))
    for _settle_preview in range(12):
        studio._process(.1)
    if studio.preview_motion_energy > .001 \
            or studio.preview_drag_bend != Vector2.ZERO \
            or absf(float(ghost_optics.get_shader_parameter("gel_spring"))) > .001 \
            or ghost_optics.get_shader_parameter("studio_drag") != Vector2.ZERO:
        push_error("Jelly ghost motion failed to settle after the finger stops")
        quit(1)
        return
    studio.selected_cell = Vector2i(2, 1)
    studio._refresh_preview()

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
    if studio.active_touch_index != 5 or studio.bricks.size() != 6 \
            or not studio.play_multitouch_blocked \
            or studio.preview_drag_bend != Vector2.ZERO:
        push_error("Second finger did not disarm the original stacking drag")
        quit(1)
        return
    # A non-cancelled first-finger release after a second finger has lifted
    # must ALSO be suppressed, otherwise a pinch can accidentally drop Jelly.
    finger_first.pressed = false
    studio.handle_input(finger_first)
    if studio.active_touch_index != -1 or studio.bricks.size() != 6 \
            or studio.play_multitouch_blocked \
            or not studio.play_touch_contacts.is_empty():
        push_error("Two-finger stacking gesture accidentally committed a Jelly brick")
        quit(1)
        return
    finger_first.pressed = true
    studio.handle_input(finger_first)
    if studio.active_touch_index != 5:
        push_error("Stacking did not re-arm after all fingers lifted")
        quit(1)
        return
    finger_first.pressed = false
    finger_first.canceled = true
    studio.handle_input(finger_first)
    if studio.active_touch_index != -1 or studio.bricks.size() != 6 \
            or not studio.play_touch_contacts.is_empty():
        push_error("Cancelled mobile touch should not place a stack brick")
        quit(1)
        return
    # Impact contact coordinates must follow actual shared cells, even
    # when a long brick is supported only at its far tip or rotated 90°.
    var bar_x: Dictionary = studio._entry(2, 2, 2, 0, 0, 1)
    var tip_x: Dictionary = studio._entry(2, 4, 0, 0, 0, 0)
    var bar_z: Dictionary = studio._entry(1, 1, 2, 1, 0, 1)
    var tip_z: Dictionary = studio._entry(3, 1, 0, 0, 0, 0)
    if not studio._wave_center_on(bar_x, tip_x).is_equal_approx(
            Vector2(2.5, .5)) \
            or not studio._wave_center_on(bar_z, tip_z).is_equal_approx(
                Vector2(.5, 2.5)) \
            or not studio._wave_center_on(bar_x, {}).is_equal_approx(
                Vector2(1.5, .5)):
        push_error("Local gel impact is not placed at the real support overlap")
        quit(1)
        return
    # Multiple direct supports blend by occupied-cell count, not an
    # arbitrary world-space proximity to neighboring colored bricks.
    var optical_upper: Dictionary = studio._entry(1, 1, 2, 0, 0, 1)
    var optical_left: Dictionary = studio._entry(1, 1, 0, 0, 1, 0)
    var optical_right: Dictionary = studio._entry(1, 3, 0, 0, 2, 0)
    var direct_supports: Array[Dictionary] = [optical_left, optical_right]
    var unrelated_supports: Array[Dictionary] = [
        studio._entry(1, 1, 0, 0, 1, 3)]
    var optical_profile: Dictionary = studio._contact_profile(
        optical_upper, direct_supports)
    var unrelated_profile: Dictionary = studio._contact_profile(
        optical_upper, unrelated_supports)
    var expected_mix: Color = Color(studio.COLORS[1]).lerp(
        Color(studio.COLORS[2]), .5)
    if optical_profile.is_empty() or not unrelated_profile.is_empty() \
            or not optical_profile["center"].is_equal_approx(
                Vector2(1.5, .5)) \
            or int(optical_profile.get("supported_cells", -1)) != 2 \
            or absf(float(optical_profile.get("support_fraction", -1.0)) -
                2.0 / 3.0) > .001 \
            or absf(optical_profile["dye"].r - expected_mix.r) > .002 \
            or absf(optical_profile["dye"].g - expected_mix.g) > .002 \
            or absf(optical_profile["dye"].b - expected_mix.b) > .002:
        push_error("Multiple contact cells failed to resolve a centered impact and dye")
        quit(1)
        return
    # In a REAL commit, support iteration order must not bias where a
    # three-cell Jelly bar compresses. Two single-cell ground supports at
    # opposite ends are enough to hold the bridge (2/3 coverage). Old
    # behavior incorrectly emitted the wave at x=.5 (first support).
    var bridge_setup: Array[Dictionary] = [
        studio._entry(1, 1, 0, 0, 1, 0),
        studio._entry(1, 3, 0, 0, 2, 0)]
    if not studio._load_entries(bridge_setup):
        push_error("Valid spaced ground supports could not be loaded")
        quit(1)
        return
    studio._rebuild()
    studio.selected_cell = Vector2i(1, 1)
    studio.selected_length = 2
    studio.selected_turns = 0
    studio._commit()
    if studio.bricks.size() != 3 or int(studio.bricks[2]["layer"]) != 1:
        push_error("Bridge of two support cells did not form a legal stack")
        quit(1)
        return
    var bridge_paint: ShaderMaterial = studio.brick_nodes[2].get_node(
        "GelBody").material_override
    var bridge_wave_center: Vector2 = bridge_paint.get_shader_parameter(
        "studio_wave_center")
    var bridge_wave_gain: float = float(bridge_paint.get_shader_parameter(
        "studio_wave_gain"))
    if not bridge_wave_center.is_equal_approx(Vector2(1.5, .5)) \
            or absf(bridge_wave_gain - .90) > .005 \
            or absf(float(bridge_paint.get_shader_parameter(
                "studio_wave_phase"))) > .001:
        push_error("Multi-support Jelly landing has an off-centre or premature impulse")
        quit(1)
        return
    studio._stop_motion()
    if bridge_paint.get_shader_parameter("studio_wave_gain") != 0.0:
        push_error("Interrupting a two-support ripple left residual deformation")
        quit(1)
        return
    studio._reset()
    if not studio.bricks.is_empty() or caustic.multimesh.instance_count != 0:
        push_error("Stack reset left ghost caustics on the empty floor")
        quit(1)
        return
    studio.selected_cell = Vector2i(2, 2)
    studio.selected_length = 2
    studio._commit()
    if studio.bricks.size() != 1 or not studio.occupancy.has(Vector3i(2, 2, 0)):
        push_error("First stacked 3D brick was not placed on the plinth")
        quit(1)
        return
    if caustic.multimesh.instance_count != 0:
        push_error("Airborne ground Jelly illuminated the floor before contact")
        quit(1)
        return
    studio.selected_length = 0
    studio._commit()
    if studio.bricks.size() != 2 or int(studio.bricks[1]["layer"]) != 1:
        push_error("Second brick did not snap onto the first")
        quit(1)
        return
    if caustic.multimesh.instance_count != 1:
        push_error("Upper Jelly wrongly projected light on the ground")
        quit(1)
        return
    # The landing is delayed by .29 s. Realtime Tween timers are
    # checked by the separate impact_feedback.gd integration test.
    if game.candy_fx.landing_cursor != 0:
        push_error("Studio emitted feedback before the contact")
        quit(1)
        return
    var contact_supports: Array[int] = studio._support_indices(studio.bricks[1])
    if contact_supports != [0] or studio.motion_tweens.size() < 2 \
            or studio.brick_nodes.size() != 2:
        push_error("New candy landing failed to transmit a spring into its support")
        quit(1)
        return
    var top_gel: ShaderMaterial = studio.brick_nodes[1].get_node("GelBody").material_override
    var base_gel: ShaderMaterial = studio.brick_nodes[0].get_node("GelBody").material_override
    if float(top_gel.get_shader_parameter("gel_spring")) < .95 \
            or absf(float(base_gel.get_shader_parameter("gel_spring"))) > .001:
        push_error("Supporting Jelly reacted before the falling brick made contact")
        quit(1)
        return
    # Real landing compression is delayed until the falling brick reaches
    # the studs. Test its positive squeeze, negative elastic overshoot,
    # smaller impulse transmitted downward and exact final resting state.
    if studio.motion_tweens.size() < 5 \
            or absf(float(top_gel.get_shader_parameter("studio_squash"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_squash"))) > .001:
        push_error("Jelly deformed before the brick touched its support")
        quit(1)
        return
    if studio.motion_tweens.size() < 9 \
            or absf(float(top_gel.get_shader_parameter("studio_wave_phase"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_wave_phase"))) > .001 \
            or absf(float(top_gel.get_shader_parameter("studio_jiggle_phase"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_jiggle_phase"))) > .001 \
            or float(top_gel.get_shader_parameter("studio_wave_gain")) < .85 \
            or float(base_gel.get_shader_parameter("studio_wave_gain")) >= .55 \
            or float(top_gel.get_shader_parameter("studio_jiggle_gain")) < .85 \
            or float(base_gel.get_shader_parameter("studio_jiggle_gain")) >= .65 \
            or not Vector2(top_gel.get_shader_parameter(
                "studio_wave_center")).is_equal_approx(Vector2(.5, .5)) \
            or not Vector2(base_gel.get_shader_parameter(
                "studio_wave_center")).is_equal_approx(Vector2(.5, .5)):
        push_error("Jelly contact wave is early, misplaced or stronger below than above")
        quit(1)
        return
    var upper_rebound: Tween = studio.motion_tweens[1]
    var lower_spring: Tween = studio.motion_tweens[2]
    var lower_rebound: Tween = studio.motion_tweens[3]
    var lower_wave: Tween = studio.motion_tweens[5]
    var lower_jiggle: Tween = studio.motion_tweens[6]
    var upper_wave: Tween = studio.motion_tweens[7]
    var upper_jiggle: Tween = studio.motion_tweens[8]
    upper_rebound.custom_step(.37)
    lower_rebound.custom_step(.37)
    lower_spring.custom_step(.37)
    lower_wave.custom_step(.37)
    upper_wave.custom_step(.37)
    lower_jiggle.custom_step(.37)
    upper_jiggle.custom_step(.37)
    var crest_upper: float = float(top_gel.get_shader_parameter("studio_wave_phase"))
    var crest_lower: float = float(base_gel.get_shader_parameter("studio_wave_phase"))
    var slow_upper: float = float(top_gel.get_shader_parameter("studio_jiggle_phase"))
    var slow_lower: float = float(base_gel.get_shader_parameter("studio_jiggle_phase"))
    if crest_upper < .08 or crest_upper > .25 \
            or crest_lower < .08 or crest_lower > .25 \
            or slow_upper < .05 or slow_upper > .14 \
            or slow_lower < .05 or slow_lower > .14:
        push_error("Local wavefront did not propagate after the .29s impact")
        quit(1)
        return
    if float(base_gel.get_shader_parameter("gel_spring")) < .08:
        push_error("Contact shock failed to travel down to the supporting Jelly")
        quit(1)
        return
    var upper_pressure: float = float(top_gel.get_shader_parameter("studio_squash"))
    var lower_pressure: float = float(base_gel.get_shader_parameter("studio_squash"))
    if upper_pressure < .76 or lower_pressure < .12 \
            or lower_pressure >= upper_pressure:
        push_error("Landing Jelly failed to squeeze more than its supporting tier")
        quit(1)
        return
    upper_rebound.custom_step(.18)
    if float(top_gel.get_shader_parameter("studio_squash")) > -.20:
        push_error("Jelly rebound does not overshoot its original volume")
        quit(1)
        return
    upper_rebound.custom_step(1.0)
    lower_rebound.custom_step(1.0)
    lower_spring.custom_step(1.0)
    lower_wave.custom_step(1.0)
    upper_wave.custom_step(1.0)
    # The fast ring is gone by now, but the low-frequency body wobble
    # persists independently for almost twice as long.
    if float(top_gel.get_shader_parameter("studio_jiggle_phase")) <= .04 \
            or float(top_gel.get_shader_parameter("studio_jiggle_gain")) < .85:
        push_error("Studio Jelly stopped wobbling when the contact ring ended")
        quit(1)
        return
    lower_jiggle.custom_step(1.08)
    upper_jiggle.custom_step(1.08)
    if absf(float(top_gel.get_shader_parameter("studio_jiggle_phase"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_jiggle_phase"))) > .001 \
            or absf(float(top_gel.get_shader_parameter("studio_jiggle_gain"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_jiggle_gain"))) > .001:
        push_error("Viscous post-impact wobble did not damp to the exact rest pose")
        quit(1)
        return
    if absf(float(top_gel.get_shader_parameter("studio_wave_phase"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_wave_phase"))) > .001 \
            or absf(float(top_gel.get_shader_parameter("studio_wave_gain"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_wave_gain"))) > .001:
        push_error("Jelly contact wave did not settle completely")
        quit(1)
        return
    if absf(float(top_gel.get_shader_parameter("studio_squash"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_squash"))) > .001:
        push_error("Viscoelastic impulse did not return to a resting Jelly volume")
        quit(1)
        return
    studio._stop_motion()
    if float(top_gel.get_shader_parameter("gel_spring")) != 0.0 \
            or float(base_gel.get_shader_parameter("gel_spring")) != 0.0 \
            or absf(float(top_gel.get_shader_parameter("studio_squash"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_squash"))) > .001 \
            or absf(float(top_gel.get_shader_parameter("studio_wave_gain"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_wave_gain"))) > .001 \
            or absf(float(top_gel.get_shader_parameter("studio_jiggle_gain"))) > .001 \
            or absf(float(base_gel.get_shader_parameter("studio_jiggle_gain"))) > .001:
        push_error("Cancelling a transition left physically deformed Jelly behind")
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
    if not studio.bricks.is_empty() or not studio.motion_tweens.is_empty() \
            or not studio.brick_nodes.is_empty():
        push_error("Stack undo left a stale wobble or suspended brick")
        quit(1)
        return
    # Grow a full-height tower: the camera must zoom out before the 9th
    # stack layer is cropped on small portrait Android screens.
    studio.selected_length = 0
    studio.selected_cell = Vector2i(2, 2)
    for _tower_layer in range(9):
        studio._commit()
    if studio.bricks.size() != 9 or game.camera.size <= 12.5:
        push_error("Tall Jelly tower was clipped or failed to build")
        quit(1)
        return
    studio._reset()
    if not studio.bricks.is_empty() or game.camera.size > 12.5:
        push_error("Blank studio did not restore the original product framing")
        quit(1)
        return
    # Phone screenshot regression: blank upper space should not force a
    # real four-layer sculpture against the bottom HUD. The close default
    # camera's world-space aim is now below the old fixed y=1.6.
    if absf(game.camera.size - 9.90) > .005 \
            or absf(game.camera.position.y - 7.65) > .05:
        push_error("Studio reverted to distant and low-framed product camera")
        quit(1)
        return
    # Regression: a crashed native write can leave malformed primary JSON.
    # Recover the structurally valid backup and never rotate the broken
    # primary over it on the first subsequent player action.
    studio._seed_showcase()
    if not studio._save():
        push_error("Could not stage the real six-brick studio recovery fixture")
        quit(1)
        return
    var studio_known_good: String = FileAccess.get_file_as_string(studio.SAVE_PATH)
    var studio_baseline: String = JSON.stringify(studio._export_entries())
    var verified_studio: Dictionary = studio._read_valid_studio_file(studio.SAVE_PATH)
    if not verified_studio.get("ok", false) or verified_studio["bricks"].size() != 6:
        push_error("Studio primary file did not pass strict structural validation")
        quit(1)
        return
    var studio_backup: FileAccess = FileAccess.open(
        studio.SAVE_PATH + ".bak", FileAccess.WRITE)
    if studio_backup == null:
        push_error("Cannot stage known-good studio backup")
        quit(1)
        return
    studio_backup.store_string(studio_known_good)
    studio_backup.close()
    var studio_truncated: FileAccess = FileAccess.open(studio.SAVE_PATH, FileAccess.WRITE)
    studio_truncated.store_string("{\"schema\":1,\"bricks\":[")
    studio_truncated.close()
    if not studio._read_valid_studio_file(studio.SAVE_PATH).is_empty():
        push_error("Truncated studio save passed JSON validation")
        quit(1)
        return
    studio.bricks.clear()
    studio._restore_or_seed()
    if JSON.stringify(studio._export_entries()) != studio_baseline \
            or not studio._save() \
            or FileAccess.get_file_as_string(studio.SAVE_PATH + ".bak") != studio_known_good:
        push_error("Studio crash recovery lost bricks or overwrote safe backup")
        quit(1)
        return
    # Also reject *parseable* JSON with a fabricated unsupported layer.
    # It must not silently turn the player's personal sculpture into
    # the default six-brick seed, which can resemble a valid saved scene.
    var malformed_studio: Dictionary = JSON.parse_string(studio_known_good)
    malformed_studio["bricks"][0]["layer"] = 8
    var tampered_file: FileAccess = FileAccess.open(studio.SAVE_PATH, FileAccess.WRITE)
    tampered_file.store_string(JSON.stringify(malformed_studio))
    tampered_file.close()
    if not studio._read_valid_studio_file(studio.SAVE_PATH).is_empty():
        push_error("Impossible upper-layer Jelly was treated as valid studio progress")
        quit(1)
        return
    studio.bricks.clear()
    studio._restore_or_seed()
    if JSON.stringify(studio._export_entries()) != studio_baseline \
            or not studio._save() \
            or FileAccess.get_file_as_string(studio.SAVE_PATH + ".bak") != studio_known_good \
            or FileAccess.file_exists(studio.SAVE_PATH + ".tmp"):
        push_error("Studio semantic backup recovery did not survive next autosave")
        quit(1)
        return
    studio._rebuild()
    studio._reset()
    print("TEST: studio save restores valid backup after truncated or impossible JSON")
    print("TEST: animated gel material springs, grounded product stage, nine-layer auto framing")
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
    var pitch_voice: AudioStreamPlayer = game.audio_voices[
        game.audio_voice_cursor % game.audio_voices.size()]
    game._play_feedback("place", 0, .89)
    if absf(pitch_voice.pitch_scale - .89) > .001:
        push_error("Heavier Jelly lost its lower-pitched synthesized contact sound")
        quit(1)
        return
    var restored_voice: AudioStreamPlayer = game.audio_voices[
        game.audio_voice_cursor % game.audio_voices.size()]
    game._play_feedback("select")
    if absf(restored_voice.pitch_scale - 1.0) > .001:
        push_error("Pooled Jelly audio inherited pitch from a preceding heavy brick")
        quit(1)
        return
    print("TEST: synthesized PCM, pooled sounds, mass-aware pitch and FX opt-out")
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
        # Small reference models used only a tiny patch of their large panel,
        # while 7x7 models could overflow. Check actual per-level dimensions.
        var reference_cell: int = game._reference_cell_size(game.size)
        var reference_extent: int = game.size * reference_cell + \
            3 * (game.size - 1)
        var drawn_reference: Control = game.model_grid.get_child(
            game.model_grid.get_child_count() - 1)
        if reference_cell < 18 or reference_cell > 34 \
                or reference_extent > 146 \
                or absf(drawn_reference.custom_minimum_size.x -
                    float(reference_cell)) > .01 \
                or absf(drawn_reference.custom_minimum_size.y -
                    float(reference_cell)) > .01:
            push_error("Mobile reference model overflows or wastes portrait panel space")
            quit(1)
            return
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
            var voice_before: int = game.audio_voice_cursor
            game._try_place(first_id, first_position)
            if fx.landing_cursor != fx_counter_before or game.audio_voice_cursor != voice_before:
                push_error("Puzzle contact emitted effects while still airborne")
                quit(1)
                return
            if game.puzzle_motion_tweens.size() != 3:
                push_error("Contact timeline is not tracked with puzzle motion")
                quit(1)
                return
            game.puzzle_motion_tweens[2].custom_step(.17)
            if fx.landing_cursor != fx_counter_before:
                push_error("Puzzle landing emitted particles before contact")
                quit(1)
                return
            game.puzzle_motion_tweens[2].custom_step(.05)
            if fx.landing_cursor != fx_counter_before + 1 \
                    or game.audio_voice_cursor != voice_before + 1:
                push_error("Puzzle landing never emitted synchronized sound and glints")
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
            var gel_paint: ShaderMaterial = preview_a.get_child(0).material_override
            var ghost_mat: ShaderMaterial = preview_b.get_child(0).material_override
            # Premium puzzle lighting must NEVER turn the placement ghost
            # opaque, or change the separate Gallery/studio shader contract.
            if float(gel_paint.get_shader_parameter("puzzle_lacquer")) < .99 \
                    or float(ghost_mat.get_shader_parameter("puzzle_lacquer")) > .001 \
                    or float(gel_paint.get_shader_parameter("gel_opacity")) < .96 \
                    or float(game.contact_shadow_material.get_shader_parameter(
                        "strength")) < .32:
                push_error("Premium puzzle lacquer, ghost isolation or stronger grounding lost")
                quit(1)
                return
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
            # A distant, still visible pointer makes the real translucent
            # ghost flex without moving any saved puzzle piece or board cell.
            game._draw_preview(Vector2i(game.size - 1, game.size - 1))
            var live_ghost_paint: ShaderMaterial = first_ghost.get_child(0).material_override
            var initial_bend: float = game.preview_drag_bend.length()
            if game.ghost.get_child(0) != first_ghost or initial_bend < .10 \
                    or initial_bend > 1.0 \
                    or float(live_ghost_paint.get_shader_parameter("gel_spring")) <= .1 \
                    or live_ghost_paint.get_shader_parameter("studio_drag") != game.preview_drag_bend \
                    or not game.placements.is_empty():
                push_error("Puzzle ghost has no bounded directional gelatin inertia")
                quit(1)
                return
            game._process(.1)
            if game.preview_drag_bend.length() >= initial_bend \
                    or game.preview_motion_energy >= .50:
                push_error("Puzzle jelly preview does not damp its movement")
                quit(1)
                return
            game._draw_preview(Vector2i(-1, -1))
            if first_ghost.visible or game.preview_drag_bend != Vector2.ZERO \
                    or game.preview_motion_energy != 0.0 \
                    or live_ghost_paint.get_shader_parameter("studio_drag") != Vector2.ZERO \
                    or float(live_ghost_paint.get_shader_parameter("gel_spring")) != 0.0:
                push_error("Touch release failed to neutralize hidden jelly ghost")
                quit(1)
                return

            # Reusing the hidden ghost on the next finger-down is essential
            # on Android: the existing mesh and material must survive release.
            game._draw_preview(first_position)
            if game.ghost.get_child(0) != first_ghost \
                    or not first_ghost.visible \
                    or game.preview_drag_bend != Vector2.ZERO:
                push_error("Repeated touch rebuilt or distorted the hidden Jelly ghost")
                quit(1)
                return
            game._draw_preview(Vector2i(-1, -1))

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
            if game.active_touch_index != 3 or not game.placements.is_empty() \
                    or not game.play_multitouch_blocked:
                push_error("Secondary Android contact did not disarm a puzzle gesture")
                quit(1)
                return
            finger_a.pressed = false
            game._unhandled_input(finger_a)
            if game.active_touch_index != -1 or game.touch_started_on_board \
                    or not game.placements.is_empty() or game.preview_cell.x >= 0 \
                    or game.play_multitouch_blocked \
                    or not game.play_touch_contacts.is_empty():
                push_error("Uncancelled first touch after two fingers placed Jelly")
                quit(1)
                return
            finger_a.pressed = true
            game._unhandled_input(finger_a)
            if game.active_touch_index != 3 or game.play_multitouch_blocked:
                push_error("Puzzle gestures failed to re-arm after all contacts lifted")
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

            # Puzzle landing must have a real airborne approach, anchored
            # shader squash AFTER contact and no parent mesh scaling.
            # Testing the actual Tween tracks prevents a decorative shader
            # uniform from silently replacing physical-looking feedback.
            game._try_place(first_id, first_position)
            var first_piece: Node3D = game.board.get_node_or_null(
                "Piece_" + first_id)
            var first_paint: ShaderMaterial = first_piece.get_child(
                0).material_override
            var first_cells: Array = game._pose_cells(first_id, 0)
            var width: int = 0
            var depth: int = 0
            for cell in first_cells:
                width = maxi(width, cell.y + 1)
                depth = maxi(depth, cell.x + 1)
            if game.puzzle_motion_tweens.size() != 3 \
                    or first_piece.scale != Vector3.ONE \
                    or first_piece.position.y < .25 \
                    or first_paint.get_shader_parameter("studio_span") != \
                        Vector2(float(width), float(depth)) \
                    or absf(float(first_paint.get_shader_parameter(
                        "puzzle_squash"))) > .001:
                push_error("Puzzle Jelly landing did not start with correct geometry")
                quit(1)
                return
            game.puzzle_motion_tweens[0].custom_step(.26)
            game.puzzle_motion_tweens[1].custom_step(.26)
            var pulse_before: int = fx.landing_cursor
            game.puzzle_motion_tweens[2].custom_step(.17)
            if fx.landing_cursor != pulse_before:
                push_error("Puzzle shell settled but contact sparkle fired too early")
                quit(1)
                return
            game.puzzle_motion_tweens[2].custom_step(.05)
            if fx.landing_cursor != pulse_before + 1:
                push_error("Puzzle physical contact did not trigger the sparkle")
                quit(1)
                return
            if absf(first_piece.position.y - .034) > .001 \
                    or float(first_paint.get_shader_parameter(
                        "puzzle_squash")) < .35:
                push_error("Puzzle Jelly never reached its support or compressed")
                quit(1)
                return
            var second_id := String(ids[1])
            var second_pose: Dictionary = poses[second_id]
            game._try_place(second_id, Vector2i(int(second_pose["row"]),
                int(second_pose["col"])))
            if game.placements.size() != 2 or game.undo_history.size() != 2:
                push_error("Multi-move undo stack or placement is broken")
                quit(1)
                return
            # Reusing unchanged pieces avoids per-touch GL mesh/material
            # allocations and protects completed visual bodies from flicker.
            var still_placed: Node3D = game.board.get_node_or_null(
                "Piece_" + first_id)
            if still_placed != first_piece \
                    or still_placed.get_child(0).material_override != first_paint \
                    or absf(still_placed.position.y - .034) > .001 \
                    or still_placed.rotation != Vector3.ZERO \
                    or absf(float(first_paint.get_shader_parameter(
                        "puzzle_squash"))) > .001:
                push_error("Second placement rebuilt or left first Jelly airborne")
                quit(1)
                return
            game._undo()
            if game.placements.size() != 1 or not game.has_undo_snapshot:
                push_error("Undo did not restore the previous move")
                quit(1)
                return
            if game.board.get_node_or_null("Piece_" + first_id) != first_piece \
                    or game.board.get_node_or_null("Piece_" + second_id) != null:
                push_error("Undo reconstructed unchanged Jelly or retained removed brick")
                quit(1)
                return
            game._undo()
            if not game.placements.is_empty() or game.has_undo_snapshot:
                push_error("Multi-undo did not recover the empty starting board")
                quit(1)
                return
            if game.board.get_node_or_null("Piece_" + first_id) != null:
                push_error("Undo left a detached piece on the GPU stage")
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
            # Startup rewrites the damaged primary, but must never rotate
            # its truncated contents over the known-good backup.
            if FileAccess.get_file_as_string(game.BACKUP_SAVE_FILE) != known_good:
                push_error("Crash recovery destroyed the known-good save backup")
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
            if game._valid_local_progress(broken):
                push_error("Out-of-range puzzle was accepted as a valid recovery source")
                quit(1)
                return
            var clean_reopen = scene.instantiate()
            root.add_child(clean_reopen)
            if clean_reopen.current_level != 1 \
                    or clean_reopen.saved_sessions.size() < 2 \
                    or clean_reopen.placements.size() != 1 \
                    or not clean_reopen.has_undo_snapshot:
                push_error("Semantic corruption did not recover the complete backup session")
                quit(1)
                return
            if FileAccess.get_file_as_string(game.BACKUP_SAVE_FILE) != known_good:
                push_error("Semantically corrupt primary overwrote the safe backup")
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
            print("TEST: atomic save swap, syntactic + semantic backup recovery and multi-level sessions")
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

# Godot treats clockwise triangles as front-facing. Vertex normals alone
# cannot catch an inside-out shell: inspect real indexed triangle winding.
func _clockwise_exterior(mesh: ArrayMesh) -> bool:
    var data: Array = mesh.surface_get_arrays(0)
    var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
    for offset in range(0, indices.size(), 3):
        var a: int = indices[offset]
        var b: int = indices[offset + 1]
        var c: int = indices[offset + 2]
        var geometric := (points[b] - points[a]).cross(points[c] - points[a])
        if geometric.dot(normals[a] + normals[b] + normals[c]) > .000001:
            return false
    return true
