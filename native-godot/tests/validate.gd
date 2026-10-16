extends SceneTree

## Real Godot-engine CI test, not a textual GDScript lint.
## Run: godot --headless --path native-godot --script res://tests/validate.gd

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Native scene cannot be loaded")
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    if game.levels.size() != 21:
        push_error("Expected all 21 puzzle levels")
        quit(1)
        return
    game.unlocked = 20
    var solved := 0
    for level_number in range(21):
        game._open_level(level_number)
        await process_frame
        if game.pieces.is_empty():
            push_error("Level has no pieces: " + str(level_number))
            quit(1)
            return
        var level: Dictionary = game.levels[level_number]
        var rows: Array = level["rows"]
        var letters: Array = game.pieces.keys()
        letters.sort()
        for letter in letters:
            var origin := Vector2i(game.size, game.size)
            for row in range(game.size):
                var line := String(rows[row])
                for col in range(game.size):
                    if line.substr(col, 1) == String(letter):
                        origin.x = mini(origin.x, row)
                        origin.y = mini(origin.y, col)
            game.selected_id = String(letter)
            game.rotation = 0
            game._try_place(String(letter), origin)
        if not game.completed:
            push_error("Native gameplay cannot solve level " + str(level_number))
            quit(1)
            return
        solved += 1
    print("PASS: Godot native Android source loads and all ", solved,
        " puzzle levels solve by real placement actions.")
    quit(0)
