extends SceneTree
## Actual Godot 4.6 GL smoke test for the optional single-red Android app.
const MOBILE = preload("res://prototypes/single_brick/soft_reference_mobile.tscn")
var app: Node3D
var ticks: int = 0

func _initialize() -> void:
    app = MOBILE.instantiate() as Node3D
    root.add_child(app)

func _button(index: int) -> Button:
    return app.get_node(
        "Red2x1MobileReference/ReviewOverlay/ReviewControls/PoseButtons/Pose%d" % index
    ) as Button

func _process(_delta: float) -> bool:
    ticks += 1
    if ticks == 8:
        if app.mobile_hud == null or app.fine_triangles != 8192:
            push_error("Mobile reviewer missing dense geometry or touch overlay")
            quit(1)
            return false
        var controls := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/PoseButtons") as HBoxContainer
        if controls == null or controls.get_child_count() != 3:
            push_error("Mobile reviewer must provide three real actions")
            quit(1)
            return false
        print("PASS: mobile red reference has 8192 triangles and 3 controls")
    if ticks == 17:
        var button := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/PoseButtons/Pose1") as Button
        button.pressed.emit()
        if app.pose_index != 1 or \
                float(app.gel_material.get_shader_parameter("deformation")) < 0.80:
            push_error("Impact button is not driving the actual gel deformation")
            quit(1)
            return false
    if ticks == 25:
        var button := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/PoseButtons/Pose2") as Button
        button.pressed.emit()
        if app.pose_index != 2 or \
                float(app.gel_material.get_shader_parameter("deformation")) > -0.17:
            push_error("Rebound button failed to overshoot the soft gel")
            quit(1)
            return false
    if ticks == 35:
        var button := app.mobile_hud.get_node(
            "ReviewOverlay/ReviewControls/PoseButtons/Pose0") as Button
        button.pressed.emit()
        if app.pose_index != 0 or \
                absf(float(app.gel_material.get_shader_parameter("deformation"))) > 0.001:
            push_error("Rest button did not restore the original 2x1 shape")
            quit(1)
            return false
        print("PASS: three Android review buttons physically change the shader")
        quit()
    return false
