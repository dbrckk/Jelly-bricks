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
    await create_timer(.30).timeout
    if game.candy_fx.landing_cursor != before + 1:
        push_error("Landing did not produce exactly one contact effect")
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
    studio._commit()
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
    print("PASS: impact-timed contact, grounded caustics and undo")
    quit()
