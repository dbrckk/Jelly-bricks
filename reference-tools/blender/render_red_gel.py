"""Reproducible one-brick optical GROUND TRUTH (Blender Cycles).
Run: blender -b -t 4 --python reference-tools/blender/render_red_gel.py
This is a reference renderer, not an Android game asset or a claimed photo.
Outputs .blend and 3 real ray-traced PNGs under build/blender-red-gel.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(bpy.path.abspath("//")).resolve()
OUT = ROOT / "build" / "blender-red-gel"
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 720
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.engine = "CYCLES"
scene.camera = None
scene.world = bpy.data.worlds.new("Neutral photographic studio")
scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (0.83, 0.89, 0.95, 1.0)
background.inputs["Strength"].default_value = 0.55
try:
    scene.view_settings.view_transform = "AgX"
except Exception:
    scene.view_settings.view_transform = "Filmic"
scene.view_settings.look = "Medium High Contrast" if any(
    x.name == "Medium High Contrast"
    for x in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items
) else "Medium High Contrast"

def glossy_gel(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (420, 40)
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    principled.location = (90, 110)
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = 0.115
    principled.inputs["IOR"].default_value = 1.34
    if "Transmission Weight" in principled.inputs:
        principled.inputs["Transmission Weight"].default_value = 0.87
    else:
        principled.inputs["Transmission"].default_value = 0.87
    absorption = nodes.new("ShaderNodeVolumeAbsorption")
    absorption.location = (100, -230)
    absorption.inputs["Color"].default_value = (0.92, 0.075, 0.09, 1.0)
    absorption.inputs["Density"].default_value = 1.25
    mat.node_tree.links.new(principled.outputs["BSDF"], out.inputs["Surface"])
    mat.node_tree.links.new(absorption.outputs["Volume"], out.inputs["Volume"])
    return mat

red = glossy_gel("Red gelatin • IOR 1.34 / absorption / transmission", (0.86, 0.018, 0.037))

def apply_modifier(obj, modifier):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)

# Outer continuously rounded 2x1 brick, physical y in Godot -> Blender z.
bpy.ops.mesh.primitive_cube_add(size=1, location=(1.0, 0.5, 0.3075))
body = bpy.context.object
body.name = "Red gel 2x1 — hollow base and molded corners"
body.dimensions = (2.0, 1.0, 0.505)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bevel = body.modifiers.new("Rounded optical corners", "BEVEL")
bevel.width = 0.105
bevel.segments = 9
bevel.affect = "EDGES" if hasattr(bevel, "affect") else None
apply_modifier(body, bevel)

# Open underside socket: remove a volume rising from below to Z=0.265.
bpy.ops.mesh.primitive_cube_add(size=1, location=(1.0, 0.5, 0.055))
cutter = bpy.context.object
cutter.name = "Temporary exact underside socket cutter"
cutter.dimensions = (1.80, 0.80, 0.42)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
boolean = body.modifiers.new("Actual open-bottom socket", "BOOLEAN")
boolean.operation = "DIFFERENCE"
boolean.solver = "EXACT"
boolean.object = cutter
apply_modifier(body, boolean)
bpy.data.objects.remove(cutter, do_unlink=True)
for polygon in body.data.polygons:
    polygon.use_smooth = True
body.data.materials.append(red)

# Four short molded studs; their material is the SAME red volume optical model.
for cell in range(2):
    for lane, transverse in enumerate((0.265, 0.735)):
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=64, radius=0.126, depth=0.178,
            location=(cell + 0.5, transverse, 0.646))
        cap = bpy.context.object
        cap.name = f"Gel stud {cell+1}-{lane+1}"
        rounded = cap.modifiers.new("Wet rounded stud lip", "BEVEL")
        rounded.width = 0.027
        rounded.segments = 6
        apply_modifier(cap, rounded)
        for face in cap.data.polygons:
            face.use_smooth = True
        cap.data.materials.append(red)

# Matte studio floor (the actual object, not a composited backdrop).
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0.0))
floor = bpy.context.object
floor.name = "Physical offwhite studio floor"
matte = bpy.data.materials.new("Neutral matte cyclorama")
matte.diffuse_color = (0.88, 0.91, 0.93, 1)
matte.use_nodes = True
matte.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.95
floor.data.materials.append(matte)

def area(name, location, watts, extent, color):
    data = bpy.data.lights.new(name, type="AREA")
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = location
    direction = Vector((1.0, 0.5, 0.35)) - light.location
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    data.energy = watts
    data.shape = "DISK"
    data.size = extent
    data.color = color

area("Large warm softbox", (-3.5, -4.2, 7.0), 640, 5.5, (1.0, 0.94, 0.87))
area("Cool forward fill", (4.0, -0.5, 4.8), 300, 4.2, (0.88, 0.94, 1.0))
area("Thin transmission rim", (1.4, 4.0, 4.5), 880, 2.2, (1.0, 0.96, 0.95))

cam_data = bpy.data.cameras.new("Reference camera 70mm orthographic")
cam = bpy.data.objects.new("Reference camera", cam_data)
bpy.context.collection.objects.link(cam)
scene.camera = cam
cam_data.type = "ORTHO"
cam_data.ortho_scale = 3.4

def frame_camera(location):
    cam.location = location
    cam.rotation_euler = (Vector((1.0, 0.5, 0.30)) - cam.location).to_track_quat("-Z", "Y").to_euler()

views = (
    ("01-three-quarter.png", (3.7, -4.5, 2.9)),
    ("02-side.png", (1.6, -5.5, 1.4)),
    ("03-top.png", (2.0, -2.8, 5.1)),
)
frame_camera(views[0][1])
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "red-2x1-photoreal-reference.blend"))
for name, position in views:
    frame_camera(position)
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    assert (OUT / name).stat().st_size > 10000, name

metadata = {
    "renderer": "Blender Cycles CPU",
    "description": "Single modeled red gelatin 2x1 with real light transmission",
    "transmission": 0.87,
    "ior": 1.34,
    "absorption_density": 1.25,
    "output": [v[0] for v in views],
    "not_game_render": True,
    "not_reference_video": True,
}
(OUT / "reference-settings.json").write_text(
    json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
print("PASS: Three physically based Blender reference PNGs + editable blend file")
