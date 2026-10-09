class_name Geo
extends RefCounted
## Utilidades para construir geometría con colisión de forma compacta.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_NPC := 4
const LAYER_PROPS := 8
const LAYER_INTERACT := 16
const LAYER_VEHICLE := 32


static func box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collide: bool = true, rot_y: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER_WORLD
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func collider(parent: Node, size: Vector3, pos: Vector3, layer: int = LAYER_WORLD) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	parent.add_child(sb)
	return sb


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, mat: Material, collide: bool = true, top_radius: float = -1.0, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER_WORLD
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(radius, cm.top_radius)
		sh.height = height
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


static func sphere(parent: Node, radius: float, pos: Vector3, mat: Material, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(segments / 2, 4)
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node, text: String, pos: Vector3, size: int = 64, color: Color = Color.WHITE, billboard: bool = false, outline: int = 8) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = false
	parent.add_child(l)
	return l


## Cartel rectangular con texto; normal hacia +Z local. Se gira con rot_y.
static func sign_board(parent: Node, text: String, pos: Vector3, rot_y: float, width: float, bg: Color, fg: Color = Color.WHITE, height: float = 0.8, glow: bool = true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	parent.add_child(root)
	box(root, Vector3(width, height, 0.12), Vector3.ZERO, Mats.emissive(bg, 0.6) if glow else Mats.color(bg), false)
	var l := label(root, text, Vector3(0, 0, 0.07), int(height * 70.0), fg)
	l.outline_size = 6
	if glow:
		l.modulate = fg * 1.4
	return root
