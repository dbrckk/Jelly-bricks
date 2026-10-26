extends SceneTree
## Real Godot 4.6/Mesa campaign UI smoke: not an HTML or painted mock.
## Capture level one and the raised top layer of the final Dragon level.
var frame := 0
var game: Node = null

func _process(_delta: float) -> bool:
    if frame == 0:
        var scene: PackedScene = load("res://scenes/main.tscn")
        if scene == null:
            push_error("Cannot open real Jelly challenge camera")
            quit(1)
            return false
        game = scene.instantiate()
        root.add_child(game)
        game._enter_stack_mode()
        game.stack_studio._enter_challenge()
    frame += 1
    if frame == 14:
        var studio = game.stack_studio
        if not studio.challenge_mode or studio.challenge_index != 0 \
                or not studio.challenge_preview.visible \
                or studio.challenge_grid.get_child_count() != 36:
            push_error("Real 3D first-challenge HUD is not visible or is incomplete")
            quit(1)
            return false
        if not _snapshot("jelly-sculpture-level01-ui.png"):
            return false
        # Complete a REAL challenge by assembling the published solution
        # with the actual stack and verifying its award/save. The screenshot
        # above remains the true novice state, not a mocked success screen.
        var example: Dictionary = studio.challenge_levels[0]
        if not studio._load_entries(example["demo"]):
            push_error("Real first Jelly challenge cannot be completed")
            quit(1)
            return false
        studio.challenge_moves = example["demo"].size()
        studio._rebuild()
        var match_state: Dictionary = preload(
            "res://scripts/challenge_progress.gd").compare(
            studio.bricks, studio._target())
        print("DEBUG campaign pre-victory: mode=%s index=%d armed=%s match=%s" %
            [str(studio.challenge_mode), studio.challenge_index,
            str(studio.challenge_awarded), JSON.stringify(match_state)])
        studio._challenge_check()
        var stored: Dictionary = preload(
            "res://scripts/challenge_progress.gd").load_profile()
        print("DEBUG campaign post-victory: awarded=%s memory=%s disk=%s dialog=%s" %
            [str(studio.challenge_awarded),
            JSON.stringify(studio.challenge_profile), JSON.stringify(stored),
            studio.challenge_win_dialog.dialog_text])
        if not studio.challenge_awarded or int(stored["unlocked"]) < 1 \
                or int(stored["xp"]) <= 0 \
                or not studio.challenge_win_dialog.dialog_text.contains(
                    "reproduit"):
            push_error("Challenge victory did not award durable XP or unlock the next animal")
            quit(1)
            return false
        studio.challenge_win_dialog.hide()
        # Test only: unlock the final Dragon for a second visual capture,
        # without granting its XP or fabricating user achievements.
        studio.challenge_profile["unlocked"] = 19
        studio._select_challenge(19)
        studio._cycle_challenge_layer()
    if frame == 28:
        var model = game.stack_studio
        if model.challenge_index != 19 \
                or model.challenge_preview_layer != 1 \
                or model.challenge_grid.get_child_count() != 36:
            push_error("Advanced animal relief model is not displayed")
            quit(1)
            return false
        if not _snapshot("jelly-sculpture-level20-relief-ui.png"):
            return false
        print("PASS: real Android-layout Jelly challenges 1/20 and 20/20, six-by-six models")
        quit()
    return false

func _snapshot(name: String) -> bool:
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Could not capture real Godot campaign screen")
        quit(1)
        return false
    image.resize(540, 960, Image.INTERPOLATE_LANCZOS)
    if image.save_png(ProjectSettings.globalize_path(
            "res://../build/" + name)) != OK:
        push_error("Cannot save Godot campaign screenshot: " + name)
        quit(1)
        return false
    return true
