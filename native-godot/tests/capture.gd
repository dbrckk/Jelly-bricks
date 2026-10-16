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
    frames += 1
    if frames < 16:
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
