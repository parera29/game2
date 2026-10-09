class_name PhysicsProp
extends RigidBody3D
## Objeto físico que el jugador puede agarrar (clic izquierdo) y lanzar (clic derecho).

var prop_id := ""
var display := "objeto"


static func make_box(parent: Node, id: String, name: String, size: Vector3, pos: Vector3, color: Color, p_mass: float = 4.0) -> PhysicsProp:
	var p := PhysicsProp.new()
	p.prop_id = id
	p.display = name
	p.mass = p_mass
	p.collision_layer = Geo.LAYER_PROPS
	p.collision_mask = Geo.LAYER_WORLD | Geo.LAYER_PROPS | Geo.LAYER_PLAYER | Geo.LAYER_NPC | Geo.LAYER_VEHICLE
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	p.add_child(cs)
	Geo.box(p, size, Vector3.ZERO, Mats.color(color, 0.8), false)
	Geo.box(p, Vector3(size.x * 1.01, 0.04, size.z * 1.01), Vector3(0, size.y * 0.3, 0), Mats.color(color.darkened(0.3), 0.8), false)
	p.position = pos
	parent.add_child(p)
	p.add_to_group("grabbable")
	p.add_to_group("props")
	return p


static func make_cylinder(parent: Node, id: String, name: String, radius: float, height: float, pos: Vector3, color: Color, p_mass: float = 6.0) -> PhysicsProp:
	var p := PhysicsProp.new()
	p.prop_id = id
	p.display = name
	p.mass = p_mass
	p.collision_layer = Geo.LAYER_PROPS
	p.collision_mask = Geo.LAYER_WORLD | Geo.LAYER_PROPS | Geo.LAYER_PLAYER | Geo.LAYER_NPC | Geo.LAYER_VEHICLE
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	p.add_child(cs)
	Geo.cylinder(p, radius, height, Vector3.ZERO, Mats.color(color, 0.6, 0.3), false)
	Geo.cylinder(p, radius * 1.05, 0.05, Vector3(0, height * 0.5, 0), Mats.color(color.darkened(0.3), 0.6, 0.3), false)
	p.position = pos
	parent.add_child(p)
	p.add_to_group("grabbable")
	p.add_to_group("props")
	return p


func get_prompt(_player: Node) -> String:
	return "%s  [Clic izq.] Agarrar" % display.capitalize()


func interact(_player: Node) -> void:
	Events.toast("Usa el clic izquierdo para agarrar y el derecho para lanzar.", "info")
