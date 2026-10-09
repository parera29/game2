class_name World
extends Node3D
## Mundo de juego: construye la ciudad (CityBuilder), gestiona NPC, puntos de
## encuentro, barreras de distritos, objetos sueltos y la API que usan los sistemas.

const NPC_SCRIPT := preload("res://scripts/npc/npc.gd")

var nav := WaypointGraph.new()
var doors: Array = []
var items_root: Node3D
var npc_root: Node3D
var props_root: Node3D
var meeting_points: Dictionary = {}     # id -> {name, district, pos, yaw}
var locations: Dictionary = {}          # id -> Vector3 (puntos de misión)
var barriers: Dictionary = {}           # distrito -> [Node3D]
var property_spawns: Dictionary = {}    # pid -> {pos, yaw}
var employee_spots: Dictionary = {}     # pid -> [Vector3]
var static_npc_specs: Array = []        # NPC fijos definidos por el builder
var police_station_pos := Vector3.ZERO
var player_spawn := Vector3.ZERO
var player_spawn_yaw := 0.0
var traffic_routes: Dictionary = {}     # distrito -> [Vector3]
var customers_npcs: Dictionary = {}
var employee_npcs: Dictionary = {}
var _reinforcements: Array = []
var builder: RefCounted = null
var map_rects: Array = []               # [{"rect": Rect2, "color": Color}] para el mapa
var pois: Array = []                    # [{"name", "pos", "kind"}]
var lamp_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _los_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_rng.randomize()
	items_root = Node3D.new()
	items_root.name = "Items"
	add_child(items_root)
	npc_root = Node3D.new()
	npc_root.name = "NPCs"
	add_child(npc_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	_los_query.collision_mask = Geo.LAYER_WORLD
	var builder := CityBuilder.new(self)
	builder.build()
	_refresh_barriers()
	Events.district_unlocked.connect(func(_d): _refresh_barriers())
	Events.deal_scheduled.connect(_on_deal_scheduled)
	Events.deal_cancelled.connect(_refresh_customer_marker)
	Events.deal_completed.connect(func(id, _u, _t): _refresh_customer_marker(id))
	Events.customer_unlocked.connect(_refresh_customer_marker)
	Events.quest_started.connect(func(_q): _refresh_static_markers())
	Events.quest_updated.connect(func(_q): _refresh_static_markers())
	Events.quest_completed.connect(func(_q): _refresh_static_markers())
	Events.employees_changed.connect(_refresh_employees)
	GameState.world = self


func _refresh_customer_marker(id: String) -> void:
	if customers_npcs.has(id) and is_instance_valid(customers_npcs[id]):
		customers_npcs[id].refresh_marker()


func _exit_tree() -> void:
	if GameState.world == self:
		GameState.world = null


func _zone_enter(body: Node, zone: Area3D) -> void:
	if body.has_method("enter_zone"):
		body.enter_zone(zone)


func _zone_exit(body: Node, zone: Area3D) -> void:
	if body.has_method("exit_zone"):
		body.exit_zone(zone)


func _location_enter(body: Node, id: String) -> void:
	if body.is_in_group("player"):
		Events.location_reached.emit(id)


# ------------------------------------------------------------------ NPC

func spawn_npc(id: String, p_name: String, role: String, district: String, look: Dictionary, pos: Vector3, yaw: float = 0.0) -> NPC:
	var n: NPC = NPC_SCRIPT.new()
	n.setup(id, p_name, role, district, look)
	n.position = pos
	n.rotation.y = yaw
	n.floor_max_angle = deg_to_rad(60)
	npc_root.add_child(n)
	return n


func populate() -> void:
	# NPC fijos (tenderos, personajes de misión)
	for spec in static_npc_specs:
		var n := spawn_npc(spec["id"], spec["name"], spec["role"], spec["district"], spec["look"], spec["pos"], spec["yaw"])
		n.shop_id = String(spec.get("shop", ""))
		n.active_hours = spec.get("hours", Vector2i(0, 24))
	# Clientes
	for cid in Customers.defs:
		var d: Dictionary = Customers.defs[cid]
		var pos: Vector3 = nav.random_point(String(d["district"]), _rng)
		var n2 := spawn_npc(cid, String(d["name"]), "customer", String(d["district"]), d["look"], pos + Vector3.UP * 0.2)
		n2.active_hours = Vector2i(7, 23)
		customers_npcs[cid] = n2
	# Peatones
	var counts := {"northtown": 10, "downtown": 10, "docks": 6, "uptown": 7}
	for dist in counts:
		for i in int(counts[dist]):
			var pos2: Vector3 = nav.random_point(dist, _rng)
			var n3 := spawn_npc("ped_%s_%d" % [dist, i], _random_name(), "pedestrian", dist, _random_look(dist), pos2 + Vector3.UP * 0.2)
			n3.active_hours = Vector2i(_rng.randi_range(5, 8), _rng.randi_range(20, 24))
	# Policía de patrulla
	var cops := {"northtown": 2, "downtown": 2, "docks": 1, "uptown": 2}
	for dist in cops:
		for i in int(cops[dist]):
			var pos3: Vector3 = nav.random_point(dist, _rng)
			var c := spawn_npc("cop_%s_%d" % [dist, i], "Agente", "police", dist, _police_look(), pos3 + Vector3.UP * 0.2)
			c.active_hours = Vector2i(0, 24)
	_refresh_employees()
	_refresh_static_markers()


func _refresh_static_markers() -> void:
	for n in npc_root.get_children():
		if n is NPC and (n.role == "quest" or n.role == "shopkeeper"):
			n.refresh_marker()


func _random_name() -> String:
	var names := ["Vecino", "Vecina", "Transeúnte", "Paseante", "Oficinista", "Estudiante", "Jubilado", "Turista"]
	return names[_rng.randi() % names.size()]


func _random_look(district: String) -> Dictionary:
	var skins := ["#f1c9a5", "#e0b48c", "#c68a62", "#8d5a3b", "#f6dcc4", "#a46f4c", "#d6a27e"]
	var shirts := ["#3f6fb5", "#c0504d", "#4f9a5a", "#e2a03f", "#8e5ab5", "#7a7a7a", "#2fa38a", "#d9d9d9", "#26324a", "#b5563f"]
	var pants := ["#2b2f3a", "#3b3b55", "#4d5560", "#22252b", "#3a2c22", "#5a5a6a", "#1e2228"]
	var hairs := ["#1a1210", "#4a3020", "#c98b3a", "#2a1a10", "#e8d27a", "#555555", "#7a3b1f"]
	if district == "uptown":
		shirts = ["#f0e6d2", "#26324a", "#f2f2f2", "#4b3a6b", "#2f4f6f", "#9a1f2f"]
	elif district == "docks":
		shirts = ["#d97b29", "#5a5a2a", "#304050", "#7a7a7a", "#c9a23a"]
	return {
		"skin": skins[_rng.randi() % skins.size()], "shirt": shirts[_rng.randi() % shirts.size()],
		"pants": pants[_rng.randi() % pants.size()], "hair": hairs[_rng.randi() % hairs.size()],
		"female": _rng.randf() < 0.5,
	}


func _police_look() -> Dictionary:
	return {"skin": ["#f1c9a5", "#c68a62", "#8d5a3b", "#e0b48c"][_rng.randi() % 4], "shirt": "#24365e", "pants": "#1a2238", "hair": "#2a1a10", "female": _rng.randf() < 0.3}


func _on_deal_scheduled(id: String) -> void:
	if customers_npcs.has(id):
		customers_npcs[id].on_deal_scheduled()


func get_police() -> Array:
	return get_tree().get_nodes_in_group("police")


func get_civilians() -> Array:
	var out: Array = []
	for n in npc_root.get_children():
		if n is NPC and n.role in ["pedestrian", "customer", "shopkeeper", "quest"] and n.visible:
			out.append(n)
	return out


func has_line_of_sight(a: Vector3, b: Vector3) -> bool:
	_los_query.from = a
	_los_query.to = b
	var hit := get_world_3d().direct_space_state.intersect_ray(_los_query)
	return hit.is_empty()


func spawn_reinforcements(near: Vector3) -> void:
	var count := 2 if near != Vector3.ZERO else 3
	for i in count:
		var pos: Vector3
		if near != Vector3.ZERO:
			var far_pts: Array = []
			for d in GameState.unlocked_districts:
				for pid in nav.district_points.get(d, []):
					var p := nav.point_pos(pid)
					var dd := p.distance_to(near)
					if dd > 25.0 and dd < 60.0:
						far_pts.append(p)
			pos = far_pts[_rng.randi() % far_pts.size()] if far_pts.size() > 0 else nav.random_point("northtown", _rng)
		else:
			var dist: String = GameState.unlocked_districts[_rng.randi() % GameState.unlocked_districts.size()]
			pos = nav.random_point(dist, _rng)
		var c := spawn_npc("cop_extra_%d" % _rng.randi(), "Agente", "police", GameState.district_at(pos), _police_look(), pos + Vector3.UP * 0.2)
		_reinforcements.append(c)
		if Police.wanted >= Police.Wanted.PURSUIT:
			c.chase_player()
	# Los refuerzos se retiran tras un tiempo
	get_tree().create_timer(240.0, false).timeout.connect(_cleanup_reinforcements)


func _cleanup_reinforcements() -> void:
	if Police.wanted >= Police.Wanted.PURSUIT:
		get_tree().create_timer(60.0, false).timeout.connect(_cleanup_reinforcements)
		return
	for c in _reinforcements:
		if is_instance_valid(c):
			c.queue_free()
	_reinforcements.clear()


func dispatch_police(pos: Vector3) -> void:
	var best: NPC = null
	var best_d := INF
	for c in get_police():
		var d: float = (c as Node3D).global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = c
	if best:
		best.dispatch_to(pos)


func police_stand_down() -> void:
	for c in get_police():
		c.resume_patrol()


func spawn_mugger() -> void:
	var p := GameState.player as Node3D
	if p == null:
		return
	var district := GameState.district_at(p.global_position)
	var pts: Array = []
	for pid in nav.district_points.get(district, []):
		var pp := nav.point_pos(pid)
		var dd := pp.distance_to(p.global_position)
		if dd > 15.0 and dd < 35.0:
			pts.append(pp)
	if pts.is_empty():
		return
	var pos: Vector3 = pts[_rng.randi() % pts.size()]
	var m := spawn_npc("mugger_%d" % _rng.randi(), "Atracador", "mugger", district, {"skin": "#c68a62", "shirt": "#1a1a1a", "pants": "#1a1a1a", "hair": "#111111"}, pos + Vector3.UP * 0.2)
	m.model.say("¡Eh, tú! ¡La cartera!", 3.0)
	Events.toast("¡Un atracador va a por ti! Huye o empújalo (clic izq.) dos veces.", "warn")


func _refresh_employees() -> void:
	var hired: Dictionary = {}
	for e in Business.employees:
		hired[e["id"]] = e
	for id in employee_npcs.keys():
		if not hired.has(id) or employee_npcs[id].district != String(hired[id]["property"]):
			if is_instance_valid(employee_npcs[id]):
				employee_npcs[id].queue_free()
			employee_npcs.erase(id)
	for id in hired:
		if employee_npcs.has(id):
			continue
		var e: Dictionary = hired[id]
		var pid := String(e["property"])
		var spots: Array = employee_spots.get(pid, [])
		if spots.is_empty():
			continue
		var idx := employee_npcs.size() % spots.size()
		var n := spawn_npc(id, String(e["name"]), "employee", pid, e["look"], spots[idx])
		employee_npcs[id] = n


# ------------------------------------------------------------------ Puntos de encuentro

func add_meeting_point(id: String, p_name: String, district: String, pos: Vector3, yaw: float) -> void:
	meeting_points[id] = {"id": id, "name": p_name, "district": district, "pos": pos, "yaw": yaw}


func get_meeting_point(district: String, _customer_id: String) -> Dictionary:
	var opts: Array = []
	for id in meeting_points:
		if meeting_points[id]["district"] == district:
			opts.append(meeting_points[id])
	if opts.is_empty():
		return {"id": "", "name": "su barrio"}
	var mp: Dictionary = opts[_rng.randi() % opts.size()]
	return {"id": mp["id"], "name": mp["name"]}


func get_meeting_point_data(id: String) -> Dictionary:
	return meeting_points.get(id, {})


# ------------------------------------------------------------------ Barreras de distritos

func _refresh_barriers() -> void:
	for d in barriers:
		var open := GameState.is_district_accessible(d)
		for n in barriers[d]:
			if not is_instance_valid(n):
				continue
			n.visible = not open
			if n is CollisionObject3D:
				(n as CollisionObject3D).collision_layer = 0 if open else Geo.LAYER_WORLD
			for c in n.find_children("*", "CollisionObject3D", true, false):
				(c as CollisionObject3D).collision_layer = 0 if open else Geo.LAYER_WORLD
	# Si el jugador está dentro de un distrito cerrado, se le saca
	var p := GameState.player as Node3D
	if p:
		var d2 := GameState.district_at(p.global_position)
		if not GameState.is_district_accessible(d2):
			respawn_player()


# ------------------------------------------------------------------ Objetos

func spawn_item_near_player(id: String, qty: int, data: Dictionary) -> void:
	var p := GameState.player as Node3D
	var pos := (p.global_position + Vector3.UP * 1.0 - p.global_basis.z * 0.8) if p else player_spawn
	WorldItem.spawn(items_root, id, qty, data, pos)
	Events.toast("Inventario lleno: %s está en el suelo." % ItemDB.display_name(id, data), "warn")


func spawn_quest_item(item: String, location: String) -> void:
	for w in get_tree().get_nodes_in_group("world_items"):
		if (w as WorldItem).item_id == item:
			return
	if not locations.has(location):
		push_warning("Ubicación de misión desconocida: %s" % location)
		return
	var wi := WorldItem.spawn(items_root, item, 1, {}, locations[location] + Vector3.UP * 0.5)
	wi.quest_item = true


# ------------------------------------------------------------------ Jugador

func respawn_player() -> void:
	var p := GameState.player
	if p == null:
		return
	var pid := ""
	for prop in Business.accessible_properties():
		pid = prop
		break
	if pid != "" and property_spawns.has(pid):
		p.teleport(property_spawns[pid]["pos"], property_spawns[pid]["yaw"])
	else:
		p.teleport(police_station_pos, 0.0)


func on_player_arrested() -> void:
	var p := GameState.player
	if p:
		p.teleport(police_station_pos, PI)
	for c in get_police():
		c.resume_patrol()


func on_player_passed_out() -> void:
	respawn_player()


# ------------------------------------------------------------------ Guardado

func to_save_dict() -> Dictionary:
	var p := GameState.player as Node3D
	var items: Array = []
	for w in get_tree().get_nodes_in_group("world_items"):
		var wi := w as WorldItem
		if wi.quest_item or wi.is_queued_for_deletion():
			continue
		items.append(wi.to_save())
	var props: Array = []
	for pr in get_tree().get_nodes_in_group("props"):
		var n := pr as Node3D
		props.append({"name": String(n.name), "pos": [n.global_position.x, n.global_position.y, n.global_position.z], "rot": [n.rotation.x, n.rotation.y, n.rotation.z]})
	return {
		"player_pos": [p.global_position.x, p.global_position.y, p.global_position.z] if p else [player_spawn.x, player_spawn.y, player_spawn.z],
		"player_yaw": p.rotation.y if p else 0.0,
		"hotbar": p.get("hotbar_index") if p else 0,
		"items": items,
		"props": props,
	}


func apply_save(d: Dictionary) -> void:
	var p := GameState.player
	var pp: Array = d.get("player_pos", [])
	if p and pp.size() == 3:
		p.teleport(Vector3(float(pp[0]), float(pp[1]) + 0.1, float(pp[2])), float(d.get("player_yaw", 0.0)))
		p.select_slot(int(d.get("hotbar", 0)))
	for it in d.get("items", []):
		var pos: Array = it.get("pos", [0, 0, 0])
		if ItemDB.exists(String(it.get("id", ""))):
			WorldItem.spawn(items_root, String(it["id"]), int(it.get("qty", 1)), it.get("data", {}), Vector3(float(pos[0]), float(pos[1]) + 0.05, float(pos[2])))
	var by_name: Dictionary = {}
	for pr in get_tree().get_nodes_in_group("props"):
		by_name[String(pr.name)] = pr
	for pd in d.get("props", []):
		var n: Node3D = by_name.get(String(pd.get("name", "")), null)
		var pos2: Array = pd.get("pos", [])
		var rot: Array = pd.get("rot", [0, 0, 0])
		if n and pos2.size() == 3:
			n.global_position = Vector3(float(pos2[0]), float(pos2[1]), float(pos2[2]))
			n.rotation = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
	_refresh_barriers()
