class_name CityBuilder
extends RefCounted
## Genera la ciudad de Redmont de forma determinista: calles, aceras, edificios
## (con interiores accesibles), casas, mobiliario urbano, propiedades, NPC fijos,
## grafo de navegación, barreras policiales de distritos y tráfico.
##
## Rejilla: calles cada 50 m (x, z = 0, 50, ..., 200) de 10 m de ancho.
## Manzana (bx, bz) ocupa [bx*50+5, bx*50+45]; acera de 3 m en el borde.
## Coordenadas locales de manzana (lx, lz) en [0, 40]; solar edificable [3, 37].

const B := 50.0
const CURB := 0.12
const WALL_T := 0.25
const ROOM_H := 3.3

var w: World
var root: Node3D
var rng := RandomNumberGenerator.new()
var _corners: Dictionary = {}
var _attach: Dictionary = {}
var _avoid: Dictionary = {}
var lamp_mat: StandardMaterial3D
var ceiling_lamp_mat: StandardMaterial3D


func _init(world: World) -> void:
	w = world
	w.builder = self
	rng.seed = 74219


static func district_of(bx: int, bz: int) -> String:
	if bx < 2 and bz < 2:
		return "northtown"
	if bx >= 2 and bz < 2:
		return "downtown"
	if bx < 2:
		return "docks"
	return "uptown"


func L(bx: int, bz: int, lx: float, lz: float, y: float = 0.0) -> Vector3:
	return Vector3(bx * B + 5.0 + lx, y, bz * B + 5.0 + lz)


func _key(bx: int, bz: int) -> String:
	return "%d,%d" % [bx, bz]


static func yaw_facing(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func yaw_of_normal(n: Vector3) -> float:
	return atan2(n.x, n.z)


func build() -> void:
	root = Node3D.new()
	root.name = "City"
	w.add_child(root)
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.92, 0.7)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.85, 0.55)
	lamp_mat.emission_energy_multiplier = 0.0
	w.lamp_material = lamp_mat
	ceiling_lamp_mat = Mats.emissive(Color(1.0, 0.95, 0.85), 1.5)
	_ground()
	_roads()
	for bx in 4:
		for bz in 4:
			_block_base(bx, bz)
	_northtown()
	_downtown()
	_docks()
	_uptown()
	_finish_nav()
	_street_furniture()
	_parked_cars()
	_barriers()
	_outer()
	_traffic()
	apply_culling(w)


## Optimización: los objetos pequeños dejan de dibujarse a cierta distancia y las
## luces interiores se desvanecen. Los edificios grandes siempre se dibujan.
static func apply_culling(parent: Node) -> void:
	for n in parent.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0:
			continue
		if gi is Label3D or gi is Sprite3D:
			gi.visibility_range_end = 120.0
			continue
		var longest := gi.get_aabb().size[gi.get_aabb().size.max_axis_index()]
		if longest < 1.5:
			gi.visibility_range_end = 60.0
		elif longest < 4.0:
			gi.visibility_range_end = 110.0
		elif longest < 12.0:
			gi.visibility_range_end = 200.0
	for n in parent.find_children("*", "OmniLight3D", true, false):
		var l := n as OmniLight3D
		l.distance_fade_enabled = true
		l.distance_fade_begin = 60.0
		l.distance_fade_length = 15.0


# ================================================================== Base

func _ground() -> void:
	var grass := Mats.surface(Mats.Surf.GRASS, Color(0.3, 0.47, 0.2), Color(0.42, 0.55, 0.24), 0.5)
	_plane(Vector3(100, -0.03, 4), Vector2(700, 420), grass)        # z de -206 a 214
	_plane(Vector3(357.5, -0.03, 307), Vector2(505, 186), grass)    # sureste (Uptown sur)
	Geo.collider(root, Vector3(800, 1.0, 800), Vector3(100, -0.5, 100))
	# Agua del puerto
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 186)
	pm.subdivide_width = 30
	pm.subdivide_depth = 18
	water.mesh = pm
	water.material_override = Mats.water()
	water.position = Vector3(-45, -0.7, 307)
	root.add_child(water)
	Geo.box(root, Vector3(300, 1.0, 0.6), Vector3(-45, -0.4, 214.3), Mats.surface(Mats.Surf.CONCRETE, Color(0.45, 0.45, 0.43)), false)


func _plane(center: Vector3, size: Vector2, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _roads() -> void:
	for k in 5:
		Geo.box(root, Vector3(210, 0.04, 10), Vector3(100, -0.015, k * B), Mats.road(0), false, 0.0, false)
	for k in 5:
		for j in 4:
			Geo.box(root, Vector3(10, 0.04, 40), Vector3(k * B, -0.015, j * B + 25.0), Mats.road(1), false, 0.0, false)


func _sidewalk_mat(district: String) -> Material:
	match district:
		"uptown":
			return Mats.surface(Mats.Surf.SIDEWALK, Color(0.74, 0.72, 0.68), Color(0.55, 0.53, 0.5))
		"docks":
			return Mats.surface(Mats.Surf.SIDEWALK, Color(0.5, 0.5, 0.49), Color(0.36, 0.36, 0.35))
		"downtown":
			return Mats.surface(Mats.Surf.SIDEWALK, Color(0.66, 0.64, 0.6), Color(0.5, 0.48, 0.45))
	return Mats.surface(Mats.Surf.SIDEWALK, Color(0.6, 0.59, 0.56), Color(0.44, 0.43, 0.41))


func _block_base(bx: int, bz: int) -> void:
	var c := L(bx, bz, 20, 20)
	var d := district_of(bx, bz)
	Geo.box(root, Vector3(40, CURB, 40), Vector3(c.x, CURB * 0.5, c.z), _sidewalk_mat(d), true, 0.0, false)
	# Bordillo
	var curb_m := Mats.color(Color(0.7, 0.7, 0.68), 0.9)
	for s in [Vector3(0, 0, -19.9), Vector3(0, 0, 19.9)]:
		Geo.box(root, Vector3(40.02, 0.02, 0.2), c + s + Vector3(0, CURB + 0.005, 0), curb_m, false, 0.0, false)
	for s in [Vector3(-19.9, 0, 0), Vector3(19.9, 0, 0)]:
		Geo.box(root, Vector3(0.2, 0.02, 40.02), c + s + Vector3(0, CURB + 0.005, 0), curb_m, false, 0.0, false)
	var key := _key(bx, bz)
	var x0 := bx * B + 5.0
	var z0 := bz * B + 5.0
	_corners[key] = {
		"nw": w.nav.add_point(Vector3(x0 + 1.5, CURB, z0 + 1.5), d),
		"ne": w.nav.add_point(Vector3(x0 + 38.5, CURB, z0 + 1.5), d),
		"se": w.nav.add_point(Vector3(x0 + 38.5, CURB, z0 + 38.5), d),
		"sw": w.nav.add_point(Vector3(x0 + 1.5, CURB, z0 + 38.5), d),
	}
	_attach[key] = {"n": [], "s": [], "w": [], "e": []}
	_avoid[key] = []


func _attach_point(bx: int, bz: int, side: String, along: float, in_district: bool = true) -> int:
	var x0 := bx * B + 5.0
	var z0 := bz * B + 5.0
	var pos := Vector3.ZERO
	match side:
		"n":
			pos = Vector3(clampf(along, x0 + 2.0, x0 + 38.0), CURB, z0 + 1.5)
		"s":
			pos = Vector3(clampf(along, x0 + 2.0, x0 + 38.0), CURB, z0 + 38.5)
		"w":
			pos = Vector3(x0 + 1.5, CURB, clampf(along, z0 + 2.0, z0 + 38.0))
		"e":
			pos = Vector3(x0 + 38.5, CURB, clampf(along, z0 + 2.0, z0 + 38.0))
	var id := w.nav.add_point(pos, district_of(bx, bz) if in_district else "")
	_attach[_key(bx, bz)][side].append([along, id])
	return id


## Ramal desde la acera hacia puntos interiores (puertas, callejones, encuentros).
func add_spur(bx: int, bz: int, side: String, along: float, inner: Array) -> int:
	var prev := _attach_point(bx, bz, side, along)
	for p in inner:
		var id := w.nav.add_point(p)
		w.nav.link(prev, id)
		prev = id
	return prev


func _finish_nav() -> void:
	for bx in 4:
		for bz in 4:
			var key := _key(bx, bz)
			var c: Dictionary = _corners[key]
			var at: Dictionary = _attach[key]
			_chain(c["nw"], at["n"], c["ne"])
			_chain(c["sw"], at["s"], c["se"])
			_chain(c["nw"], at["w"], c["sw"])
			_chain(c["ne"], at["e"], c["se"])
	for bx in 4:
		for bz in 4:
			var c: Dictionary = _corners[_key(bx, bz)]
			if bx + 1 < 4:
				var r: Dictionary = _corners[_key(bx + 1, bz)]
				w.nav.link(c["ne"], r["nw"])
				w.nav.link(c["se"], r["sw"])
			if bz + 1 < 4:
				var dn: Dictionary = _corners[_key(bx, bz + 1)]
				w.nav.link(c["sw"], dn["nw"])
				w.nav.link(c["se"], dn["ne"])


func _chain(start: int, items: Array, end: int) -> void:
	items.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var prev := start
	for it in items:
		w.nav.link(prev, int(it[1]))
		prev = int(it[1])
	w.nav.link(prev, end)


func _avoid_spot(bx: int, bz: int, p: Vector3) -> void:
	_avoid[_key(bx, bz)].append(p)


# ================================================================== Edificios

## Edificio con planta baja accesible.
func shell(bx: int, bz: int, r: Rect2, floors: int, ext: Material, opts: Dictionary = {}) -> Dictionary:
	var p0 := L(bx, bz, r.position.x, r.position.y)
	var p1 := L(bx, bz, r.end.x, r.end.y)
	var side: String = opts.get("door_side", "n")
	var frac: float = opts.get("door_frac", 0.5)
	var dw: float = opts.get("door_w", 1.4)
	var y0 := CURB
	var h := ROOM_H
	var t := WALL_T
	var inner_mat: Material = Mats.surface(Mats.Surf.PLASTER, opts.get("wall_col", Color(0.86, 0.83, 0.76)), opts.get("base_col", Color(0.32, 0.26, 0.2)))
	var node := Node3D.new()
	root.add_child(node)
	var walls := {
		"n": [Vector3(p0.x, 0, p0.z + t * 0.5), Vector3(p1.x, 0, p0.z + t * 0.5), Vector3(0, 0, -1)],
		"s": [Vector3(p0.x, 0, p1.z - t * 0.5), Vector3(p1.x, 0, p1.z - t * 0.5), Vector3(0, 0, 1)],
		"w": [Vector3(p0.x + t * 0.5, 0, p0.z + t), Vector3(p0.x + t * 0.5, 0, p1.z - t), Vector3(-1, 0, 0)],
		"e": [Vector3(p1.x - t * 0.5, 0, p0.z + t), Vector3(p1.x - t * 0.5, 0, p1.z - t), Vector3(1, 0, 0)],
	}
	_map_rect(p0, p1, opts.get("map_color", Color(0.42, 0.4, 0.38)))
	if opts.has("poi"):
		var pp: PackedStringArray = String(opts["poi"]).split("|")
		w.pois.append({"name": pp[0], "pos": (p0 + p1) * 0.5, "kind": pp[1] if pp.size() > 1 else "shop"})
	var door_center := Vector3.ZERO
	for sname in walls:
		var a: Vector3 = walls[sname][0]
		var b: Vector3 = walls[sname][1]
		var n: Vector3 = walls[sname][2]
		var length := (b - a).length()
		var gaps: Array = []
		if sname == side:
			var c := clampf(length * frac, dw * 0.5 + 0.4, length - dw * 0.5 - 0.4)
			gaps.append(c)
			door_center = a + (b - a).normalized() * c
		_wall_segments(node, a, b, n, length, gaps, dw, y0, h, t, ext, inner_mat)
	var ww := p1.x - p0.x
	var dd := p1.z - p0.z
	var cx := (p0.x + p1.x) * 0.5
	var cz := (p0.z + p1.z) * 0.5
	Geo.box(node, Vector3(ww, 0.25, dd), Vector3(cx, y0 + h + 0.125, cz), ext)
	Geo.box(node, Vector3(ww - 2 * t, 0.02, dd - 2 * t), Vector3(cx, y0 + h - 0.01, cz), _ceiling_mat(opts.get("ceiling_col", Color(0.9, 0.88, 0.84))), false, 0.0, false)
	var top := y0 + h + 0.25
	if floors > 1:
		var uh := (floors - 1) * 3.2
		Geo.box(node, Vector3(ww, uh, dd), Vector3(cx, top + uh * 0.5, cz), ext)
		top += uh
	_roof_details(node, Vector3(cx, top, cz), ww, dd, opts.get("trim", Color(0.5, 0.5, 0.5)))
	var floor_mat: Material = opts.get("floor", Mats.surface(Mats.Surf.WOOD, Color(0.55, 0.38, 0.24), Color(0.45, 0.3, 0.18)))
	Geo.box(node, Vector3(ww - 2 * t, 0.01, dd - 2 * t), Vector3(cx, y0 + 0.006, cz), floor_mat, false, 0.0, false)
	# Iluminación interior
	var light := OmniLight3D.new()
	light.position = Vector3(cx, y0 + h - 0.5, cz)
	light.omni_range = maxf(ww, dd) * 1.1
	light.omni_attenuation = 0.55
	light.light_energy = opts.get("light_energy", 1.5)
	light.light_color = opts.get("light_color", Color(1.0, 0.92, 0.8))
	light.light_specular = 0.3
	node.add_child(light)
	var lamps := maxi(1, int(ww / 6.0))
	for i in lamps:
		var lx := p0.x + ww * (i + 0.5) / lamps
		Geo.box(node, Vector3(1.2, 0.06, 0.4), Vector3(lx, y0 + h - 0.05, cz), ceiling_lamp_mat, false, 0.0, false)
	# Zona interior
	var zone := Area3D.new()
	zone.collision_layer = 0
	zone.collision_mask = Geo.LAYER_PLAYER
	var zcs := CollisionShape3D.new()
	var zsh := BoxShape3D.new()
	zsh.size = Vector3(ww - 2 * t, h, dd - 2 * t)
	zcs.shape = zsh
	zone.add_child(zcs)
	zone.position = Vector3(cx, y0 + h * 0.5, cz)
	node.add_child(zone)
	if opts.has("property"):
		zone.set_meta("property", opts["property"])
	zone.body_entered.connect(w._zone_enter.bind(zone))
	zone.body_exited.connect(w._zone_exit.bind(zone))
	# Puerta
	var nrm: Vector3 = walls[side][2]
	var door: Door = null
	if not opts.get("open_front", false):
		door = Door.new()
		node.add_child(door)
		door.position = Vector3(door_center.x, y0, door_center.z)
		door.rotation.y = yaw_of_normal(nrm)
		door.setup(dw - 0.06, 2.3, opts.get("door_color", Color(0.4, 0.27, 0.17)), opts.get("glass_door", false))
		door.door_name = opts.get("door_name", "puerta")
		door.lock_check = opts.get("lock", Callable())
		w.doors.append(door)
	# Marco exterior
	var frame_m := Mats.color(opts.get("trim", Color(0.85, 0.82, 0.78)), 0.6)
	var tang := Vector3(-nrm.z, 0, nrm.x)
	for sgn in [-1.0, 1.0]:
		var fp: Vector3 = door_center + tang * sgn * (dw * 0.5 + 0.06) + nrm * (t * 0.5 + 0.03)
		Geo.box(node, Vector3(0.12, 2.45, 0.06) if absf(nrm.z) > 0.5 else Vector3(0.06, 2.45, 0.12), fp + Vector3(0, y0 + 1.22, 0), frame_m, false)
	var lp := door_center + nrm * (t * 0.5 + 0.03)
	Geo.box(node, Vector3(dw + 0.3, 0.14, 0.07) if absf(nrm.z) > 0.5 else Vector3(0.07, 0.14, dw + 0.3), lp + Vector3(0, y0 + 2.4, 0), frame_m, false)
	if opts.has("awning"):
		var aw_c: Color = opts["awning"]
		var ap := door_center + nrm * (t * 0.5 + 0.6)
		var aw := Geo.box(node, Vector3(dw + 1.4, 0.08, 1.2) if absf(nrm.z) > 0.5 else Vector3(1.2, 0.08, dw + 1.4), ap + Vector3(0, y0 + 2.75, 0), Mats.color(aw_c, 0.8), false)
		aw.rotation = Vector3(0.18 * nrm.z, 0, -0.18 * nrm.x)
	if opts.has("sign"):
		var sp := door_center + nrm * (t * 0.5 + 0.1) + Vector3(0, y0 + 3.0, 0)
		Geo.sign_board(node, String(opts["sign"]), sp, yaw_of_normal(nrm), opts.get("sign_w", 4.0), opts.get("sign_bg", Color(0.15, 0.15, 0.2)), opts.get("sign_fg", Color(1, 1, 1)))
	# Navegación: acera -> umbral -> interior
	var along := door_center.x if absf(nrm.z) > 0.5 else door_center.z
	var thr := door_center + nrm * 0.9
	var inside := door_center - nrm * 1.6
	add_spur(bx, bz, side, along, [Vector3(thr.x, CURB, thr.z), Vector3(inside.x, CURB, inside.z)])
	_avoid_spot(bx, bz, door_center)
	return {"node": node, "p0": p0, "p1": p1, "y0": y0, "door": door, "door_pos": door_center, "normal": nrm, "zone": zone,
		"in0": Vector3(p0.x + t, y0, p0.z + t), "in1": Vector3(p1.x - t, y0, p1.z - t)}


## Techo interior con una ligera emisión cálida: simula la luz rebotada y evita
## que el ambiente del cielo lo tiña de azul.
func _ceiling_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = col * Color(1.0, 0.92, 0.8)
	m.emission_energy_multiplier = 0.35
	return m


func _map_rect(p0: Vector3, p1: Vector3, col: Color) -> void:
	w.map_rects.append({"rect": Rect2(p0.x, p0.z, p1.x - p0.x, p1.z - p0.z), "color": col})


func _wall_segments(node: Node3D, a: Vector3, b: Vector3, n: Vector3, length: float, gaps: Array, dw: float, y0: float, h: float, t: float, ext: Material, inner: Material) -> void:
	var dir := (b - a).normalized()
	var along_x := absf(n.z) > 0.5
	var cuts: Array = [0.0]
	for g in gaps:
		cuts.append(float(g) - dw * 0.5)
		cuts.append(float(g) + dw * 0.5)
	cuts.append(length)
	for i in range(0, cuts.size(), 2):
		var s0: float = cuts[i]
		var s1: float = cuts[i + 1]
		if s1 - s0 < 0.01:
			continue
		var mid := a + dir * ((s0 + s1) * 0.5)
		var size := Vector3(s1 - s0, h, t) if along_x else Vector3(t, h, s1 - s0)
		Geo.box(node, size, Vector3(mid.x, y0 + h * 0.5, mid.z), ext)
		var lsize := Vector3(s1 - s0, h, 0.02) if along_x else Vector3(0.02, h, s1 - s0)
		var lpos := mid - n * (t * 0.5 + 0.011)
		Geo.box(node, lsize, Vector3(lpos.x, y0 + h * 0.5, lpos.z), inner, false, 0.0, false)
	for g in gaps:
		var mid2 := a + dir * float(g)
		var lh := h - 2.35
		var size2 := Vector3(dw, lh, t) if along_x else Vector3(t, lh, dw)
		Geo.box(node, size2, Vector3(mid2.x, y0 + 2.35 + lh * 0.5, mid2.z), ext)
		var lp := mid2 - n * (t * 0.5 + 0.011)
		Geo.box(node, Vector3(dw, lh, 0.02) if along_x else Vector3(0.02, lh, dw), Vector3(lp.x, y0 + 2.35 + lh * 0.5, lp.z), inner, false, 0.0, false)


## Edificio macizo (no accesible) con puerta decorativa opcional.
func solid(bx: int, bz: int, r: Rect2, floors: int, mat: Material, opts: Dictionary = {}) -> Dictionary:
	var p0 := L(bx, bz, r.position.x, r.position.y)
	var p1 := L(bx, bz, r.end.x, r.end.y)
	var ww := p1.x - p0.x
	var dd := p1.z - p0.z
	var hh := floors * 3.2 + 0.35
	var c := Vector3((p0.x + p1.x) * 0.5, CURB + hh * 0.5, (p0.z + p1.z) * 0.5)
	_map_rect(p0, p1, Color(0.33, 0.33, 0.36))
	if opts.has("poi"):
		var pp: PackedStringArray = String(opts["poi"]).split("|")
		w.pois.append({"name": pp[0], "pos": c, "kind": pp[1] if pp.size() > 1 else "shop"})
	Geo.box(root, Vector3(ww, hh, dd), c, mat)
	_roof_details(root, Vector3(c.x, CURB + hh, c.z), ww, dd, opts.get("trim", Color(0.5, 0.5, 0.5)))
	var side: String = opts.get("door_side", "")
	if side != "":
		var nrm := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}[side] as Vector3
		var frac: float = opts.get("door_frac", 0.5)
		var dp := Vector3.ZERO
		match side:
			"n": dp = Vector3(lerpf(p0.x, p1.x, frac), 0, p0.z)
			"s": dp = Vector3(lerpf(p0.x, p1.x, frac), 0, p1.z)
			"w": dp = Vector3(p0.x, 0, lerpf(p0.z, p1.z, frac))
			"e": dp = Vector3(p1.x, 0, lerpf(p0.z, p1.z, frac))
		var dwid: float = opts.get("door_w", 1.6)
		var door_m := Mats.color(opts.get("door_color", Color(0.25, 0.2, 0.16)), 0.6)
		var pos := dp + nrm * 0.03 + Vector3(0, CURB + 1.2, 0)
		Geo.box(root, Vector3(dwid, 2.4, 0.08) if absf(nrm.z) > 0.5 else Vector3(0.08, 2.4, dwid), pos, door_m, false)
		Geo.box(root, Vector3(dwid + 0.3, 0.15, 0.12) if absf(nrm.z) > 0.5 else Vector3(0.12, 0.15, dwid + 0.3), dp + nrm * 0.05 + Vector3(0, CURB + 2.47, 0), Mats.color(Color(0.8, 0.78, 0.74)), false)
		if opts.has("sign"):
			Geo.sign_board(root, String(opts["sign"]), dp + nrm * 0.12 + Vector3(0, CURB + 3.1, 0), yaw_of_normal(nrm), opts.get("sign_w", 4.0), opts.get("sign_bg", Color(0.15, 0.15, 0.2)), opts.get("sign_fg", Color.WHITE))
		_avoid_spot(bx, bz, dp)
	return {"p0": p0, "p1": p1}


func _roof_details(parent: Node3D, top_center: Vector3, ww: float, dd: float, trim: Color) -> void:
	var tm := Mats.color(trim.darkened(0.2), 0.8)
	var y := top_center.y + 0.25
	Geo.box(parent, Vector3(ww, 0.5, 0.2), Vector3(top_center.x, y, top_center.z - dd * 0.5 + 0.1), tm, false, 0.0, false)
	Geo.box(parent, Vector3(ww, 0.5, 0.2), Vector3(top_center.x, y, top_center.z + dd * 0.5 - 0.1), tm, false, 0.0, false)
	Geo.box(parent, Vector3(0.2, 0.5, dd), Vector3(top_center.x - ww * 0.5 + 0.1, y, top_center.z), tm, false, 0.0, false)
	Geo.box(parent, Vector3(0.2, 0.5, dd), Vector3(top_center.x + ww * 0.5 - 0.1, y, top_center.z), tm, false, 0.0, false)
	var metal := Mats.color(Color(0.6, 0.62, 0.64), 0.5, 0.6)
	for i in rng.randi_range(1, 3):
		var off := Vector3(rng.randf_range(-ww * 0.3, ww * 0.3), 0, rng.randf_range(-dd * 0.3, dd * 0.3))
		Geo.box(parent, Vector3(1.4, 0.9, 1.0), top_center + off + Vector3(0, 0.45, 0), metal, false)
		Geo.cylinder(parent, 0.35, 0.1, top_center + off + Vector3(0, 0.95, 0), Mats.color(Color(0.3, 0.3, 0.32)), false)


## Casa unifamiliar decorativa con tejado a dos aguas, jardín y valla.
func house(bx: int, bz: int, r: Rect2, wall: Color, roof: Color, door_side: String, floors: int = 1, fence: bool = true) -> void:
	var p0 := L(bx, bz, r.position.x, r.position.y)
	var p1 := L(bx, bz, r.end.x, r.end.y)
	var lot_c := Vector3((p0.x + p1.x) * 0.5, 0, (p0.z + p1.z) * 0.5)
	var lot_w := p1.x - p0.x
	var lot_d := p1.z - p0.z
	Geo.box(root, Vector3(lot_w, 0.01, lot_d), lot_c + Vector3(0, CURB + 0.005, 0), Mats.surface(Mats.Surf.GRASS, Color(0.32, 0.5, 0.22), Color(0.4, 0.56, 0.25), 0.8), false, 0.0, false)
	var inset := {"n": 2.0, "s": 2.0, "w": 2.0, "e": 2.0}
	inset[door_side] = 4.5
	var h0 := Vector3(p0.x + inset["w"], 0, p0.z + inset["n"])
	var h1 := Vector3(p1.x - inset["e"], 0, p1.z - inset["s"])
	var fw := h1.x - h0.x
	var fd := h1.z - h0.z
	var hh := floors * 3.0
	var hc := Vector3((h0.x + h1.x) * 0.5, CURB + hh * 0.5, (h0.z + h1.z) * 0.5)
	_map_rect(h0, h1, Color(0.55, 0.45, 0.4))
	var mat := Mats.building(wall, 3, Color(0.95, 0.95, 0.93), false, rng.randf() * 10.0, Vector2(2.6, 3.0), 0.45)
	Geo.box(root, Vector3(fw, hh, fd), hc, mat)
	# Tejado
	var rm := MeshInstance3D.new()
	var prism := PrismMesh.new()
	if fw >= fd:
		prism.size = Vector3(fd + 0.8, 1.9, fw + 0.8)
		rm.rotation.y = PI * 0.5
	else:
		prism.size = Vector3(fw + 0.8, 1.9, fd + 0.8)
	rm.mesh = prism
	rm.material_override = Mats.color(roof, 0.85)
	rm.position = Vector3(hc.x, CURB + hh + 0.95, hc.z)
	root.add_child(rm)
	Geo.box(root, Vector3(0.6, 1.8, 0.6), Vector3(hc.x + fw * 0.25, CURB + hh + 1.2, hc.z), Mats.building(Color(0.55, 0.3, 0.25), 1), false)
	# Puerta y porche
	var nrm := {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "w": Vector3(-1, 0, 0), "e": Vector3(1, 0, 0)}[door_side] as Vector3
	var dp := Vector3.ZERO
	match door_side:
		"n": dp = Vector3(hc.x, 0, h0.z)
		"s": dp = Vector3(hc.x, 0, h1.z)
		"w": dp = Vector3(h0.x, 0, hc.z)
		"e": dp = Vector3(h1.x, 0, hc.z)
	var door_m := Mats.color(Color(rng.randf_range(0.2, 0.7), rng.randf_range(0.15, 0.35), rng.randf_range(0.1, 0.3)), 0.6)
	Geo.box(root, Vector3(1.1, 2.2, 0.08) if absf(nrm.z) > 0.5 else Vector3(0.08, 2.2, 1.1), dp + nrm * 0.03 + Vector3(0, CURB + 1.1, 0), door_m, false)
	Geo.box(root, Vector3(2.4, 0.2, 1.4) if absf(nrm.z) > 0.5 else Vector3(1.4, 0.2, 2.4), dp + nrm * 0.7 + Vector3(0, CURB + 0.1, 0), Mats.color(Color(0.6, 0.45, 0.32)), true)
	Geo.box(root, Vector3(2.6, 0.1, 1.6) if absf(nrm.z) > 0.5 else Vector3(1.6, 0.1, 2.6), dp + nrm * 0.75 + Vector3(0, CURB + 2.6, 0), Mats.color(roof.darkened(0.1)), false)
	# Camino hasta la acera
	var edge := dp
	match door_side:
		"n": edge = Vector3(dp.x, 0, p0.z)
		"s": edge = Vector3(dp.x, 0, p1.z)
		"w": edge = Vector3(p0.x, 0, dp.z)
		"e": edge = Vector3(p1.x, 0, dp.z)
	var path_c := (dp + edge) * 0.5
	var plen := dp.distance_to(edge)
	Geo.box(root, Vector3(1.2, 0.012, plen) if absf(nrm.z) > 0.5 else Vector3(plen, 0.012, 1.2), path_c + Vector3(0, CURB + 0.008, 0), Mats.surface(Mats.Surf.SIDEWALK, Color(0.7, 0.66, 0.6), Color(0.5, 0.48, 0.44)), false, 0.0, false)
	if fence:
		_fence_lot(p0, p1, door_side, edge)
	_avoid_spot(bx, bz, edge)
	# Arbusto y árbol de jardín
	_tree(root, Vector3(p0.x + 1.0, CURB, p1.z - 1.0) if door_side != "s" else Vector3(p0.x + 1.0, CURB, p0.z + 1.0), 0.8, rng.randi() % 2)


func _fence_lot(p0: Vector3, p1: Vector3, gap_side: String, gap_at: Vector3) -> void:
	var fm := Mats.color(Color(0.92, 0.92, 0.9), 0.7)
	var y := CURB + 0.45
	var sides := {
		"n": [Vector3(p0.x, 0, p0.z + 0.1), Vector3(p1.x, 0, p0.z + 0.1)],
		"s": [Vector3(p0.x, 0, p1.z - 0.1), Vector3(p1.x, 0, p1.z - 0.1)],
		"w": [Vector3(p0.x + 0.1, 0, p0.z), Vector3(p0.x + 0.1, 0, p1.z)],
		"e": [Vector3(p1.x - 0.1, 0, p0.z), Vector3(p1.x - 0.1, 0, p1.z)],
	}
	for s in sides:
		var a: Vector3 = sides[s][0]
		var b: Vector3 = sides[s][1]
		var segs: Array = []
		if s == gap_side:
			var along_x := absf(b.x - a.x) > 0.1
			var g := gap_at.x if along_x else gap_at.z
			var g0 := g - 0.9
			var g1 := g + 0.9
			if along_x:
				segs = [[a, Vector3(g0, 0, a.z)], [Vector3(g1, 0, a.z), b]]
			else:
				segs = [[a, Vector3(a.x, 0, g0)], [Vector3(a.x, 0, g1), b]]
		else:
			segs = [[a, b]]
		for sg in segs:
			var sa: Vector3 = sg[0]
			var sb: Vector3 = sg[1]
			var len := sa.distance_to(sb)
			if len < 0.2:
				continue
			var mid := (sa + sb) * 0.5
			var along_x2 := absf(sb.x - sa.x) > 0.1
			Geo.box(root, Vector3(len, 0.9, 0.06) if along_x2 else Vector3(0.06, 0.9, len), mid + Vector3(0, y, 0), fm, true, 0.0, false)


# ================================================================== Mobiliario

func _pivot(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = yaw
	parent.add_child(p)
	return p


func _counter(parent: Node3D, pos: Vector3, size: Vector3, yaw: float, top: Color, body: Color) -> Node3D:
	var p := _pivot(parent, pos, yaw)
	Geo.box(p, size, Vector3(0, size.y * 0.5, 0), Mats.color(body, 0.7))
	Geo.box(p, Vector3(size.x + 0.08, 0.05, size.z + 0.08), Vector3(0, size.y + 0.025, 0), Mats.color(top, 0.35), false)
	return p


func _shelf(parent: Node3D, pos: Vector3, yaw: float, length: float, height: float = 1.9) -> void:
	var p := _pivot(parent, pos, yaw)
	var frame := Mats.color(Color(0.75, 0.75, 0.78), 0.5, 0.5)
	Geo.box(p, Vector3(length, height, 0.5), Vector3(0, height * 0.5, 0), Mats.color(Color(0.35, 0.35, 0.38), 0.8))
	for i in 4:
		var y := 0.15 + i * (height - 0.2) / 3.0
		Geo.box(p, Vector3(length, 0.04, 0.55), Vector3(0, y, 0.0), frame, false)
		var x := -length * 0.5 + 0.2
		while x < length * 0.5 - 0.2:
			var bw := rng.randf_range(0.15, 0.3)
			var bh := rng.randf_range(0.15, 0.35)
			var col := Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.8), rng.randf_range(0.6, 0.95))
			for side in [-1.0, 1.0]:
				Geo.box(p, Vector3(bw, bh, 0.2), Vector3(x + bw * 0.5, y + 0.02 + bh * 0.5, side * 0.15), Mats.color(col, 0.6), false, 0.0, false)
			x += bw + rng.randf_range(0.03, 0.08)


func _table(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var p := _pivot(parent, pos, 0.0)
	Geo.box(p, Vector3(size.x, 0.06, size.z), Vector3(0, size.y, 0), Mats.color(col, 0.5), false)
	Geo.cylinder(p, 0.05, size.y, Vector3(0, size.y * 0.5, 0), Mats.color(Color(0.2, 0.2, 0.22), 0.4, 0.6), false)
	Geo.collider(p, Vector3(size.x, size.y, size.z), Vector3(0, size.y * 0.5, 0))


func _stool(parent: Node3D, pos: Vector3, col: Color) -> void:
	Geo.cylinder(parent, 0.2, 0.08, pos + Vector3(0, 0.75, 0), Mats.color(col, 0.5), false)
	Geo.cylinder(parent, 0.04, 0.72, pos + Vector3(0, 0.36, 0), Mats.color(Color(0.7, 0.7, 0.72), 0.3, 0.8), false)


func _booth(parent: Node3D, pos: Vector3, yaw: float, col: Color) -> void:
	var p := _pivot(parent, pos, yaw)
	var seat := Mats.color(col, 0.6)
	for z in [-0.85, 0.85]:
		Geo.box(p, Vector3(1.6, 0.45, 0.55), Vector3(0, 0.22, z), seat)
		Geo.box(p, Vector3(1.6, 0.7, 0.15), Vector3(0, 0.75, z + signf(z) * 0.22), seat, false)
	Geo.box(p, Vector3(1.4, 0.06, 0.8), Vector3(0, 0.75, 0), Mats.color(Color(0.9, 0.88, 0.82), 0.3), false)
	Geo.collider(p, Vector3(1.4, 0.75, 0.8), Vector3(0, 0.37, 0))


func _bed(parent: Node3D, pos: Vector3, yaw: float, pid: String, col: Color = Color(0.3, 0.4, 0.6)) -> void:
	var p := _pivot(parent, pos, yaw)
	Geo.box(p, Vector3(1.5, 0.35, 2.1), Vector3(0, 0.18, 0), Mats.color(Color(0.4, 0.28, 0.18), 0.7))
	Geo.box(p, Vector3(1.4, 0.2, 2.0), Vector3(0, 0.45, 0), Mats.color(Color(0.92, 0.92, 0.9), 0.9), false)
	Geo.box(p, Vector3(1.42, 0.08, 1.4), Vector3(0, 0.58, 0.3), Mats.color(col, 0.9), false)
	Geo.box(p, Vector3(0.9, 0.12, 0.35), Vector3(0, 0.6, -0.75), Mats.color(Color(0.95, 0.95, 0.95), 0.9), false)
	Geo.box(p, Vector3(1.5, 0.9, 0.08), Vector3(0, 0.6, -1.05), Mats.color(Color(0.4, 0.28, 0.18), 0.7), false)
	var sleep_action := func(_pl: Node) -> void:
		if not Business.has_access(pid):
			Events.toast("Esta cama no es tuya.", "warn")
			return
		if Police.wanted >= Police.Wanted.PURSUIT:
			Events.toast("No puedes dormir con la policía detrás de ti.", "warn")
			return
		var hr := GameState.hour()
		if hr >= 7 and hr < 19:
			Events.toast("Aún no tienes sueño. Puedes dormir a partir de las 19:00.", "info")
			return
		Events.request_ui.emit("sleep", {})
	Interactable.create(p, Vector3(1.5, 0.8, 2.1), Vector3(0, 0.4, 0), "Dormir (hasta las 7:00)", sleep_action)


func _sink(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var p := _pivot(parent, pos, yaw)
	Geo.box(p, Vector3(0.9, 0.85, 0.55), Vector3(0, 0.42, 0), Mats.color(Color(0.85, 0.85, 0.82), 0.5))
	Geo.box(p, Vector3(0.6, 0.1, 0.4), Vector3(0, 0.82, 0), Mats.color(Color(0.7, 0.72, 0.75), 0.2, 0.8), false)
	Geo.cylinder(p, 0.025, 0.3, Vector3(0, 1.0, 0.2), Mats.color(Color(0.8, 0.8, 0.82), 0.2, 0.9), false)
	var fill := func(_pl: Node) -> void:
		var inv: Inventory = GameState.player_inventory
		var filled := 0
		for s in inv.slots:
			if s != null and s["id"] == "watering_can":
				s["data"]["water"] = int(ItemDB.get_prop("watering_can", "uses", 6))
				filled += 1
		if filled > 0:
			inv.changed.emit()
			Audio.play("water")
			Events.toast("Regadera llena.", "info")
		else:
			Audio.play("water", -8.0)
			Events.toast("Te lavas las manos. (Trae una regadera para rellenarla)", "info")
	Interactable.create(p, Vector3(0.9, 1.0, 0.6), Vector3(0, 0.5, 0), "Fregadero: rellenar regadera", fill)


func _fridge(parent: Node3D, pos: Vector3, yaw: float, glass: bool = true) -> void:
	var p := _pivot(parent, pos, yaw)
	Geo.box(p, Vector3(1.2, 2.0, 0.7), Vector3(0, 1.0, 0), Mats.color(Color(0.85, 0.87, 0.9), 0.3, 0.4))
	if glass:
		Geo.box(p, Vector3(1.05, 1.7, 0.02), Vector3(0, 1.05, 0.36), Mats.emissive(Color(0.75, 0.9, 1.0), 0.4), false)
		for i in 4:
			for j in 5:
				var col := Color.from_hsv(rng.randf(), 0.7, 0.9)
				Geo.box(p, Vector3(0.12, 0.25, 0.1), Vector3(-0.4 + j * 0.2, 0.4 + i * 0.42, 0.25), Mats.color(col, 0.4), false)


func _sofa(parent: Node3D, pos: Vector3, yaw: float, col: Color) -> void:
	var p := _pivot(parent, pos, yaw)
	var m := Mats.color(col, 0.9)
	Geo.box(p, Vector3(2.0, 0.45, 0.9), Vector3(0, 0.22, 0), m)
	Geo.box(p, Vector3(2.0, 0.6, 0.2), Vector3(0, 0.7, 0.35), m, false)
	for x in [-0.95, 0.95]:
		Geo.box(p, Vector3(0.18, 0.35, 0.9), Vector3(x, 0.55, 0), m, false)


func _tv(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var p := _pivot(parent, pos, yaw)
	Geo.box(p, Vector3(1.4, 0.5, 0.45), Vector3(0, 0.25, 0), Mats.color(Color(0.25, 0.18, 0.12), 0.6))
	Geo.box(p, Vector3(1.1, 0.65, 0.06), Vector3(0, 0.85, 0), Mats.color(Color(0.05, 0.05, 0.06), 0.2), false)
	Geo.box(p, Vector3(1.0, 0.56, 0.01), Vector3(0, 0.85, 0.035), Mats.emissive(Color(0.25, 0.35, 0.6), 0.6), false)


func _rug(parent: Node3D, pos: Vector3, size: Vector2, col: Color) -> void:
	Geo.box(parent, Vector3(size.x, 0.015, size.y), pos + Vector3(0, 0.02, 0), Mats.surface(Mats.Surf.CARPET, col, col.darkened(0.2), 2.0), false, 0.0, false)


func _plant(parent: Node3D, pos: Vector3) -> void:
	Geo.cylinder(parent, 0.22, 0.4, pos + Vector3(0, 0.2, 0), Mats.color(Color(0.7, 0.4, 0.25)), true, 0.28)
	Geo.sphere(parent, 0.4, pos + Vector3(0, 0.75, 0), Mats.color(Color(0.22, 0.5, 0.2), 0.8), 8)


func _crate_prop(pos: Vector3, idx: String) -> void:
	var p := PhysicsProp.make_box(w.props_root, "crate", "caja", Vector3(0.6, 0.5, 0.6), pos + Vector3(0, 0.3, 0), Color(0.6, 0.45, 0.28), 6.0)
	p.name = "crate_%s" % idx


func _barrel_prop(pos: Vector3, idx: String, col: Color = Color(0.2, 0.35, 0.6)) -> void:
	var p := PhysicsProp.make_cylinder(w.props_root, "barrel", "bidón", 0.3, 0.9, pos + Vector3(0, 0.5, 0), col, 12.0)
	p.name = "barrel_%s" % idx


func _trashcan_prop(pos: Vector3, idx: String) -> void:
	var p := PhysicsProp.make_cylinder(w.props_root, "trash", "papelera", 0.25, 0.8, pos + Vector3(0, 0.45, 0), Color(0.25, 0.4, 0.3), 5.0)
	p.name = "trash_%s" % idx


func _dumpster(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var p := _pivot(parent, pos, yaw)
	Geo.box(p, Vector3(2.0, 1.2, 1.1), Vector3(0, 0.6, 0), Mats.color(Color(0.18, 0.4, 0.25), 0.7, 0.3))
	Geo.box(p, Vector3(2.05, 0.08, 1.15), Vector3(0, 1.25, 0), Mats.color(Color(0.12, 0.12, 0.12), 0.6), false)


func _junk(pos: Vector3, item: String) -> void:
	WorldItem.spawn(w.items_root, item, 1, {}, pos + Vector3(0, 0.4, 0))


func _for_sale(parent: Node3D, pid: String, pos: Vector3, yaw: float) -> void:
	var p := _pivot(parent, pos, yaw)
	Geo.cylinder(p, 0.05, 1.2, Vector3(0, 0.6, 0), Mats.color(Color(0.5, 0.35, 0.2)), false)
	Geo.box(p, Vector3(1.0, 0.6, 0.05), Vector3(0, 1.4, 0), Mats.color(Color(0.85, 0.15, 0.15), 0.6), false)
	var price := int(Business.prop_defs.get(pid, {}).get("price", 0))
	var l := Geo.label(p, "SE VENDE\n$%d" % price, Vector3(0, 1.4, 0.04), 22, Color.WHITE)
	l.outline_size = 4
	var l2 := Geo.label(p, "SE VENDE\n$%d" % price, Vector3(0, 1.4, -0.04), 22, Color.WHITE)
	l2.rotation.y = PI
	var prompt_fn := func(_pl: Node) -> String:
		if Business.owns(pid):
			return "Tu propiedad: %s" % Business.property_name(pid)
		return "Comprar %s ($%d)" % [Business.property_name(pid), price]
	var buy_fn := func(_pl: Node) -> void:
		if Business.owns(pid):
			return
		var d: Dictionary = Business.prop_defs[pid]
		var on_yes := func() -> void:
			Business.buy_property(pid)
		var text := "%s\n\n%s\n\nPrecio: $%d (se paga con efectivo y banco).\nHuecos para estaciones: %d" % [d["name"], d.get("desc", ""), price, int(d["slots"])]
		Events.request_ui.emit("confirm", {"title": "Comprar propiedad", "text": text, "on_yes": on_yes})
	Interactable.create(p, Vector3(1.1, 1.8, 0.4), Vector3(0, 0.9, 0), "", buy_fn, prompt_fn)
	Events.property_acquired.connect(func(id: String) -> void:
		if id == pid and is_instance_valid(p):
			p.visible = false)


func _slots(parent: Node3D, pid: String, positions: Array, yaws: Array = []) -> void:
	for i in positions.size():
		var st := Station.new()
		parent.add_child(st)
		st.position = positions[i]
		st.rotation.y = float(yaws[i]) if i < yaws.size() else 0.0
		st.setup(pid, i)


func _npc(id: String, p_name: String, role: String, district: String, look: Dictionary, pos: Vector3, yaw: float, shop: String = "", hours: Vector2i = Vector2i(0, 24)) -> void:
	w.static_npc_specs.append({"id": id, "name": p_name, "role": role, "district": district, "look": look, "pos": pos + Vector3(0, 0.05, 0), "yaw": yaw, "shop": shop, "hours": hours})


func _location(id: String, pos: Vector3, size: Vector3 = Vector3.ZERO) -> void:
	w.locations[id] = pos
	if size == Vector3.ZERO:
		return
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = Geo.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	a.position = pos
	root.add_child(a)
	a.body_entered.connect(w._location_enter.bind(id))


func _meeting(bx: int, bz: int, id: String, p_name: String, side: String, along: float, pos: Vector3, yaw: float) -> void:
	add_spur(bx, bz, side, along, [pos])
	w.add_meeting_point(id, p_name, district_of(bx, bz), pos, yaw)


func _shop_lock(shop: String) -> Callable:
	return func() -> String:
		var p := GameState.player as Node3D
		if p and p.is_indoors:
			return ""
		if ShopData.is_open(shop):
			return ""
		return "Cerrado. Horario: %s" % ShopData.hours_text(shop)


func _hours_lock(open_h: int, close_h: int, label: String) -> Callable:
	return func() -> String:
		var p := GameState.player as Node3D
		if p and p.is_indoors:
			return ""
		if ShopData.hours_contain(open_h, close_h, GameState.hour()):
			return ""
		return "%s cerrado. Horario: %02d:00 - %02d:00" % [label, open_h, close_h % 24]


func _property_lock(pid: String) -> Callable:
	return func() -> String:
		var p := GameState.player as Node3D
		if p and p.current_property() == pid:
			return ""
		if Business.has_access(pid):
			return ""
		return "Cerrado con llave (%s)" % Business.property_name(pid)


# ================================================================== Northtown

func _northtown() -> void:
	var D := "northtown"
	# ---------------- Manzana (0,0): Motel Sunset, callejón, parque y casas
	var motel_mat := Mats.building(Color(0.86, 0.6, 0.5), 0, Color(0.95, 0.92, 0.85), false, 1.0, Vector2(3.0, 3.2), 0.4, true, Color(0.35, 0.3, 0.3))
	var office := shell(0, 0, Rect2(3, 3, 8, 11), 1, motel_mat, {"door_side": "n", "door_frac": 0.5, "sign": "RECEPCIÓN", "sign_w": 2.6, "poi": "Motel Sunset|home",
		"sign_bg": Color(0.2, 0.25, 0.35), "floor": Mats.surface(Mats.Surf.TILES, Color(0.8, 0.75, 0.65), Color(0.6, 0.5, 0.4)), "lock": _hours_lock(0, 24, "Recepción")})
	var oi: Vector3 = office["in0"]
	_counter(office["node"], oi + Vector3(3.8, 0, 5.0), Vector3(3.5, 1.05, 0.7), 0.0, Color(0.5, 0.35, 0.22), Color(0.6, 0.45, 0.3))
	_plant(office["node"], oi + Vector3(0.5, 0, 0.6))
	_sofa(office["node"], oi + Vector3(1.2, 0, 2.6), PI * 0.5, Color(0.55, 0.25, 0.25))
	_npc("gloria", "Gloria", "quest", D, {"skin": "#f1c9a5", "shirt": "#d77a8a", "pants": "#3b3b55", "hair": "#a0522d", "female": true}, oi + Vector3(3.8, 0, 6.2), 0.0)
	var room := shell(0, 0, Rect2(11, 3, 12, 11), 1, motel_mat, {"door_side": "n", "door_frac": 0.3, "property": "motel_room", "door_name": "puerta de la habitación 4", "map_color": Color(0.3, 0.6, 0.35),
		"lock": _property_lock("motel_room"), "wall_col": Color(0.78, 0.74, 0.62), "floor": Mats.surface(Mats.Surf.CARPET, Color(0.45, 0.35, 0.3), Color(0.35, 0.28, 0.25))})
	var ri: Vector3 = room["in0"]
	_bed(room["node"], ri + Vector3(9.5, 0, 6.5), 0.0, "motel_room", Color(0.55, 0.3, 0.3))
	_tv(room["node"], ri + Vector3(9.5, 0, 1.0), PI)
	_sink(room["node"], ri + Vector3(0.5, 0, 9.0), PI * 0.5)
	_rug(room["node"], ri + Vector3(6.0, 0, 5.0), Vector2(3.0, 2.0), Color(0.6, 0.5, 0.3))
	_slots(room["node"], "motel_room", [ri + Vector3(2.0, 0, 3.0), ri + Vector3(2.0, 0, 6.0), ri + Vector3(5.5, 0, 9.0)])
	Geo.label(room["node"], "4", (room["door_pos"] as Vector3) + Vector3(0.9, 2.2, -0.2), 64, Color(1, 0.9, 0.5))
	w.property_spawns["motel_room"] = {"pos": ri + Vector3(5.5, 0.2, 3.5), "yaw": 0.0}
	w.employee_spots["motel_room"] = [ri + Vector3(7.0, 0.1, 2.0)]
	w.player_spawn = ri + Vector3(5.5, 0.2, 3.5)
	w.player_spawn_yaw = 0.0
	# Porche cubierto del motel
	var por := L(0, 0, 13, 1.6)
	Geo.box(root, Vector3(20, 0.15, 2.6), por + Vector3(0, CURB + 2.9, 0), Mats.color(Color(0.95, 0.92, 0.85), 0.7), false)
	for x in [3.3, 8.0, 13.0, 18.0, 22.7]:
		Geo.cylinder(root, 0.08, 2.9, L(0, 0, x, 0.6, CURB + 1.45), Mats.color(Color(0.95, 0.92, 0.85)), true)
	# Letrero gigante del motel
	var pole := L(0, 0, 4.5, 1.0)
	Geo.cylinder(root, 0.15, 7.0, pole + Vector3(0, CURB + 3.5, 0), Mats.color(Color(0.5, 0.5, 0.52), 0.4, 0.6), true)
	Geo.sign_board(root, "SUNSET MOTEL", pole + Vector3(0, CURB + 6.4, 0), PI, 4.2, Color(0.9, 0.35, 0.25), Color(1.0, 0.95, 0.6), 1.2)
	Geo.sign_board(root, "SUNSET MOTEL", pole + Vector3(0, CURB + 6.4, 0), 0.0, 4.2, Color(0.9, 0.35, 0.25), Color(1.0, 0.95, 0.6), 1.2)
	# Callejón trasero
	_dumpster(root, L(0, 0, 6, 16.5, CURB), 0.0)
	_dumpster(root, L(0, 0, 20, 16.0, CURB), 0.3)
	_crate_prop(L(0, 0, 9, 17, CURB), "nt0")
	_crate_prop(L(0, 0, 9.7, 17.2, CURB), "nt1")
	_trashcan_prop(L(0, 0, 13, 15.6, CURB), "nt0")
	_junk(L(0, 0, 17, 19, CURB), "scrap_metal")
	_location("motel_alley", L(0, 0, 15, 18.5, CURB))
	_meeting(0, 0, "nt_alley", "el callejón del motel", "w", L(0, 0, 0, 18).z, L(0, 0, 11, 19, CURB), PI * 0.5)
	# Parque Sunset
	var pk := L(0, 0, 12.5, 30.5)
	Geo.box(root, Vector3(19, 0.01, 13), pk + Vector3(0, CURB + 0.005, 0), Mats.surface(Mats.Surf.GRASS, Color(0.3, 0.5, 0.2), Color(0.4, 0.55, 0.24), 0.8), false, 0.0, false)
	Geo.box(root, Vector3(1.6, 0.012, 13), L(0, 0, 12.5, 30.5, CURB + 0.01), Mats.surface(Mats.Surf.DIRT, Color(0.6, 0.5, 0.36), Color(0.5, 0.42, 0.3)), false, 0.0, false)
	for tp in [Vector2(5, 26), Vector2(19, 27), Vector2(6, 35), Vector2(20, 35)]:
		_tree(root, L(0, 0, tp.x, tp.y, CURB), rng.randf_range(0.9, 1.2), 0)
	_bench(root, L(0, 0, 10.6, 30, CURB), PI * 0.5)
	_bench(root, L(0, 0, 14.4, 30, CURB), -PI * 0.5)
	_meeting(0, 0, "nt_park", "el parque Sunset", "s", L(0, 0, 12.5, 0).x, L(0, 0, 12.5, 32, CURB), PI)
	# Casas
	house(0, 0, Rect2(25, 3, 12, 15), Color(0.45, 0.6, 0.75), Color(0.35, 0.25, 0.22), "n")
	house(0, 0, Rect2(25, 21, 12, 16), Color(0.75, 0.72, 0.5), Color(0.3, 0.3, 0.35), "e")

	# ---------------- Manzana (1,0): Gas-Mart, aparcamiento, Elm Apartments, comisaría
	var gm_mat := Mats.building(Color(0.92, 0.92, 0.9), 2, Color(0.85, 0.2, 0.2), true, 2.0, Vector2(3.5, 3.4), 0.3)
	var gm := shell(1, 0, Rect2(3, 3, 14, 12), 1, gm_mat, {"door_side": "n", "door_frac": 0.5, "glass_door": true, "door_color": Color(0.8, 0.82, 0.85),
		"sign": "GAS-MART", "sign_w": 5.0, "poi": "Gas-Mart|shop", "sign_bg": Color(0.85, 0.15, 0.15), "awning": Color(0.85, 0.15, 0.15),
		"floor": Mats.surface(Mats.Surf.TILES, Color(0.9, 0.9, 0.88), Color(0.75, 0.75, 0.72)), "lock": _shop_lock("gasmart"), "light_energy": 1.6})
	var gi: Vector3 = gm["in0"]
	_counter(gm["node"], gi + Vector3(2.0, 0, 5.5), Vector3(0.7, 1.0, 3.0), 0.0, Color(0.85, 0.85, 0.82), Color(0.8, 0.2, 0.2))
	Geo.box(gm["node"], Vector3(0.4, 0.3, 0.4), gi + Vector3(2.0, 1.2, 5.0), Mats.color(Color(0.15, 0.15, 0.15)), false)
	_shelf(gm["node"], gi + Vector3(7.0, 0, 4.0), 0.0, 4.0, 1.6)
	_shelf(gm["node"], gi + Vector3(7.0, 0, 7.0), 0.0, 4.0, 1.6)
	_fridge(gm["node"], gi + Vector3(12.5, 0, 6.0), -PI * 0.5)
	_fridge(gm["node"], gi + Vector3(12.5, 0, 8.0), -PI * 0.5)
	_npc("clerk_gasmart", "Dev", "shopkeeper", D, {"skin": "#a46f4c", "shirt": "#c0392b", "pants": "#2b2f3a", "hair": "#111111"}, gi + Vector3(1.0, 0, 5.5), PI * 0.5, "gasmart", Vector2i(6, 24))
	# Aparcamiento
	var pl := L(1, 0, 27.5, 9.5)
	Geo.box(root, Vector3(19, 0.012, 13), pl + Vector3(0, CURB + 0.006, 0), Mats.surface(Mats.Surf.CONCRETE, Color(0.3, 0.3, 0.31), Color(0.2, 0.2, 0.2)), false, 0.0, false)
	for i in 5:
		Geo.box(root, Vector3(0.1, 0.015, 4.5), L(1, 0, 19 + i * 4.2, 11.5, CURB + 0.012), Mats.color(Color(0.9, 0.9, 0.9)), false, 0.0, false)
	CarModel.parked(root, L(1, 0, 21.1, 11.5, CURB), 0.0, Color(CarModel.COLORS[0]))
	CarModel.parked(root, L(1, 0, 29.5, 11.5, CURB), 0.0, Color(CarModel.COLORS[6]))
	_meeting(1, 0, "nt_parking", "el aparcamiento del Gas-Mart", "n", L(1, 0, 33, 0).x, L(1, 0, 33, 7, CURB), 0.0)
	# Elm Apartments (propiedad)
	var elm_mat := Mats.building(Color(0.55, 0.28, 0.22), 1, Color(0.9, 0.88, 0.82), false, 3.0)
	var elm := shell(1, 0, Rect2(3, 20, 14, 17), 3, elm_mat, {"door_side": "w", "door_frac": 0.5, "property": "elm_apartment", "lock": _property_lock("elm_apartment"),
		"door_name": "puerta del apartamento", "sign": "ELM APARTMENTS", "sign_w": 4.5, "poi": "Elm Apartments (en venta)|property", "sign_bg": Color(0.2, 0.3, 0.25),
		"wall_col": Color(0.85, 0.85, 0.8), "floor": Mats.surface(Mats.Surf.WOOD, Color(0.6, 0.45, 0.3), Color(0.5, 0.35, 0.22))})
	var ei: Vector3 = elm["in0"]
	_bed(elm["node"], ei + Vector3(11.5, 0, 14.0), PI, "elm_apartment", Color(0.3, 0.45, 0.35))
	_sofa(elm["node"], ei + Vector3(11.0, 0, 3.0), -PI * 0.5, Color(0.35, 0.35, 0.45))
	_tv(elm["node"], ei + Vector3(8.0, 0, 3.0), PI * 0.5)
	_sink(elm["node"], ei + Vector3(0.6, 0, 15.0), PI * 0.5)
	_counter(elm["node"], ei + Vector3(0.6, 0, 12.8), Vector3(0.8, 0.9, 2.5), 0.0, Color(0.85, 0.85, 0.85), Color(0.5, 0.4, 0.3))
	_rug(elm["node"], ei + Vector3(9.5, 0, 3.0), Vector2(3, 3), Color(0.55, 0.2, 0.2))
	_slots(elm["node"], "elm_apartment", [ei + Vector3(3.0, 0, 2.0), ei + Vector3(6.0, 0, 2.0), ei + Vector3(3.0, 0, 6.0), ei + Vector3(6.0, 0, 6.0), ei + Vector3(4.5, 0, 11.0)])
	_for_sale(root, "elm_apartment", (elm["door_pos"] as Vector3) + Vector3(-1.4, CURB, 2.2), -PI * 0.5)
	w.property_spawns["elm_apartment"] = {"pos": ei + Vector3(2.0, 0.2, 8.5), "yaw": -PI * 0.5}
	w.employee_spots["elm_apartment"] = [ei + Vector3(9.0, 0.1, 8.0), ei + Vector3(9.0, 0.1, 10.0)]
	# Comisaría (exterior)
	var pol_mat := Mats.building(Color(0.72, 0.76, 0.8), 2, Color(0.2, 0.3, 0.55), false, 4.0, Vector2(3.0, 3.2), 0.5)
	solid(1, 0, Rect2(21, 20, 16, 17), 2, pol_mat, {"door_side": "s", "door_frac": 0.5, "sign": "COMISARÍA DE POLICÍA", "sign_w": 6.0, "poi": "Comisaría|police", "sign_bg": Color(0.1, 0.2, 0.5), "door_color": Color(0.2, 0.25, 0.35)})
	w.police_station_pos = L(1, 0, 29, 39, CURB + 0.2)
	Geo.cylinder(root, 0.06, 7.0, L(1, 0, 34, 38.5, CURB + 3.5), Mats.color(Color(0.8, 0.8, 0.82), 0.3, 0.8), true)
	Geo.box(root, Vector3(1.4, 0.9, 0.03), L(1, 0, 34.7, 38.5, CURB + 6.4), Mats.color(Color(0.2, 0.35, 0.7)), false)

	# ---------------- Manzana (0,1): Lucky Diner, Ferretería, Taller, casa
	var diner_mat := Mats.building(Color(0.55, 0.78, 0.76), 3, Color(0.85, 0.2, 0.25), true, 5.0, Vector2(2.6, 3.4), 0.3)
	var diner := shell(0, 1, Rect2(3, 3, 15, 12), 1, diner_mat, {"door_side": "n", "door_frac": 0.5, "glass_door": true, "door_color": Color(0.85, 0.2, 0.25),
		"sign": "LUCKY DINER", "sign_w": 5.0, "poi": "Lucky Diner|quest", "sign_bg": Color(0.15, 0.15, 0.2), "sign_fg": Color(1.0, 0.4, 0.6), "awning": Color(0.85, 0.2, 0.25),
		"floor": Mats.surface(Mats.Surf.TILES, Color(0.92, 0.92, 0.9), Color(0.12, 0.12, 0.12)), "lock": _hours_lock(6, 23, "El Lucky Diner"),
		"wall_col": Color(0.95, 0.93, 0.85), "light_color": Color(1.0, 0.9, 0.75)})
	var di: Vector3 = diner["in0"]
	_counter(diner["node"], di + Vector3(9.0, 0, 8.5), Vector3(8.0, 1.05, 0.7), 0.0, Color(0.85, 0.85, 0.85), Color(0.75, 0.15, 0.2))
	for i in 5:
		_stool(diner["node"], di + Vector3(6.0 + i * 1.5, 0, 7.6), Color(0.8, 0.15, 0.2))
	_booth(diner["node"], di + Vector3(1.5, 0, 3.0), PI * 0.5, Color(0.8, 0.15, 0.2))
	_booth(diner["node"], di + Vector3(1.5, 0, 7.5), PI * 0.5, Color(0.8, 0.15, 0.2))
	_fridge(diner["node"], di + Vector3(13.8, 0, 10.2), PI, false)
	_npc("marco", "Marco", "quest", D, {"skin": "#c99470", "shirt": "#2c3e50", "pants": "#1e2228", "hair": "#2a1a10"}, di + Vector3(3.0, 0, 5.2), PI * 0.5, "", Vector2i(7, 23))
	_npc("rosa", "Rosa", "quest", D, {"skin": "#e7bf9b", "shirt": "#f5f5f5", "pants": "#c0392b", "hair": "#5a2f1a", "female": true}, di + Vector3(9.0, 0, 9.6), 0.0, "", Vector2i(6, 23))
	_location("diner", di + Vector3(7.5, 1.0, 5.0), Vector3(13.0, 2.5, 10.0))
	var hw_mat := Mats.building(Color(0.6, 0.38, 0.25), 1, Color(0.9, 0.85, 0.7), true, 6.0)
	var hw := shell(0, 1, Rect2(21, 3, 16, 12), 1, hw_mat, {"door_side": "n", "door_frac": 0.4, "glass_door": true, "sign": "FERRETERÍA HANK", "sign_w": 5.5, "poi": "Ferretería Hank|shop",
		"sign_bg": Color(0.95, 0.6, 0.1), "sign_fg": Color(0.1, 0.1, 0.1), "awning": Color(0.2, 0.45, 0.25), "lock": _shop_lock("hardware"),
		"floor": Mats.surface(Mats.Surf.CONCRETE, Color(0.55, 0.55, 0.53), Color(0.45, 0.45, 0.44))})
	var hi: Vector3 = hw["in0"]
	_counter(hw["node"], hi + Vector3(12.0, 0, 3.0), Vector3(3.5, 1.0, 0.8), 0.0, Color(0.6, 0.45, 0.3), Color(0.3, 0.45, 0.3))
	_shelf(hw["node"], hi + Vector3(4.0, 0, 6.0), 0.0, 5.0)
	_shelf(hw["node"], hi + Vector3(4.0, 0, 9.0), 0.0, 5.0)
	_shelf(hw["node"], hi + Vector3(11.0, 0, 9.5), 0.0, 5.0)
	_npc("hank", "Hank", "shopkeeper", D, {"skin": "#f0c8a8", "shirt": "#3e8e5a", "pants": "#3a2c22", "hair": "#888888"}, hi + Vector3(12.0, 0, 4.0), 0.0, "hardware", Vector2i(7, 20))
	# Taller de Tony (frente abierto)
	var gar_mat := Mats.building(Color(0.5, 0.52, 0.55), 2, Color(0.9, 0.7, 0.1), false, 7.0, Vector2(4.0, 3.4), 0.2, false)
	var gar := shell(0, 1, Rect2(3, 21, 13, 16), 1, gar_mat, {"door_side": "w", "door_frac": 0.45, "door_w": 4.5, "open_front": true, "sign": "TALLER TONY", "sign_w": 4.0, "poi": "Taller de Tony|quest",
		"sign_bg": Color(0.9, 0.7, 0.1), "sign_fg": Color(0.1, 0.1, 0.1), "floor": Mats.surface(Mats.Surf.CONCRETE, Color(0.45, 0.45, 0.45), Color(0.3, 0.3, 0.3))})
	var ti: Vector3 = gar["in0"]
	CarModel.parked(gar["node"], ti + Vector3(6.5, 0.3, 6.0), PI * 0.5, Color(CarModel.COLORS[4]))
	Geo.box(gar["node"], Vector3(4.6, 0.3, 2.4), ti + Vector3(6.5, 0.15, 6.0), Mats.color(Color(0.8, 0.6, 0.1), 0.5, 0.4))
	_counter(gar["node"], ti + Vector3(10.0, 0, 13.5), Vector3(3.0, 0.95, 0.8), 0.0, Color(0.3, 0.3, 0.3), Color(0.6, 0.15, 0.1))
	_barrel_prop(ti + Vector3(11.5, 0, 1.0), "gar0", Color(0.7, 0.2, 0.1))
	_junk(ti + Vector3(2.0, 0, 13.5), "old_radio")
	_npc("tony", "Tony", "quest", D, {"skin": "#d9a27a", "shirt": "#34495e", "pants": "#22252b", "hair": "#2a1a10"}, ti + Vector3(9.5, 0, 12.4), 0.0, "", Vector2i(8, 20))
	house(0, 1, Rect2(21, 21, 16, 16), Color(0.8, 0.55, 0.45), Color(0.3, 0.22, 0.2), "s")

	# ---------------- Manzana (1,1): bloques de pisos y el callejón de Ray
	solid(1, 1, Rect2(3, 3, 12, 34), 4, Mats.building(Color(0.62, 0.35, 0.28), 1, Color(0.85, 0.82, 0.75), false, 8.0), {"door_side": "w", "door_frac": 0.3})
	solid(1, 1, Rect2(25, 3, 12, 34), 3, Mats.building(Color(0.85, 0.75, 0.5), 0, Color(0.55, 0.4, 0.3), false, 9.0), {"door_side": "e", "door_frac": 0.6})
	Geo.box(root, Vector3(10, 0.012, 34), L(1, 1, 20, 20, CURB + 0.006), Mats.surface(Mats.Surf.CONCRETE, Color(0.35, 0.34, 0.33), Color(0.25, 0.25, 0.24)), false, 0.0, false)
	# Puesto de Ray
	var stall := L(1, 1, 20, 22)
	_counter(root, stall + Vector3(0, CURB, 0), Vector3(2.4, 0.9, 0.8), 0.0, Color(0.5, 0.4, 0.3), Color(0.35, 0.3, 0.25))
	for x in [-1.4, 1.4]:
		Geo.cylinder(root, 0.05, 2.6, stall + Vector3(x, CURB + 1.3, -0.6), Mats.color(Color(0.4, 0.4, 0.42)), true)
		Geo.cylinder(root, 0.05, 2.6, stall + Vector3(x, CURB + 1.3, 1.6), Mats.color(Color(0.4, 0.4, 0.42)), true)
	var tarp := Geo.box(root, Vector3(3.2, 0.05, 2.6), stall + Vector3(0, CURB + 2.65, 0.5), Mats.color(Color(0.2, 0.35, 0.6), 0.9), false)
	tarp.rotation.x = -0.12
	for i in 8:
		var col := Color.from_hsv(float(i) / 8.0, 0.6, 1.0)
		Geo.sphere(root, 0.06, stall + Vector3(-1.4 + i * 0.4, CURB + 2.5, -0.62), Mats.emissive(col, 3.0), 6)
	_crate_prop(stall + Vector3(-2.2, CURB, 1.0), "ray0")
	_crate_prop(stall + Vector3(-2.2, CURB + 0.55, 1.0), "ray1")
	_dumpster(root, L(1, 1, 18, 33, CURB), PI * 0.5)
	w.pois.append({"name": "Puesto de Ray", "pos": stall, "kind": "shop"})
	_npc("ray", "Ray", "shopkeeper", D, {"skin": "#8d5a3b", "shirt": "#2fa38a", "pants": "#25303a", "hair": "#0f0f12"}, stall + Vector3(0, CURB, 1.0), 0.0, "ray", Vector2i(10, 2))
	add_spur(1, 1, "n", L(1, 1, 20, 0).x, [L(1, 1, 20, 8, CURB), L(1, 1, 20, 18, CURB)])
	_meeting(1, 1, "nt_ray_alley", "el callejón de Ray", "s", L(1, 1, 20, 0).x, L(1, 1, 20, 30, CURB), PI)


func _bench(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var p := _pivot(parent, pos, yaw)
	var wood := Mats.color(Color(0.5, 0.33, 0.2), 0.8)
	var iron := Mats.color(Color(0.15, 0.15, 0.16), 0.5, 0.6)
	Geo.box(p, Vector3(1.8, 0.08, 0.5), Vector3(0, 0.45, 0), wood, false)
	Geo.box(p, Vector3(1.8, 0.4, 0.06), Vector3(0, 0.75, 0.24), wood, false)
	for x in [-0.8, 0.8]:
		Geo.box(p, Vector3(0.06, 0.45, 0.5), Vector3(x, 0.22, 0), iron, false)
	Geo.collider(p, Vector3(1.8, 0.5, 0.5), Vector3(0, 0.25, 0))


func _tree(parent: Node3D, pos: Vector3, s: float = 1.0, kind: int = 0) -> void:
	var trunk := Mats.color(Color(0.36, 0.25, 0.16), 0.9)
	Geo.cylinder(parent, 0.16 * s, 2.4 * s, pos + Vector3(0, 1.2 * s, 0), trunk, true, 0.11 * s, 7)
	if kind == 0:
		var greens := [Color(0.22, 0.45, 0.18), Color(0.28, 0.52, 0.2), Color(0.2, 0.4, 0.16)]
		var g1 := Geo.sphere(parent, 1.5 * s, pos + Vector3(0, 3.2 * s, 0), Mats.color(greens[rng.randi() % 3], 0.85), 10)
		var g2 := Geo.sphere(parent, 1.1 * s, pos + Vector3(0.7 * s, 3.9 * s, 0.3 * s), Mats.color(greens[rng.randi() % 3], 0.85), 8)
		var g3 := Geo.sphere(parent, 1.0 * s, pos + Vector3(-0.6 * s, 3.7 * s, -0.4 * s), Mats.color(greens[rng.randi() % 3], 0.85), 8)
		for g in [g1, g2, g3]:
			(g as GeometryInstance3D).visibility_range_end = 180.0
	else:
		var pine := Mats.color(Color(0.16, 0.35, 0.2), 0.85)
		for i in 3:
			var c := Geo.cylinder(parent, (1.6 - i * 0.4) * s, 1.8 * s, pos + Vector3(0, (2.4 + i * 1.1) * s, 0), pine, false, 0.0, 8)
			c.visibility_range_end = 180.0


# ================================================================== Downtown

func _downtown() -> void:
	var D := "downtown"
	# ---------------- Manzana (2,0): torres y banco
	solid(2, 0, Rect2(3, 3, 15, 15), 9, Mats.building(Color(0.42, 0.5, 0.6), 2, Color(0.8, 0.85, 0.9), false, 11.0, Vector2(2.0, 3.2), 0.55), {"door_side": "n", "door_frac": 0.5, "door_w": 2.4, "door_color": Color(0.3, 0.4, 0.5)})
	solid(2, 0, Rect2(21, 3, 16, 15), 7, Mats.building(Color(0.78, 0.72, 0.6), 2, Color(0.4, 0.35, 0.3), false, 12.0, Vector2(2.4, 3.2), 0.5), {"door_side": "n", "door_frac": 0.5, "door_w": 2.0})
	var bank_mat := Mats.building(Color(0.88, 0.85, 0.76), 2, Color(0.6, 0.55, 0.45), true, 13.0, Vector2(3.0, 3.4), 0.3)
	var bank := shell(2, 0, Rect2(3, 21, 17, 16), 2, bank_mat, {"door_side": "s", "door_frac": 0.5, "glass_door": true, "door_color": Color(0.75, 0.65, 0.35),
		"sign": "BANCO REDMONT", "sign_w": 5.5, "poi": "Banco (cajero)|bank", "sign_bg": Color(0.15, 0.25, 0.2), "sign_fg": Color(1.0, 0.85, 0.4), "lock": _hours_lock(7, 22, "El banco"),
		"floor": Mats.surface(Mats.Surf.TILES, Color(0.9, 0.88, 0.84), Color(0.7, 0.68, 0.64)), "light_energy": 1.5})
	var bi: Vector3 = bank["in0"]
	_counter(bank["node"], bi + Vector3(8.2, 0, 3.0), Vector3(10.0, 1.1, 0.8), 0.0, Color(0.3, 0.25, 0.2), Color(0.55, 0.42, 0.3))
	_plant(bank["node"], bi + Vector3(0.6, 0, 14.6))
	_plant(bank["node"], bi + Vector3(15.8, 0, 14.6))
	_npc("teller", "Cajera", "quest", D, {"skin": "#f2d0b0", "shirt": "#26324a", "pants": "#1a1a22", "hair": "#3a1f14", "female": true}, bi + Vector3(8.2, 0, 2.0), PI, "", Vector2i(7, 22))
	var atm := _pivot(bank["node"], bi + Vector3(1.0, 0, 8.0), PI * 0.5)
	Geo.box(atm, Vector3(0.9, 1.7, 0.6), Vector3(0, 0.85, 0), Mats.color(Color(0.3, 0.32, 0.36), 0.4, 0.5))
	Geo.box(atm, Vector3(0.5, 0.35, 0.02), Vector3(0, 1.25, 0.31), Mats.emissive(Color(0.3, 0.6, 1.0), 1.2), false)
	Interactable.create(atm, Vector3(0.9, 1.7, 0.7), Vector3(0, 0.85, 0), "Cajero automático", func(_p: Node) -> void: Events.request_ui.emit("atm", {}))
	# Plaza
	var pz := L(2, 0, 29, 29)
	Geo.cylinder(root, 2.4, 0.6, pz + Vector3(0, CURB + 0.3, 0), Mats.surface(Mats.Surf.CONCRETE, Color(0.75, 0.73, 0.7)), true, -1.0, 20)
	Geo.cylinder(root, 2.1, 0.1, pz + Vector3(0, CURB + 0.6, 0), Mats.water(), false, -1.0, 20)
	Geo.cylinder(root, 0.3, 1.8, pz + Vector3(0, CURB + 1.2, 0), Mats.surface(Mats.Surf.CONCRETE, Color(0.75, 0.73, 0.7)), false)
	for tp in [Vector2(23, 23), Vector2(35, 23), Vector2(23, 35), Vector2(35, 35)]:
		_tree(root, L(2, 0, tp.x, tp.y, CURB), 1.0, 0)
	_bench(root, L(2, 0, 29, 24.5, CURB), PI)
	_bench(root, L(2, 0, 29, 33.5, CURB), 0.0)
	_meeting(2, 0, "dt_plaza", "la plaza del banco", "e", L(2, 0, 0, 29).z, L(2, 0, 33, 29, CURB), -PI * 0.5)

	# ---------------- Manzana (3,0): Neon Lounge, casa de empeños, torre
	var neon_mat := Mats.building(Color(0.3, 0.22, 0.35), 0, Color(0.9, 0.3, 0.8), false, 14.0, Vector2(3.0, 3.2), 0.5)
	var bar := shell(3, 0, Rect2(3, 3, 16, 14), 2, neon_mat, {"door_side": "n", "door_frac": 0.5, "door_color": Color(0.15, 0.1, 0.18),
		"sign": "NEON LOUNGE", "sign_w": 5.0, "poi": "Neon Lounge|quest", "sign_bg": Color(0.25, 0.05, 0.3), "sign_fg": Color(1.0, 0.4, 0.9), "lock": _hours_lock(12, 28, "El Neon Lounge"),
		"floor": Mats.surface(Mats.Surf.WOOD, Color(0.25, 0.16, 0.12), Color(0.18, 0.12, 0.09)), "wall_col": Color(0.35, 0.25, 0.4), "light_color": Color(0.85, 0.5, 1.0), "light_energy": 1.4})
	var ni: Vector3 = bar["in0"]
	_counter(bar["node"], ni + Vector3(8.0, 0, 11.0), Vector3(9.0, 1.1, 0.8), 0.0, Color(0.15, 0.1, 0.08), Color(0.35, 0.2, 0.3))
	for i in 12:
		var bc := Color.from_hsv(rng.randf(), 0.7, 1.0)
		Geo.cylinder(bar["node"], 0.06, 0.32, ni + Vector3(4.0 + i * 0.7, 1.6, 13.2), Mats.emissive(bc, 0.8), false)
	Geo.box(bar["node"], Vector3(9.5, 0.05, 0.4), ni + Vector3(8.0, 1.42, 13.2), Mats.color(Color(0.3, 0.2, 0.15)), false)
	for i in 5:
		_stool(bar["node"], ni + Vector3(4.5 + i * 1.6, 0, 10.0), Color(0.6, 0.1, 0.5))
	for tp in [Vector3(3.0, 0, 3.0), Vector3(7.0, 0, 4.0), Vector3(12.0, 0, 3.5)]:
		_table(bar["node"], ni + tp, Vector3(1.0, 1.0, 1.0), Color(0.2, 0.15, 0.12))
	_npc("vince", "Vince", "quest", D, {"skin": "#eac0a0", "shirt": "#1a1a1a", "pants": "#26324a", "hair": "#111111"}, ni + Vector3(8.0, 0, 12.2), 0.0, "", Vector2i(12, 4))
	var pawn_mat := Mats.building(Color(0.5, 0.42, 0.35), 1, Color(0.9, 0.8, 0.5), true, 15.0)
	var pawn := shell(3, 0, Rect2(22, 3, 15, 12), 2, pawn_mat, {"door_side": "n", "door_frac": 0.5, "sign": "EMPEÑOS SAL", "sign_w": 4.5, "poi": "Empeños Sal|shop",
		"sign_bg": Color(0.1, 0.1, 0.1), "sign_fg": Color(1.0, 0.85, 0.2), "awning": Color(0.1, 0.3, 0.15), "lock": _shop_lock("pawn"),
		"floor": Mats.surface(Mats.Surf.TILES, Color(0.55, 0.45, 0.35), Color(0.45, 0.35, 0.28))})
	var pi_: Vector3 = pawn["in0"]
	_counter(pawn["node"], pi_ + Vector3(7.2, 0, 6.5), Vector3(8.0, 1.0, 0.8), 0.0, Color(0.7, 0.85, 0.9), Color(0.35, 0.25, 0.2))
	_shelf(pawn["node"], pi_ + Vector3(4.0, 0, 10.5), 0.0, 6.0)
	_shelf(pawn["node"], pi_ + Vector3(11.0, 0, 10.5), 0.0, 6.0)
	_npc("sal", "Sal", "shopkeeper", D, {"skin": "#d6a27e", "shirt": "#7d5a3b", "pants": "#2a2a2a", "hair": "#9a9a9a"}, pi_ + Vector3(7.2, 0, 7.6), 0.0, "pawn", Vector2i(9, 21))
	solid(3, 0, Rect2(3, 21, 34, 16), 8, Mats.building(Color(0.35, 0.42, 0.5), 2, Color(0.7, 0.75, 0.8), false, 16.0, Vector2(2.2, 3.2), 0.6), {"door_side": "s", "door_frac": 0.5, "door_w": 3.0})

	# ---------------- Manzana (2,1): galerías y aparcamiento
	solid(2, 1, Rect2(3, 3, 34, 15), 3, Mats.building(Color(0.9, 0.85, 0.8), 2, Color(0.8, 0.3, 0.2), true, 17.0, Vector2(4.0, 3.6), 0.4), {"door_side": "n", "door_frac": 0.5, "door_w": 3.0, "sign": "GALERÍAS REDMONT", "sign_w": 7.0, "sign_bg": Color(0.8, 0.3, 0.2)})
	var pk := L(2, 1, 20, 29)
	Geo.box(root, Vector3(34, 0.012, 16), pk + Vector3(0, CURB + 0.006, 0), Mats.surface(Mats.Surf.CONCRETE, Color(0.3, 0.3, 0.31), Color(0.22, 0.22, 0.22)), false, 0.0, false)
	for i in 4:
		CarModel.parked(root, L(2, 1, 6 + i * 4.5, 25, CURB), 0.0, Color(CarModel.COLORS[(i * 3 + 1) % CarModel.COLORS.size()]))
	_meeting(2, 1, "dt_parking", "el aparcamiento de Galerías", "s", L(2, 1, 30, 0).x, L(2, 1, 30, 32, CURB), PI)

	# ---------------- Manzana (3,1): parque central y torre
	var park := L(3, 1, 11, 20)
	Geo.box(root, Vector3(18, 0.01, 34), park + Vector3(0, CURB + 0.005, 0), Mats.surface(Mats.Surf.GRASS, Color(0.3, 0.5, 0.2), Color(0.4, 0.55, 0.24), 0.8), false, 0.0, false)
	for i in 7:
		_tree(root, L(3, 1, rng.randf_range(4, 18), 4 + i * 4.8, CURB), rng.randf_range(0.9, 1.3), rng.randi() % 2)
	_bench(root, L(3, 1, 11, 20, CURB), PI * 0.5)
	_meeting(3, 1, "dt_park", "el parque central", "w", L(3, 1, 0, 20).z, L(3, 1, 9, 20, CURB), PI * 0.5)
	solid(3, 1, Rect2(23, 3, 14, 34), 10, Mats.building(Color(0.25, 0.3, 0.38), 2, Color(0.6, 0.65, 0.7), false, 18.0, Vector2(2.0, 3.2), 0.6), {"door_side": "e", "door_frac": 0.5, "door_w": 2.6})


# ================================================================== Los Muelles

func _docks() -> void:
	var D := "docks"
	var metal_blue := Mats.building(Color(0.35, 0.45, 0.55), 3, Color(0.85, 0.85, 0.85), false, 21.0, Vector2(4.0, 3.4), 0.2)
	var metal_gray := Mats.building(Color(0.55, 0.56, 0.55), 3, Color(0.9, 0.6, 0.15), false, 22.0, Vector2(5.0, 4.0), 0.15, false)
	# ---------------- Manzana (0,2): Suministros Portuarios y almacenes
	var lab := shell(0, 2, Rect2(3, 3, 15, 13), 1, metal_blue, {"door_side": "n", "door_frac": 0.5, "sign": "SUMINISTROS PORTUARIOS", "sign_w": 6.0, "poi": "Suministros Portuarios|shop",
		"sign_bg": Color(0.1, 0.3, 0.5), "lock": _shop_lock("labsupply"), "floor": Mats.surface(Mats.Surf.CONCRETE, Color(0.5, 0.5, 0.5), Color(0.4, 0.4, 0.4)),
		"light_color": Color(0.9, 0.95, 1.0)})
	var li: Vector3 = lab["in0"]
	_counter(lab["node"], li + Vector3(7.2, 0, 4.0), Vector3(5.0, 1.0, 0.8), 0.0, Color(0.6, 0.6, 0.62), Color(0.2, 0.3, 0.45))
	_shelf(lab["node"], li + Vector3(4.0, 0, 10.5), 0.0, 6.0)
	_shelf(lab["node"], li + Vector3(10.5, 0, 10.5), 0.0, 5.0)
	_barrel_prop(li + Vector3(13.5, 0, 2.0), "lab0", Color(0.8, 0.6, 0.1))
	_barrel_prop(li + Vector3(13.5, 0, 3.0), "lab1", Color(0.2, 0.5, 0.8))
	_npc("lena", "Lena", "shopkeeper", D, {"skin": "#f2d0b0", "shirt": "#4a9a8a", "pants": "#25303a", "hair": "#c9a35a", "female": true}, li + Vector3(7.2, 0, 5.1), 0.0, "labsupply", Vector2i(8, 22))
	solid(0, 2, Rect2(21, 3, 16, 34), 2, metal_gray, {"door_side": "w", "door_frac": 0.5, "door_w": 4.0, "door_color": Color(0.6, 0.5, 0.2)})
	for i in 6:
		_crate_prop(L(0, 2, 5 + (i % 3) * 3.0, 24 + (i / 3) * 4.0, CURB), "dk%d" % i)
	_barrel_prop(L(0, 2, 14, 30, CURB), "dk0")
	_barrel_prop(L(0, 2, 15, 30.5, CURB), "dk1")
	_junk(L(0, 2, 10, 33, CURB), "scrap_metal")
	_meeting(0, 2, "dk_yard", "el patio de carga", "w", L(0, 2, 0, 28).z, L(0, 2, 8, 28, CURB), PI * 0.5)

	# ---------------- Manzana (1,2): nave del puerto (propiedad)
	var wh := shell(1, 2, Rect2(3, 3, 34, 22), 2, metal_blue, {"door_side": "n", "door_frac": 0.2, "property": "dock_warehouse", "lock": _property_lock("dock_warehouse"),
		"door_name": "puerta de la nave", "poi": "Nave 7 (en venta)|property", "sign": "NAVE 7", "sign_w": 2.5, "sign_bg": Color(0.6, 0.45, 0.1),
		"floor": Mats.surface(Mats.Surf.CONCRETE, Color(0.48, 0.48, 0.46), Color(0.38, 0.38, 0.37)), "wall_col": Color(0.65, 0.66, 0.68), "light_color": Color(0.95, 0.97, 1.0)})
	var wi: Vector3 = wh["in0"]
	var wslots: Array = []
	for i in 5:
		wslots.append(wi + Vector3(10.0 + i * 4.5, 0, 5.0))
	for i in 5:
		wslots.append(wi + Vector3(10.0 + i * 4.5, 0, 14.0))
	_slots(wh["node"], "dock_warehouse", wslots)
	_bed(wh["node"], wi + Vector3(2.0, 0, 18.0), 0.0, "dock_warehouse", Color(0.4, 0.4, 0.3))
	_sink(wh["node"], wi + Vector3(0.6, 0, 12.0), PI * 0.5)
	_for_sale(root, "dock_warehouse", (wh["door_pos"] as Vector3) + Vector3(2.0, CURB, -1.0), PI)
	w.property_spawns["dock_warehouse"] = {"pos": wi + Vector3(5.0, 0.2, 3.0), "yaw": PI}
	w.employee_spots["dock_warehouse"] = [wi + Vector3(5.0, 0.1, 9.0), wi + Vector3(5.0, 0.1, 11.0), wi + Vector3(5.0, 0.1, 13.0)]
	_containers(1, 2, Rect2(3, 28, 34, 9))

	# ---------------- Manzana (0,3): patio de contenedores
	_containers(0, 3, Rect2(3, 3, 34, 34))
	_location("dock_containers", L(0, 3, 20, 19.5, CURB))
	add_spur(0, 3, "n", L(0, 3, 20, 0).x, [L(0, 3, 20, 10, CURB), L(0, 3, 20, 19.5, CURB)])
	_meeting(0, 3, "dk_containers", "los contenedores", "e", L(0, 3, 0, 20).z, L(0, 3, 37.8, 20, CURB), -PI * 0.5)
	# Grúa
	var crane := Vector3(30, CURB, 210)
	var yellow := Mats.color(Color(0.95, 0.75, 0.1), 0.6, 0.4)
	for x in [-2.0, 2.0]:
		Geo.box(root, Vector3(0.5, 16, 0.5), crane + Vector3(x, 8, 0), yellow)
	Geo.box(root, Vector3(4.5, 0.6, 0.6), crane + Vector3(0, 15.5, 0), yellow, false)
	Geo.box(root, Vector3(0.6, 0.6, 22), crane + Vector3(0, 16.2, 8), yellow, false)

	# ---------------- Manzana (1,3): muelle y cobertizos
	solid(1, 3, Rect2(3, 3, 22, 16), 2, metal_gray, {"door_side": "n", "door_frac": 0.3, "door_w": 4.0})
	solid(1, 3, Rect2(28, 3, 9, 9), 1, Mats.building(Color(0.5, 0.35, 0.25), 3, Color(0.9, 0.9, 0.9), false, 23.0), {"door_side": "e", "door_frac": 0.5, "sign": "PESCADO FRESCO", "sign_w": 3.0, "sign_bg": Color(0.2, 0.4, 0.6)})
	for i in 4:
		_barrel_prop(L(1, 3, 6 + i * 1.2, 24, CURB), "pier%d" % i, Color(0.3, 0.4, 0.3))
	_meeting(1, 3, "dk_pier", "el muelle", "s", L(1, 3, 20, 0).x, L(1, 3, 20, 34, CURB), PI)
	# Malecón
	var quay_m := Mats.surface(Mats.Surf.CONCRETE, Color(0.55, 0.55, 0.53), Color(0.45, 0.45, 0.44))
	Geo.box(root, Vector3(130, CURB, 9), Vector3(40, CURB * 0.5, 209.5), quay_m, true, 0.0, false)
	for i in 14:
		Geo.cylinder(root, 0.2, 0.6, Vector3(-20 + i * 9.0, CURB + 0.3, 213.2), Mats.color(Color(0.2, 0.2, 0.22), 0.5, 0.5), true)
	Geo.box(root, Vector3(130, 1.1, 0.1), Vector3(40, CURB + 0.55, 213.8), Mats.color(Color(0.7, 0.7, 0.72, 0.6), 0.4, 0.6), false)
	Geo.collider(root, Vector3(130, 4.0, 0.6), Vector3(40, 2.0, 214.0))


func _containers(bx: int, bz: int, r: Rect2) -> void:
	var cols := [Color(0.75, 0.25, 0.2), Color(0.2, 0.45, 0.65), Color(0.25, 0.55, 0.3), Color(0.85, 0.6, 0.15), Color(0.5, 0.5, 0.52)]
	var x := r.position.x + 1.0
	var row := 0
	while x + 2.5 < r.end.x:
		var z := r.position.y + 0.5
		while z + 6.1 < r.end.y:
			# Dejamos un pasillo central libre
			if absf(x + 1.25 - 20.0) > 3.0 or bz != 3:
				var stack := rng.randi_range(1, 3)
				for s in stack:
					var c := L(bx, bz, x + 1.25, z + 3.05, CURB + 1.3 + s * 2.6)
					var m := Mats.building(cols[rng.randi() % cols.size()], 3, Color(0.3, 0.3, 0.3), false, 0.0, Vector2(1, 1), 0.0, false)
					Geo.box(root, Vector3(2.45, 2.6, 6.05), c, m)
			z += 6.6
		x += 3.4 if row % 2 == 0 else 3.0
		row += 1


# ================================================================== Uptown

func _uptown() -> void:
	var D := "uptown"
	# ---------------- Manzana (2,2): Uptown Gadgets, mansión, pistas
	var white := Mats.building(Color(0.95, 0.94, 0.9), 0, Color(0.3, 0.3, 0.32), true, 31.0, Vector2(3.5, 3.4), 0.4)
	var gad := shell(2, 2, Rect2(3, 3, 14, 12), 2, white, {"door_side": "n", "door_frac": 0.5, "glass_door": true, "door_color": Color(0.85, 0.85, 0.9),
		"sign": "UPTOWN GADGETS", "sign_w": 5.0, "poi": "Uptown Gadgets|shop", "sign_bg": Color(0.1, 0.1, 0.12), "sign_fg": Color(0.4, 0.9, 1.0), "lock": _shop_lock("gadgets"),
		"floor": Mats.surface(Mats.Surf.TILES, Color(0.95, 0.95, 0.95), Color(0.88, 0.88, 0.9)), "light_color": Color(0.95, 0.98, 1.0), "light_energy": 1.6})
	var gi: Vector3 = gad["in0"]
	_counter(gad["node"], gi + Vector3(6.8, 0, 8.5), Vector3(4.0, 1.0, 0.8), 0.0, Color(0.9, 0.9, 0.92), Color(0.15, 0.15, 0.18))
	for tp in [Vector3(3.0, 0, 3.5), Vector3(10.5, 0, 3.5)]:
		_table(gad["node"], gi + tp, Vector3(2.0, 0.9, 1.0), Color(0.95, 0.95, 0.95))
	_npc("clerk_uptown", "Chloe", "shopkeeper", D, {"skin": "#f6dcc4", "shirt": "#1a1a1a", "pants": "#1a1a1a", "hair": "#d8c070", "female": true}, gi + Vector3(6.8, 0, 9.6), 0.0, "gadgets", Vector2i(9, 21))
	house(2, 2, Rect2(20, 3, 17, 17), Color(0.92, 0.88, 0.8), Color(0.25, 0.3, 0.35), "n", 2)
	var court := L(2, 2, 20, 29.5)
	Geo.box(root, Vector3(32, 0.012, 13), court + Vector3(0, CURB + 0.006, 0), Mats.surface(Mats.Surf.CONCRETE, Color(0.25, 0.45, 0.35), Color(0.2, 0.4, 0.3)), false, 0.0, false)
	Geo.box(root, Vector3(0.08, 1.0, 11), court + Vector3(0, CURB + 0.5, 0), Mats.color(Color(0.9, 0.9, 0.9, 0.7)), false)
	_meeting(2, 2, "up_tennis", "las pistas de tenis", "s", L(2, 2, 10, 0).x, L(2, 2, 10, 30, CURB), PI)

	# ---------------- Manzana (3,2): Villa Hillside (propiedad)
	Geo.box(root, Vector3(34, 0.01, 34), L(3, 2, 20, 20, CURB + 0.005), Mats.surface(Mats.Surf.GRASS, Color(0.3, 0.52, 0.22), Color(0.38, 0.58, 0.25), 0.8), false, 0.0, false)
	var villa_mat := Mats.building(Color(0.93, 0.88, 0.78), 0, Color(0.45, 0.32, 0.22), false, 32.0, Vector2(3.2, 3.4), 0.5, true, Color(0.5, 0.25, 0.2))
	var villa := shell(3, 2, Rect2(8, 8, 24, 20), 2, villa_mat, {"door_side": "n", "door_frac": 0.5, "door_w": 1.8, "property": "uptown_villa", "lock": _property_lock("uptown_villa"),
		"door_name": "puerta de la villa", "poi": "Villa Hillside (en venta)|property", "door_color": Color(0.35, 0.22, 0.12), "floor": Mats.surface(Mats.Surf.WOOD, Color(0.7, 0.5, 0.32), Color(0.6, 0.42, 0.26)),
		"wall_col": Color(0.95, 0.92, 0.86), "trim": Color(0.45, 0.32, 0.22)})
	var vi: Vector3 = villa["in0"]
	_bed(villa["node"], vi + Vector3(20.0, 0, 16.0), PI, "uptown_villa", Color(0.6, 0.15, 0.2))
	_sofa(villa["node"], vi + Vector3(19.0, 0, 4.0), -PI * 0.5, Color(0.9, 0.88, 0.8))
	_sofa(villa["node"], vi + Vector3(15.0, 0, 2.0), PI, Color(0.9, 0.88, 0.8))
	_tv(villa["node"], vi + Vector3(15.0, 0, 7.0), 0.0)
	_rug(villa["node"], vi + Vector3(16.5, 0, 4.5), Vector2(5, 4), Color(0.5, 0.15, 0.15))
	_sink(villa["node"], vi + Vector3(0.6, 0, 17.0), PI * 0.5)
	_plant(villa["node"], vi + Vector3(0.6, 0, 0.6))
	_plant(villa["node"], vi + Vector3(23.0, 0, 0.6))
	var vslots: Array = []
	for i in 4:
		vslots.append(vi + Vector3(3.0 + i * 3.0, 0, 9.0))
	for i in 4:
		vslots.append(vi + Vector3(3.0 + i * 3.0, 0, 15.0))
	_slots(villa["node"], "uptown_villa", vslots)
	_for_sale(root, "uptown_villa", (villa["door_pos"] as Vector3) + Vector3(2.0, CURB, -3.0), PI)
	w.property_spawns["uptown_villa"] = {"pos": vi + Vector3(12.0, 0.2, 3.0), "yaw": PI}
	w.employee_spots["uptown_villa"] = [vi + Vector3(14.0, 0.1, 12.0), vi + Vector3(16.0, 0.1, 12.0)]
	# Piscina y setos
	Geo.box(root, Vector3(10, 0.3, 5), L(3, 2, 20, 33, CURB + 0.15), Mats.color(Color(0.9, 0.9, 0.88)), true)
	Geo.box(root, Vector3(9, 0.05, 4), L(3, 2, 20, 33, CURB + 0.31), Mats.water(), false)
	for x in [4.0, 36.0]:
		Geo.box(root, Vector3(1.0, 1.4, 30), L(3, 2, x, 20, CURB + 0.7), Mats.color(Color(0.18, 0.4, 0.18), 0.9), true)
	_tree(root, L(3, 2, 5, 5, CURB), 1.2, 1)
	_tree(root, L(3, 2, 35, 5, CURB), 1.2, 1)
	_tree(root, L(3, 2, 35, 36, CURB), 1.1, 0)

	# ---------------- Manzana (2,3): mansiones
	house(2, 3, Rect2(3, 3, 16, 17), Color(0.85, 0.82, 0.7), Color(0.4, 0.2, 0.18), "n", 2)
	house(2, 3, Rect2(21, 3, 16, 17), Color(0.7, 0.78, 0.82), Color(0.25, 0.25, 0.3), "n", 2)
	house(2, 3, Rect2(3, 21, 16, 16), Color(0.95, 0.9, 0.85), Color(0.3, 0.35, 0.3), "s", 2)
	house(2, 3, Rect2(21, 21, 16, 16), Color(0.82, 0.7, 0.6), Color(0.35, 0.22, 0.2), "s", 1)
	_meeting(2, 3, "up_oaks", "la calle de los robles", "e", L(2, 3, 0, 20).z, L(2, 3, 38.5, 20, CURB), -PI * 0.5)

	# ---------------- Manzana (3,3): parque del estanque
	Geo.box(root, Vector3(34, 0.01, 34), L(3, 3, 20, 20, CURB + 0.005), Mats.surface(Mats.Surf.GRASS, Color(0.3, 0.52, 0.22), Color(0.38, 0.58, 0.25), 0.8), false, 0.0, false)
	Geo.cylinder(root, 7.0, 0.05, L(3, 3, 22, 22, CURB + 0.03), Mats.water(), false, -1.0, 24)
	Geo.cylinder(root, 7.3, 0.04, L(3, 3, 22, 22, CURB + 0.01), Mats.surface(Mats.Surf.DIRT, Color(0.55, 0.5, 0.4), Color(0.45, 0.4, 0.32)), false, -1.0, 24)
	Geo.collider(root, Vector3(9.5, 1.0, 9.5), L(3, 3, 22, 22, CURB + 0.5))
	for i in 9:
		var a := TAU * i / 9.0
		_tree(root, L(3, 3, 22 + cos(a) * 12.5, 22 + sin(a) * 12.5, CURB), rng.randf_range(0.9, 1.3), i % 2)
	_bench(root, L(3, 3, 12, 22, CURB), PI * 0.5)
	_meeting(3, 3, "up_pond", "el estanque de Uptown", "w", L(3, 3, 0, 22).z, L(3, 3, 10, 22, CURB), PI * 0.5)


# ================================================================== Calles

func _street_furniture() -> void:
	var pole_m := Mats.color(Color(0.22, 0.23, 0.25), 0.5, 0.6)
	var idx := 0
	for bx in 4:
		for bz in 4:
			var x0 := bx * B + 5.0
			var z0 := bz * B + 5.0
			# Farolas en las esquinas
			for c in [[Vector3(x0 + 0.5, 0, z0 + 0.5), Vector3(-1, 0, -1)], [Vector3(x0 + 39.5, 0, z0 + 0.5), Vector3(1, 0, -1)],
					[Vector3(x0 + 39.5, 0, z0 + 39.5), Vector3(1, 0, 1)], [Vector3(x0 + 0.5, 0, z0 + 39.5), Vector3(-1, 0, 1)]]:
				_streetlight(c[0], (c[1] as Vector3).normalized(), pole_m)
			# Árboles, papeleras y bocas de riego a lo largo de las aceras
			var avoid: Array = _avoid[_key(bx, bz)]
			for side in ["n", "s", "w", "e"]:
				var t := 8.0
				while t < 34.0:
					var p := Vector3.ZERO
					match side:
						"n": p = Vector3(x0 + t, CURB, z0 + 0.8)
						"s": p = Vector3(x0 + t, CURB, z0 + 39.2)
						"w": p = Vector3(x0 + 0.8, CURB, z0 + t)
						"e": p = Vector3(x0 + 39.2, CURB, z0 + t)
					var ok := true
					for a in avoid:
						if Vector2(p.x, p.z).distance_to(Vector2((a as Vector3).x, (a as Vector3).z)) < 3.5:
							ok = false
							break
					if ok:
						var roll := rng.randf()
						if roll < 0.55:
							_tree(root, p, rng.randf_range(0.75, 1.0), 0 if district_of(bx, bz) != "uptown" else rng.randi() % 2)
						elif roll < 0.7:
							_trashcan_prop(p, "st%d" % idx)
							idx += 1
						elif roll < 0.8:
							Geo.cylinder(root, 0.12, 0.6, p + Vector3(0, 0.3, 0), Mats.color(Color(0.8, 0.15, 0.1), 0.5), true)
					t += rng.randf_range(9.0, 13.0)


func _streetlight(base: Vector3, out_dir: Vector3, pole_m: Material) -> void:
	var p := Vector3(base.x, CURB, base.z)
	Geo.cylinder(root, 0.08, 5.6, p + Vector3(0, 2.8, 0), pole_m, true, 0.06, 8)
	var arm_end := p + out_dir * 1.3 + Vector3(0, 5.5, 0)
	var arm := Geo.box(root, Vector3(0.08, 0.08, 1.4), (p + Vector3(0, 5.5, 0) + arm_end) * 0.5, pole_m, false)
	arm.rotation.y = atan2(out_dir.x, out_dir.z)
	Geo.box(root, Vector3(0.5, 0.14, 0.32), arm_end + Vector3(0, -0.05, 0), lamp_mat, false)
	var l := SpotLight3D.new()
	l.position = arm_end + Vector3(0, -0.2, 0)
	l.rotation.x = -PI * 0.5
	l.spot_range = 13.0
	l.spot_angle = 58.0
	l.spot_attenuation = 0.8
	l.light_energy = 5.0
	l.light_color = Color(1.0, 0.82, 0.55)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 20.0
	l.visible = false
	l.add_to_group("streetlights")
	root.add_child(l)


func _parked_cars() -> void:
	# Coches aparcados junto al bordillo (sin invadir cruces)
	for k in 5:
		for j in 4:
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.45:
					var along := j * B + rng.randf_range(16.0, 34.0)
					# Calles a lo largo de X (z = k*50)
					var pos := Vector3(along, 0.0, k * B + side * 3.6)
					if _car_ok(pos):
						CarModel.parked(root, pos, PI * 0.5 if side > 0 else -PI * 0.5, Color(CarModel.COLORS[rng.randi() % CarModel.COLORS.size()]))
				if rng.randf() < 0.35:
					var along2 := j * B + rng.randf_range(16.0, 34.0)
					var pos2 := Vector3(k * B + side * 3.6, 0.0, along2)
					if _car_ok(pos2):
						CarModel.parked(root, pos2, 0.0 if side > 0 else PI, Color(CarModel.COLORS[rng.randi() % CarModel.COLORS.size()]))
	# Coche patrulla en la comisaría
	CarModel.parked(root, Vector3(83, 0, 53.6), PI * 0.5, Color(0.1, 0.12, 0.2), true)


func _car_ok(pos: Vector3) -> bool:
	# No aparcar en las vías de las barreras ni fuera de la ciudad
	if pos.x < 2.0 or pos.z < 2.0 or pos.x > 198.0 or pos.z > 198.0:
		return false
	if absf(pos.x - 100.0) < 6.0 or absf(pos.z - 100.0) < 6.0:
		return false
	return true


# ================================================================== Barreras

func _barriers() -> void:
	_barrier_line("downtown", Vector3(105.5, 0, -24), Vector3(105.5, 0, 105.5))
	_barrier_line("docks", Vector3(-24, 0, 105.5), Vector3(105.5, 0, 105.5))
	_barrier_line("uptown", Vector3(105.5, 0, 105.5), Vector3(105.5, 0, 224))
	_barrier_line("uptown", Vector3(105.5, 0, 105.5), Vector3(224, 0, 105.5))


func _barrier_line(district: String, a: Vector3, b: Vector3) -> void:
	var node := Node3D.new()
	node.name = "Barrier_%s" % district
	root.add_child(node)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var len := a.distance_to(b)
	var mid := (a + b) * 0.5
	var sb := StaticBody3D.new()
	sb.collision_layer = Geo.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(len, 6.0, 0.5) if along_x else Vector3(0.5, 6.0, len)
	cs.shape = sh
	sb.add_child(cs)
	sb.position = mid + Vector3(0, 3.0, 0)
	node.add_child(sb)
	var post_m := Mats.color(Color(0.55, 0.57, 0.6), 0.4, 0.7)
	var mesh_m := Mats.color(Color(0.65, 0.68, 0.7, 0.35), 0.5, 0.5)
	var dir := (b - a).normalized()
	var t := 0.0
	while t <= len:
		var p := a + dir * t
		Geo.cylinder(node, 0.05, 2.4, p + Vector3(0, 1.2 + CURB, 0), post_m, false, -1.0, 6)
		t += 3.0
	Geo.box(node, Vector3(len, 2.2, 0.03) if along_x else Vector3(0.03, 2.2, len), mid + Vector3(0, 1.25 + CURB, 0), mesh_m, false, 0.0, false)
	# Barricadas en los cruces con calles
	var rd: Dictionary = GameState.DISTRICTS[district]
	for k in 5:
		var road := k * B
		var on_line := false
		var cp := Vector3.ZERO
		if along_x and road >= minf(a.x, b.x) and road <= maxf(a.x, b.x):
			on_line = true
			cp = Vector3(road, 0, a.z)
		elif not along_x and road >= minf(a.z, b.z) and road <= maxf(a.z, b.z):
			on_line = true
			cp = Vector3(a.x, 0, road)
		if not on_line:
			continue
		for i in 4:
			var off := -3.75 + i * 2.5
			var bp := cp + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
			var stripe := Mats.color(Color(0.9, 0.15, 0.1) if i % 2 == 0 else Color(0.95, 0.95, 0.95), 0.6)
			Geo.box(node, Vector3(2.3, 0.3, 0.15) if along_x else Vector3(0.15, 0.3, 2.3), bp + Vector3(0, 0.9, 0), stripe, false)
			Geo.box(node, Vector3(0.1, 0.9, 0.5) if along_x else Vector3(0.5, 0.9, 0.1), bp + Vector3(0, 0.45, 0), Mats.color(Color(0.2, 0.2, 0.2)), false)
		var car_off := Vector3(0, 0, 6.0) if along_x else Vector3(6.0, 0, 0)
		var car := CarModel.make(node, Color(0.1, 0.12, 0.2), true)
		car.position = cp + car_off + Vector3(2.0 if not along_x else 0.0, 0, 2.0 if along_x else 0.0)
		car.rotation.y = 0.0 if along_x else PI * 0.5
		var sign_text := "CONTROL POLICIAL\nAcceso: rango %s" % GameState.rank_name(int(rd["rank"]))
		var l1 := Geo.label(node, sign_text, cp + Vector3(0, 2.6, 0), 40, Color(1.0, 0.85, 0.3))
		l1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	w.barriers[district] = w.barriers.get(district, []) + [node]


func _outer() -> void:
	# Límites del mapa: valla perimetral y bosque
	var fence_m := Mats.color(Color(0.4, 0.42, 0.45), 0.6, 0.5)
	var lines := [
		[Vector3(-22, 0, -22), Vector3(222, 0, -22)],
		[Vector3(-22, 0, -22), Vector3(-22, 0, 214)],
		[Vector3(222, 0, -22), Vector3(222, 0, 222)],
		[Vector3(105, 0, 222), Vector3(222, 0, 222)],
		[Vector3(105, 0, 214), Vector3(105, 0, 222)],
	]
	for ln in lines:
		var a: Vector3 = ln[0]
		var b: Vector3 = ln[1]
		var len := a.distance_to(b)
		var along_x := absf(b.x - a.x) > absf(b.z - a.z)
		var mid := (a + b) * 0.5
		Geo.collider(root, Vector3(len, 8.0, 0.5) if along_x else Vector3(0.5, 8.0, len), mid + Vector3(0, 4.0, 0))
		Geo.box(root, Vector3(len, 1.8, 0.08) if along_x else Vector3(0.08, 1.8, len), mid + Vector3(0, 0.9, 0), fence_m, false, 0.0, false)
	for i in 70:
		var p := Vector3.ZERO
		var side := i % 4
		var t := rng.randf_range(-40.0, 240.0)
		match side:
			0: p = Vector3(t, 0, rng.randf_range(-45.0, -10.0))
			1: p = Vector3(rng.randf_range(-45.0, -10.0), 0, clampf(t, -40.0, 205.0))
			2: p = Vector3(rng.randf_range(210.0, 245.0), 0, t)
			3: p = Vector3(rng.randf_range(110.0, 240.0), 0, rng.randf_range(210.0, 245.0))
		_tree(root, p, rng.randf_range(1.0, 1.6), rng.randi() % 2)
	# Colinas al fondo
	for i in 8:
		var hm := Geo.sphere(root, rng.randf_range(25.0, 45.0), Vector3(rng.randf_range(-80, 280), -12.0, rng.randf_range(-110, -70) if i % 2 == 0 else rng.randf_range(270, 320)), Mats.color(Color(0.3, 0.45, 0.25), 0.95), 16)
		hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================== Tráfico

func _traffic() -> void:
	var loops := {
		"northtown": [[Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)], [Vector2(50, 0), Vector2(50, 100), Vector2(100, 100), Vector2(100, 0)]],
		"downtown": [[Vector2(150, 0), Vector2(200, 0), Vector2(200, 50), Vector2(150, 50)]],
		"docks": [[Vector2(0, 150), Vector2(50, 150), Vector2(50, 200), Vector2(0, 200)]],
		"uptown": [[Vector2(150, 150), Vector2(200, 150), Vector2(200, 200), Vector2(150, 200)]],
	}
	var count := 0
	for d in loops:
		for loop in loops[d]:
			var pts := _offset_loop(loop, 2.5)
			w.traffic_routes["%s_%d" % [d, count]] = pts
			var cars := 2 if d == "northtown" else 1
			for i in cars:
				var car := TrafficCar.new()
				car.name = "Traffic_%d" % count
				w.add_child(car)
				car.setup(pts, (i * 2) % pts.size(), Color(CarModel.COLORS[rng.randi() % CarModel.COLORS.size()]), d)
				count += 1


func _offset_loop(loop: Array, offset: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := loop.size()
	for i in n:
		var prev: Vector2 = loop[(i - 1 + n) % n]
		var cur: Vector2 = loop[i]
		var nxt: Vector2 = loop[(i + 1) % n]
		var d_in := (cur - prev).normalized()
		var d_out := (nxt - cur).normalized()
		# Derecha de la dirección de marcha (x, z): (-dz, dx) con Y arriba
		var r_in := Vector2(-d_in.y, d_in.x)
		var r_out := Vector2(-d_out.y, d_out.x)
		var p := cur + (r_in + r_out) * offset
		out.append(Vector3(p.x, 0.0, p.y))
	return out
