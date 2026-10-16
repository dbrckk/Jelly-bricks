extends RefCounted
## Continuous gel volume generator for native Android.
## Top and bottom caps follow occupied cells; only the true exterior edges
## receive the rounded, smooth-shaded 3D skin. No seams or internal side faces.
##
## Boundary loops follow right turns first so diagonal corner contacts
## stay separate. The same construction handles enclosed empty holes.

const TOP := 0.42
const BASE := 0.055
const RING_OFFSETS := [0.0, 0.043, 0.086, 0.109, 0.106, 0.072, 0.0]
const RING_HEIGHTS := [TOP, 0.413, 0.383, 0.310, 0.172, 0.091, BASE]
const RING_VERTICALS := [1.0, 0.92, 0.65, 0.24, -0.08, -0.56, -0.88]

static func _vertex(st: SurfaceTool, position: Vector3, normal: Vector3) -> void:
    st.set_normal(normal.normalized())
    st.add_vertex(position)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
    _vertex(st, a, na)
    _vertex(st, b, nb)
    _vertex(st, c, nc)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, d: Vector3, na: Vector3, nb: Vector3,
        nc: Vector3, nd: Vector3) -> void:
    _triangle(st, a, b, c, na, nb, nc)
    _triangle(st, a, c, d, na, nc, nd)

static func _edge(edges: Array, outgoing: Dictionary,
        a: Vector2i, b: Vector2i) -> void:
    var index := edges.size()
    edges.append({"a": a, "b": b, "used": false})
    if not outgoing.has(a):
        outgoing[a] = []
    outgoing[a].append(index)

static func _contours(cells: Array) -> Array:
    var occupied := {}
    for cell in cells:
        occupied[cell] = true
    var edges: Array = []
    var outgoing := {}
    for cell in cells:
        var r: int = cell.x
        var c: int = cell.y
        if not occupied.has(Vector2i(r - 1, c)):
            _edge(edges, outgoing, Vector2i(c, r), Vector2i(c + 1, r))
        if not occupied.has(Vector2i(r, c + 1)):
            _edge(edges, outgoing, Vector2i(c + 1, r), Vector2i(c + 1, r + 1))
        if not occupied.has(Vector2i(r + 1, c)):
            _edge(edges, outgoing, Vector2i(c + 1, r + 1), Vector2i(c, r + 1))
        if not occupied.has(Vector2i(r, c - 1)):
            _edge(edges, outgoing, Vector2i(c, r + 1), Vector2i(c, r))

    var loops: Array = []
    for start in range(edges.size()):
        if edges[start]["used"]:
            continue
        var loop: Array = []
        var current: int = start
        var reached_end := false
        for _step in range(edges.size() + 1):
            if edges[current]["used"]:
                break
            edges[current]["used"] = true
            var a: Vector2i = edges[current]["a"]
            var b: Vector2i = edges[current]["b"]
            loop.append(a)
            if b == edges[start]["a"]:
                reached_end = true
                break
            var direction := b - a
            var turn_right := Vector2i(-direction.y, direction.x)
            var turn_left := Vector2i(direction.y, -direction.x)
            var next_id := -1
            var priority := [turn_right, direction, turn_left, -direction]
            for preferred in priority:
                for candidate in outgoing.get(b, []):
                    if edges[candidate]["used"]:
                        continue
                    if edges[candidate]["b"] - edges[candidate]["a"] == preferred:
                        next_id = candidate
                        break
                if next_id >= 0:
                    break
            if next_id < 0:
                break
            current = next_id
        if not reached_end or loop.size() < 4:
            push_error("Invalid jelly perimeter; cannot build connected 3D surface")
            return []
        loops.append(loop)
    return loops

static func _outward(a: Vector2i, b: Vector2i) -> Vector2:
    var delta := b - a
    return Vector2(float(delta.y), -float(delta.x)).normalized()

static func _miters(loop: Array) -> Array:
    var result: Array = []
    var n := loop.size()
    for i in range(n):
        var prev: Vector2i = loop[(i + n - 1) % n]
        var at: Vector2i = loop[i]
        var next: Vector2i = loop[(i + 1) % n]
        var previous_out := _outward(prev, at)
        var next_out := _outward(at, next)
        var denom := maxf(0.15, 1.0 + previous_out.dot(next_out))
        result.append((previous_out + next_out) / denom)
    return result

static func _ring_point(point: Vector2i, miter: Vector2,
        band: int) -> Vector3:
    var offset: float = RING_OFFSETS[band]
    return Vector3(float(point.x) + miter.x * offset,
        RING_HEIGHTS[band], float(point.y) + miter.y * offset)

static func _ring_normal(miter: Vector2, band: int) -> Vector3:
    var vertical: float = RING_VERTICALS[band]
    var side := sqrt(maxf(0.0, 1.0 - vertical * vertical))
    var n := miter.normalized()
    return Vector3(n.x * side, vertical, n.y * side).normalized()

static func _add_skin(st: SurfaceTool, polygon: Array) -> void:
    var miters := _miters(polygon)
    var length := polygon.size()
    for band in range(RING_OFFSETS.size() - 1):
        for i in range(length):
            var j := (i + 1) % length
            var a := _ring_point(polygon[i], miters[i], band)
            var b := _ring_point(polygon[j], miters[j], band)
            var c := _ring_point(polygon[j], miters[j], band + 1)
            var d := _ring_point(polygon[i], miters[i], band + 1)
            _quad(st, a, b, c, d,
                _ring_normal(miters[i], band),
                _ring_normal(miters[j], band),
                _ring_normal(miters[j], band + 1),
                _ring_normal(miters[i], band + 1))

## Premium soft-gel studs. One indexed mesh is instanced over every
## occupied cell in a single MultiMesh draw per jelly polyomino. The bevel
## is authored as radial/vertical rings, not a sharp CylinderMesh cap.
## Dimensions align with the rounded tile's pillowy crown at y ~0.46.
static func build_stud() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var radii := [.109, .132, .145, .145, .132]
    var heights := [.654, .643, .610, .501, .450]
    var normals_y := [.91, .72, .18, -.12, -.58]
    var segments := 12
    for band in range(radii.size() - 1):
        for segment in range(segments):
            var a0: float = TAU * float(segment) / float(segments)
            var a1: float = TAU * float(segment + 1) / float(segments)
            var pa := Vector3(cos(a0) * radii[band], heights[band],
                sin(a0) * radii[band])
            var pb := Vector3(cos(a1) * radii[band], heights[band],
                sin(a1) * radii[band])
            var pc := Vector3(cos(a1) * radii[band + 1], heights[band + 1],
                sin(a1) * radii[band + 1])
            var pd := Vector3(cos(a0) * radii[band + 1], heights[band + 1],
                sin(a0) * radii[band + 1])
            var side0: float = sqrt(maxf(0.0, 1.0 - normals_y[band] * normals_y[band]))
            var side1: float = sqrt(maxf(0.0, 1.0 - normals_y[band + 1] * normals_y[band + 1]))
            var na := Vector3(cos(a0) * side0, normals_y[band],
                sin(a0) * side0)
            var nb := Vector3(cos(a1) * side0, normals_y[band],
                sin(a1) * side0)
            var nc := Vector3(cos(a1) * side1, normals_y[band + 1],
                sin(a1) * side1)
            var nd := Vector3(cos(a0) * side1, normals_y[band + 1],
                sin(a0) * side1)
            _quad(st, pa, pb, pc, pd, na, nb, nc, nd)
    for segment in range(segments):
        var a0: float = TAU * float(segment) / float(segments)
        var a1: float = TAU * float(segment + 1) / float(segments)
        var center := Vector3(0, .657, 0)
        var ring_a := Vector3(cos(a0) * .109, .654, sin(a0) * .109)
        var ring_b := Vector3(cos(a1) * .109, .654, sin(a1) * .109)
        # Reverse radial order: outward face points toward +Y.
        _triangle(st, center, ring_b, ring_a,
            Vector3.UP, Vector3.UP, Vector3.UP)
    st.index()
    return st.commit()


static func build(cells: Array) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var up := Vector3.UP
    var down := Vector3.DOWN
    # Caps are welded visually; adjacent occupied cells never emit inner walls.
    for cell in cells:
        var x0: float = float(cell.y)
        var x1 := x0 + 1.0
        var z0: float = float(cell.x)
        var z1 := z0 + 1.0
        # A subtle soft cushion on each cell preserves the authored jelly
        # brick silhouette without the former harsh flat top.
        var a := Vector3(x0, TOP, z0)
        var b := Vector3(x0, TOP, z1)
        var c := Vector3(x1, TOP, z1)
        var d := Vector3(x1, TOP, z0)
        var crown := Vector3(x0 + .5, TOP + .042, z0 + .5)
        _triangle(st, a, b, crown, up, up, up)
        _triangle(st, b, c, crown, up, up, up)
        _triangle(st, c, d, crown, up, up, up)
        _triangle(st, d, a, crown, up, up, up)
        _quad(st, Vector3(x0, BASE, z0), Vector3(x1, BASE, z0),
            Vector3(x1, BASE, z1), Vector3(x0, BASE, z1),
            down, down, down, down)
    for loop in _contours(cells):
        _add_skin(st, loop)
    st.index()
    return st.commit()
