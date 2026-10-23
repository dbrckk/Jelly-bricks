extends SceneTree
## Actual Godot 4.6 GL smoke test for the optional single-red Android app.
const MOBILE = preload("res://prototypes/single_brick/soft_reference_mobile.tscn")
var app: Node3D
var ticks: int = 0

func _initialize() -> void:
    app = MOBILE.instantiate() as Node3D
    root.add_child(app)

func _process(_delta: float) -> bool:
    ticks += 1
    if ticks == 8:
        if app.mobile_hud == null or app.fine_triangles != 8192:
            push_error("Mobile reviewer missing dense geometry or touch overlay")
            quit(1)
            return false
        var controls := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/ControlColumn/PoseButtons") as HBoxContainer
        if controls == null or controls.get_child_count() != 3:
            push_error("Mobile reviewer must provide three real actions")
            quit(1)
            return false
        var toggles := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/ControlColumn/OpticModes") as HBoxContainer
        if toggles == null or toggles.get_child_count() != 2 or \
                app.backdrop_viewport == null or app.backdrop_camera == null:
            push_error("Mobile red viewer missing real refraction controls")
            quit(1)
            return false
        print("PASS: mobile red reference has 8192 triangles and 5 controls")
    if ticks == 10:
        app.diagnostic_toggle.pressed.emit()
        if not app.diagnostic_background_enabled or not app.test_card.visible:
            push_error("Background pattern switch did not change the scene")
            quit(1)
            return false
    if ticks == 12:
        app.transmission_toggle.pressed.emit()
        if app.transmission_enabled or \
                float(app.gel_material.get_shader_parameter(
                    "backdrop_strength")) > 0.001:
            push_error("Optical comparison switch did not disable sampling")
            quit(1)
            return false
    if ticks == 14:
        app.transmission_toggle.pressed.emit()
        if not app.transmission_enabled or \
                float(app.gel_material.get_shader_parameter(
                    "backdrop_strength")) < 0.7:
            push_error("Viewport refraction cannot be restored from Android")
            quit(1)
            return false
    if ticks == 17:
        var button := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/ControlColumn/PoseButtons/Pose1") as Button
        button.pressed.emit()
        if app.pose_index != 1 or \
                float(app.gel_material.get_shader_parameter("deformation")) < 0.80:
            push_error("Impact button is not driving the actual gel deformation")
            quit(1)
            return false
    if ticks == 25:
        var button := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/ControlColumn/PoseButtons/Pose2") as Button
        button.pressed.emit()
        if app.pose_index != 2 or \
                float(app.gel_material.get_shader_parameter("deformation")) > -0.17:
            push_error("Rebound button failed to overshoot the soft gel")
            quit(1)
            return false
    if ticks == 35:
        var button := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/ControlColumn/PoseButtons/Pose0") as Button
        button.pressed.emit()
        if app.pose_index != 0 or \
                absf(float(app.gel_material.get_shader_parameter("deformation"))) > 0.001:
            push_error("Rest button did not restore the original 2x1 shape")
            quit(1)
            return false
        print("PASS: three Android review buttons physically change the shader")
        quit()
    return false
