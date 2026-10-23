extends RefCounted
## Offline-once midpoint subdivision for the isolated 2x1 gel reference.
## The original studio mesh (and all 21 puzzle levels) remains UNCHANGED.
## Dense shared vertices let the same GPU wave deform large flat faces, not
## only sparse bevel corners. Never rebuild in _process / physics frames.
const MAX_LEVEL := 2

static func _midpoint(a: int, b: int, vertices: Array[Vector3],
        normals: Array[Vector3], cache: Dictionary) -> int:
    var key := Vector2i(mini(a, b), maxi(a, b))
    if cache.has(key):
        return int(cache[key])
    var index := vertices.size()
    vertices.append((vertices[a] + vertices[b]) * 0.5)
    var n: Vector3 = normals[a] + normals[b]
    if n.length_squared() < 0.000001:
        n = normals[a]
    normals.append(n.normalized())
    cache[key] = index
    return index

static func tessellate(original: ArrayMesh, levels: int = 2) -> ArrayMesh:
    assert(original != null and original.get_surface_count() == 1)
    var arrays := original.surface_get_arrays(0)
    var original_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var original_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var original_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    assert(original_vertices.size() == original_normals.size())
    assert(original_indices.size() % 3 == 0)
    var vertices: Array[Vector3] = []
    var normals: Array[Vector3] = []
    for i in range(original_vertices.size()):
        vertices.append(original_vertices[i])
        normals.append(original_normals[i])
    var indices: PackedInt32Array = original_indices.duplicate()
    for _level in range(clampi(levels, 0, MAX_LEVEL)):
        var cache: Dictionary = {}
        var next_indices := PackedInt32Array()
        next_indices.resize(indices.size() * 4)
        var offset := 0
        for t in range(0, indices.size(), 3):
            var a: int = indices[t]
            var b: int = indices[t + 1]
            var c: int = indices[t + 2]
            var ab := _midpoint(a, b, vertices, normals, cache)
            var bc := _midpoint(b, c, vertices, normals, cache)
            var ca := _midpoint(c, a, vertices, normals, cache)
            # Preserve the original winding of the corrected studio mesh.
            for x in [a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]:
                next_indices[offset] = x
                offset += 1
        indices = next_indices
    var final_vertices := PackedVector3Array()
    var final_normals := PackedVector3Array()
    final_vertices.resize(vertices.size())
    final_normals.resize(normals.size())
    for i in range(vertices.size()):
        final_vertices[i] = vertices[i]
        final_normals[i] = normals[i]
    var result_arrays := []
    result_arrays.resize(Mesh.ARRAY_MAX)
    result_arrays[Mesh.ARRAY_VERTEX] = final_vertices
    result_arrays[Mesh.ARRAY_NORMAL] = final_normals
    result_arrays[Mesh.ARRAY_INDEX] = indices
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result_arrays)
    return result

static func triangle_count(mesh: ArrayMesh) -> int:
    var arrays := mesh.surface_get_arrays(0)
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    return indices.size() / 3
