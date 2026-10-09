class_name WaypointGraph
extends RefCounted
## Grafo de navegación peatonal (aceras, pasos de cebra, callejones y puertas)
## basado en AStar3D. Los NPC lo usan para calcular rutas.

var astar := AStar3D.new()
var district_points: Dictionary = {}    # distrito -> [ids]
var tags: Dictionary = {}               # etiqueta -> id
var _next_id := 0


func add_point(pos: Vector3, district: String = "", tag: String = "") -> int:
	var id := _next_id
	_next_id += 1
	astar.add_point(id, pos)
	if district != "":
		if not district_points.has(district):
			district_points[district] = []
		district_points[district].append(id)
	if tag != "":
		tags[tag] = id
	return id


func link(a: int, b: int) -> void:
	if a != b and astar.has_point(a) and astar.has_point(b):
		astar.connect_points(a, b, true)


func point_pos(id: int) -> Vector3:
	return astar.get_point_position(id)


func nearest(pos: Vector3) -> int:
	return astar.get_closest_point(pos)


func tag_pos(tag: String) -> Vector3:
	if tags.has(tag):
		return astar.get_point_position(tags[tag])
	return Vector3.ZERO


func random_point(district: String, rng: RandomNumberGenerator) -> Vector3:
	var arr: Array = district_points.get(district, [])
	if arr.is_empty():
		return Vector3.ZERO
	return astar.get_point_position(arr[rng.randi() % arr.size()])


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest(from)
	var b := nearest(to)
	var pts := astar.get_point_path(a, b)
	var out := PackedVector3Array()
	for p in pts:
		out.append(p)
	out.append(to)
	return out
