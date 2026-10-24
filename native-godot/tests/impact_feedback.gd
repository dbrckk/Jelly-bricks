extends SceneTree
## Wall-clock regression for audiovisual contact timing.
## Real idle frames advance the Tween callback; canceled actions must
## never produce visual or haptic feedback after their geometry is removed.
var started := false

func _process(_delta: float) -> bool:
    if not started:
        started = true
        _run_real_time()
    return false

func _run_real_time() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        push_error("Contact QA could not load the real game")
        quit(1)
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    var studio: Node3D = game.stack_studio
    studio.set_active(true)
    studio._reset()
    studio.selected_cell = Vector2i(2, 2)
    studio.selected_length = 0
    var before: int = game.candy_fx.landing_cursor

    studio._commit()
    if studio.bricks.size() != 1 or game.candy_fx.landing_cursor != before:
        push_error("Audio/visual FX played at finger release, not contact")
        quit(1)
        return
    if studio.caustic_batch.multimesh.instance_count != 0:
        push_error("Airborne Jelly projected a floor caustic before landing")
        quit(1)
        return
    var falling: Node3D = studio.brick_nodes.back()
    var gel_paint: ShaderMaterial = falling.get_node("GelBody").material_override
    if absf(float(gel_paint.get_shader_parameter("studio_wave_phase"))) > .001 \
            or float(gel_paint.get_shader_parameter("studio_wave_gain")) < .85:
        push_error("Jelly contact wave started in midair or was not armed")
        quit(1)
        return
    var contact: MeshInstance3D = falling.get_node("GelContact")
    if contact.visible:
        push_error("Contact shadow floated beneath an airborne brick")
        quit(1)
        return
    await create_timer(.12).timeout
    if game.candy_fx.landing_cursor != before:
        push_error("Premature contact feedback during airborne approach")
        quit(1)
        return
    if absf(float(gel_paint.get_shader_parameter("studio_wave_phase"))) > .001:
        push_error("Local gel wave started before the brick reached its support")
        quit(1)
        return
    await create_timer(.30).timeout
    if game.candy_fx.landing_cursor != before + 1:
        push_error("Landing did not produce exactly one contact effect")
        quit(1)
        return
    var active_phase: float = float(gel_paint.get_shader_parameter("studio_wave_phase"))
    if active_phase <= .05 or active_phase >= .85:
        push_error("Local gel wave did not expand during the real landing")
        quit(1)
        return

    if not contact.visible:
        push_error("Settled brick lost its grounding contact")
        quit(1)
        return
    if studio.caustic_batch.multimesh.instance_count != 1:
        push_error("Grounded brick has no transmitted floor caustic")
        quit(1)
        return

    # A second landing is canceled by Undo before contact.
    studio.selected_color = 1
    studio._commit()
    var second_material: ShaderMaterial = studio.brick_nodes.back().get_node(
        "GelBody").material_override
    var airborne_dye: Color = second_material.get_shader_parameter(
        "studio_contact_dye")
    if airborne_dye.a > .001:
        push_error("Contact pigment transmitted through an airborne brick")
        quit(1)
        return
    if studio.bricks.size() != 2:
        push_error("Second studio layer could not be staged")
        quit(1)
        return
    var reached: int = game.candy_fx.landing_cursor
    studio._undo()
    if studio.bricks.size() != 1:
        push_error("Undo did not revert the second brick")
        quit(1)
        return
    await create_timer(.40).timeout
    if game.candy_fx.landing_cursor != reached:
        push_error("Canceled landing emitted a ghost feedback event")
        quit(1)
        return
    studio._commit()
    studio._stop_motion()
    if not studio.brick_nodes.back().get_node("GelContact").visible:
        push_error("Interrupted landing did not restore its contact shadow")
        quit(1)
        return
    var interrupted: ShaderMaterial = studio.brick_nodes.back().get_node(
        "GelBody").material_override
    if absf(float(interrupted.get_shader_parameter("studio_wave_gain"))) > .001 \
            or absf(float(interrupted.get_shader_parameter("studio_wave_phase"))) > .001:
        push_error("Interrupted landing left a permanently rippling jelly wall")
        quit(1)
        return
    var settled_dye: Color = interrupted.get_shader_parameter(
        "studio_contact_dye")
    if settled_dye.a < .7:
        push_error("Interrupted landing did not restore seated pigment contact")
        quit(1)
        return
    # A neighboring ground brick must not illuminate the floor in flight.
    # Canceling its animation must restore the already saved caustic,
    # while Undo removes the projection and structural piece together.
    studio.selected_cell = Vector2i(4, 4)
    studio._commit()
    if studio.bricks.size() != 3 \
            or studio.caustic_batch.multimesh.instance_count != 1:
        push_error("Second ground brick leaked light before contact")
        quit(1)
        return
    studio._stop_motion()
    if studio.caustic_batch.multimesh.instance_count != 2:
        push_error("Interrupted landing did not restore ground caustics")
        quit(1)
        return
    studio._undo()
    if studio.caustic_batch.multimesh.instance_count != 1:
        push_error("Undo left a stale caustic after removing a brick")
        quit(1)
        return
    studio.selected_cell = Vector2i(2, 2)
    studio._commit()
    var final_material: ShaderMaterial = studio.brick_nodes.back().get_node(
        "GelBody").material_override
    var before_touch: Color = final_material.get_shader_parameter(
        "studio_contact_dye")
    if before_touch.a > .001:
        push_error("Contact pigment arrived before the physical landing")
        quit(1)
        return
    await create_timer(.36).timeout
    var after_touch: Color = final_material.get_shader_parameter(
        "studio_contact_dye")
    if after_touch.a < .7:
        push_error("Contact pigment did not appear when the new brick landed")
        quit(1)
        return
    studio._undo()
    if studio.bricks.size() != 2:
        push_error("Undo did not remove the last optically mixed contact brick")
        quit(1)
        return
    print("PASS: impact-timed contact, pigment, caustics and undo")
    quit()
