extends SceneTree
## Real Godot Compatibility-mode diagnostic of ONE actual molded studio brick.
## Rendered through the same GPU shader and generated mesh as gameplay.
## Never uses a pre-rendered mock or changes user saves/active game scenes.
const GEL = preload("res://scripts/gel_mesh.gd")
const JELLY_SHADER = preload("res://shaders/jelly.gdshader")
var count := 0
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
    stage = Node3D.new()
    root.add_child(stage)
    var env := WorldEnvironment.new()
    var scene_env := Environment.new()
    scene_env.background_mode = Environment.BG_COLOR
    scene_env.background_color = Color("#f9fafb")
    scene_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    scene_env.ambient_light_color = Color("#f3f4f5")
    scene_env.ambient_light_energy = .9
    scene_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = scene_env
    stage.add_child(env)
    var key := DirectionalLight3D.new()
    key.light_color = Color("#fff9f2")
    key.light_energy = .85
    key.rotation_degrees = Vector3(-54, -32, 0)
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.light_color = Color("#dfeafd")
    fill.light_energy = .26
    fill.rotation_degrees = Vector3(-35, 143, 0)
    stage.add_child(fill)
    var floor := MeshInstance3D.new()
    var floor_mesh := PlaneMesh.new()
    floor_mesh.size = Vector2(50, 50)
    floor.mesh = floor_mesh
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("#fbfbfc")
    floor_mat.roughness = .94
    floor.material_override = floor_mat
    floor.position.y = -.07
    stage.add_child(floor)
    var body := MeshInstance3D.new()
    body.name = "ActualStudioShell"
    body.mesh = GEL.build_studio(2, 0)
    var mat := ShaderMaterial.new()
    mat.shader = JELLY_SHADER
    mat.set_shader_parameter("candy_tint", Color("#e92e2a"))
    mat.set_shader_parameter("gel_opacity", .865)
    mat.set_shader_parameter("studio_glass", 1.0)
    mat.set_shader_parameter("studio_pigment", .88)
    mat.set_shader_parameter("studio_finish", .94)
    mat.set_shader_parameter("studio_wet_edge", .95)
    mat.set_shader_parameter("studio_light_card", .88)
    mat.set_shader_parameter("studio_interlock", .84)
    mat.set_shader_parameter("studio_stud_axis", 0.0)
    mat.set_shader_parameter("studio_transmission", .86)
    mat.set_shader_parameter("optical_depth", .54)
    mat.set_shader_parameter("studio_span", Vector2(2,1))
    mat.set_shader_parameter("detail", 1.0)
    mat.set_shader_parameter("sheen", .51)
    body.material_override = mat
    stage.add_child(body)
    var studs := MultiMeshInstance3D.new()
    var mesh := MultiMesh.new()
    mesh.transform_format = MultiMesh.TRANSFORM_3D
    mesh.mesh = GEL.build_studio_stud()
    mesh.instance_count = 4
    for i in range(2):
        for j in range(2):
            mesh.set_instance_transform(i * 2 + j,
                Transform3D(Basis.IDENTITY, Vector3(
                    float(i) + .5, 0.0, .265 if j == 0 else .735)))
    studs.multimesh = mesh
    studs.material_override = mat
    stage.add_child(studs)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 5.8
    stage.add_child(camera)
    camera.position = Vector3(3.9, 3.3, 6.0)
    camera.look_at_from_position(camera.position, Vector3(1.0, .28, .5))
    camera.current = true

func _process(_delta: float) -> bool:
    count += 1
    if count == 21:
        camera.look_at_from_position(Vector3(3.5, 1.5, 6.0),
            Vector3(1.0, .28, .5))
    elif count == 46:
        camera.look_at_from_position(Vector3(.4, 3.6, 4.3),
            Vector3(1.0, .28, .5))
    if count == 20 or count == 45 or count == 70:
        var name := ""
        match count:
            20: name = "reference-brick-three-quarter.png"
            45: name = "reference-brick-side.png"
            70: name = "reference-brick-top.png"
        var png: Image = root.get_texture().get_image()
        if png == null or png.is_empty():
            push_error("No image rendered for isolated physical brick")
            quit(1)
            return false
        png.resize(540, 960, Image.INTERPOLATE_LANCZOS)
        # Verify that the GPU rendered a pigmented brick, not a blank PNG.
        var red_pixels := 0
        var pale_pixels := 0
        for py in range(250, 760, 4):
            for px in range(70, 470, 4):
                var sample: Color = png.get_pixel(px, py)
                if sample.r > sample.g * 1.35 and sample.r > sample.b * 1.22 and sample.r > .22:
                    red_pixels += 1
                if sample.r > .78 and sample.g > .78 and sample.b > .78:
                    pale_pixels += 1
        if red_pixels < 25 or pale_pixels < 900:
            push_error("Rendered brick missing or discolored: %s" % name)
            quit(1)
            return false
        var target = ProjectSettings.globalize_path("res://../build/" + name)
        var err := png.save_png(target)
        if err != OK:
            push_error("Failed to save one-brick reference: %d" % err)
            quit(1)
            return false
        print("PASS: Isolated real Godot 3D reference brick: ", target)
    if count >= 70:
        quit()
    return false
