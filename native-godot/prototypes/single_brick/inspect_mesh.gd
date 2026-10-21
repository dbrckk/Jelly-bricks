extends SceneTree
const GEL = preload("res://scripts/gel_mesh.gd")
func _initialize() -> void:
    var m: ArrayMesh = GEL.build_studio(2, 0)
    var arr: Array = m.surface_get_arrays(0)
    var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
    var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
    var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
    var cap_faces := 0
    var face_up := 0
    var face_down := 0
    var shown := 0
    for i in range(0, ix.size(), 3):
        var a: Vector3 = v[ix[i]]
        var b: Vector3 = v[ix[i+1]]
        var c: Vector3 = v[ix[i+2]]
        if a.y > 0.57 and b.y > 0.53 and c.y > 0.53:
            cap_faces += 1
            var winding: float = (b-a).cross(c-a).y
            if winding > 0.0: face_up += 1
            else: face_down += 1
            if shown < 4:
                print("CAP ", a," ",b," ",c," norm=",n[ix[i]],
                    " crossY=",winding)
                shown += 1
    print("vertices ",v.size()," triangles ",ix.size()/3,
        " horizontal top ",cap_faces," up ",face_up," down ",face_down)
    quit()
