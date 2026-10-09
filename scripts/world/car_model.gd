class_name CarModel
extends RefCounted
## Modelo de coche low-poly (frente hacia -Z).

const COLORS := ["#c0392b", "#2c3e50", "#ecf0f1", "#16a085", "#f39c12", "#7f8c8d", "#2980b9", "#8e44ad", "#1b1b1b", "#d35400"]


static func make(parent: Node, color: Color, police: bool = false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body_m := Mats.color(color, 0.35, 0.4)
	var dark := Mats.color(Color(0.08, 0.08, 0.09), 0.6)
	Geo.box(root, Vector3(1.8, 0.62, 4.2), Vector3(0, 0.6, 0), body_m, false)
	Geo.box(root, Vector3(1.6, 0.55, 2.1), Vector3(0, 1.17, 0.25), body_m, false)
	Geo.box(root, Vector3(1.64, 0.42, 1.9), Vector3(0, 1.15, 0.25), Mats.color(Color(0.1, 0.13, 0.17), 0.05, 0.5), false)
	Geo.box(root, Vector3(1.84, 0.18, 4.25), Vector3(0, 0.33, 0), dark, false)
	for x in [-0.82, 0.82]:
		for z in [-1.35, 1.35]:
			var wh := Geo.cylinder(root, 0.36, 0.26, Vector3(x, 0.36, z), dark, false, -1.0, 12)
			wh.rotation.z = PI * 0.5
			var rim := Geo.cylinder(root, 0.2, 0.27, Vector3(x, 0.36, z), Mats.color(Color(0.7, 0.7, 0.72), 0.3, 0.8), false, -1.0, 8)
			rim.rotation.z = PI * 0.5
	for x in [-0.6, 0.6]:
		Geo.box(root, Vector3(0.35, 0.14, 0.05), Vector3(x, 0.72, -2.1), Mats.emissive(Color(1.0, 0.95, 0.8), 0.8), false)
		Geo.box(root, Vector3(0.35, 0.12, 0.05), Vector3(x, 0.72, 2.1), Mats.emissive(Color(0.9, 0.1, 0.1), 0.8), false)
	if police:
		Geo.box(root, Vector3(1.0, 0.12, 0.3), Vector3(0, 1.5, 0.3), Mats.emissive(Color(0.2, 0.3, 1.0), 1.5), false)
		Geo.box(root, Vector3(0.5, 0.13, 0.31), Vector3(0.25, 1.5, 0.3), Mats.emissive(Color(1.0, 0.15, 0.15), 1.5), false)
		Geo.box(root, Vector3(1.82, 0.2, 2.0), Vector3(0, 0.7, 0.3), Mats.color(Color(0.95, 0.95, 0.95), 0.4), false)
	for c in root.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).visibility_range_end = 150.0
	return root


static func parked(parent: Node, pos: Vector3, yaw: float, color: Color, police: bool = false) -> Node3D:
	var car := make(parent, color, police)
	car.position = pos
	car.rotation.y = yaw
	var sb := StaticBody3D.new()
	sb.collision_layer = Geo.LAYER_VEHICLE
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.85, 1.4, 4.3)
	cs.shape = sh
	cs.position.y = 0.75
	sb.add_child(cs)
	car.add_child(sb)
	return car
