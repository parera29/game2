extends Node
## Negocio: propiedades, estaciones de producción (cultivo, mezcla, empaquetado,
## almacenamiento, laboratorio), empleados, gastos diarios y redadas.
## El estado es puramente de datos; los nodos 3D de las estaciones lo leen y modifican.

const PROPS_PATH := "res://data/properties.json"
const GROW_MINUTES := 720.0          # 12 h de juego
const WATER_MINUTES := 300.0         # un riego dura 5 h
const MIX_MINUTES_PER_UNIT := 2
const MIX_MAX := 10
const LAB_MINUTES := 360
const LAB_YIELD := 10
const MAX_EFFECTS := 3

const STATION_NAMES := {
	"grow": "Maceta de cultivo", "mixing": "Estación de mezcla", "packaging": "Estación de empaquetado",
	"storage": "Estantería", "lab": "Laboratorio Azure",
}

const EMPLOYEE_CANDIDATES := [
	{"id": "nina", "name": "Nina", "role": "botanist", "wage": 80, "rank": 0, "look": {"skin": "#e8b896", "shirt": "#4f9a5a", "pants": "#3b3b3b", "hair": "#7a3b1f", "female": true}},
	{"id": "leo", "name": "Leo", "role": "packager", "wage": 70, "rank": 0, "look": {"skin": "#a46f4c", "shirt": "#c9a23a", "pants": "#2b2b35", "hair": "#111111", "female": false}},
	{"id": "pablo", "name": "Dr. Pablo", "role": "chemist", "wage": 150, "rank": 2, "look": {"skin": "#f0caa8", "shirt": "#f2f2f2", "pants": "#30363f", "hair": "#9a9a9a", "female": false}},
	{"id": "marta", "name": "Marta", "role": "botanist", "wage": 90, "rank": 1, "look": {"skin": "#d79c75", "shirt": "#5a7fc0", "pants": "#3b3226", "hair": "#2a160c", "female": true}},
	{"id": "ivan", "name": "Iván", "role": "packager", "wage": 75, "rank": 1, "look": {"skin": "#f1d0b5", "shirt": "#8b3b3b", "pants": "#26303a", "hair": "#c9a35a", "female": false}},
]

const ROLE_NAMES := {"botanist": "Botánico", "packager": "Empaquetador", "chemist": "Químico"}
const ROLE_DESC := {
	"botanist": "Riega, cosecha y replanta las macetas con tierra y esporas de la estantería.",
	"packager": "Empaqueta hasta 20 unidades por hora usando bolsitas/tarros de la estantería.",
	"chemist": "Mantiene el laboratorio Azure en marcha con sales y reactivo de la estantería.",
}

var prop_defs: Dictionary = {}
var properties: Dictionary = {}
var employees: Array = []
var storages: Dictionary = {}        # "pid:slot" -> Inventory
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open(PROPS_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			prop_defs = parsed
	if prop_defs.is_empty():
		push_error("BusinessManager: no se pudieron cargar las propiedades")
	Events.minute_passed.connect(_on_minute)
	Events.hour_passed.connect(_on_hour)
	reset()


func reset() -> void:
	properties.clear()
	storages.clear()
	employees.clear()
	for pid in prop_defs:
		var start := bool(prop_defs[pid].get("start", false))
		properties[pid] = {"owned": false, "rented": start, "stations": {}}


# ------------------------------------------------------------------ Propiedades

func has_access(pid: String) -> bool:
	if not properties.has(pid):
		return false
	return bool(properties[pid]["owned"]) or bool(properties[pid]["rented"])


func owns(pid: String) -> bool:
	return properties.has(pid) and bool(properties[pid]["owned"])


func owned_property_count(include_rented: bool = true) -> int:
	var n := 0
	for pid in properties:
		if properties[pid]["owned"] or (include_rented and properties[pid]["rented"]):
			n += 1
	return n


func accessible_properties() -> Array:
	var out: Array = []
	for pid in properties:
		if has_access(pid):
			out.append(pid)
	return out


func property_name(pid: String) -> String:
	return String(prop_defs.get(pid, {}).get("name", pid))


func buy_property(pid: String) -> bool:
	if not prop_defs.has(pid) or owns(pid):
		return false
	var d: Dictionary = prop_defs[pid]
	if not GameState.is_district_unlocked(String(d["district"])):
		Events.toast("Ese distrito aún no está disponible.", "warn")
		return false
	var price := int(d["price"])
	if GameState.cash + GameState.bank < price:
		Audio.play("error")
		Events.toast("Necesitas $%d (efectivo + banco)." % price, "warn")
		return false
	GameState.charge(price)
	properties[pid]["owned"] = true
	properties[pid]["rented"] = false
	Audio.play("cash")
	Events.toast("¡Has comprado %s!" % d["name"], "quest")
	GameState.add_xp(40)
	Events.property_acquired.emit(pid)
	Events.property_state_changed.emit(pid)
	return true


func slot_count(pid: String) -> int:
	return int(prop_defs.get(pid, {}).get("slots", 0))


# ------------------------------------------------------------------ Estaciones

func get_station(pid: String, slot: int) -> Dictionary:
	if not properties.has(pid):
		return {}
	return properties[pid]["stations"].get(str(slot), {})


func count_stations(type: String) -> int:
	var n := 0
	for pid in properties:
		for k in properties[pid]["stations"]:
			if properties[pid]["stations"][k].get("type", "") == type:
				n += 1
	return n


func install_station(pid: String, slot: int, kit_id: String) -> bool:
	if not has_access(pid) or not get_station(pid, slot).is_empty():
		return false
	var type := String(ItemDB.get_prop(kit_id, "station", ""))
	if type == "":
		return false
	if not GameState.player_inventory.remove(kit_id, 1):
		return false
	var st := {"type": type}
	match type:
		"grow":
			st.merge({"soil": false, "soil_quality": 0.0, "planted": false, "growth": 0.0, "water": 0.0, "light": false, "dry_minutes": 0})
		"mixing", "lab":
			st.merge({"busy": false, "remaining": 0, "output": {}})
		"storage":
			_get_storage_inv(pid, slot)
	properties[pid]["stations"][str(slot)] = st
	Audio.play("package")
	Events.toast("%s instalada." % STATION_NAMES.get(type, type), "info")
	Events.station_installed.emit(type, pid)
	Events.property_state_changed.emit(pid)
	return true


func can_uninstall(pid: String, slot: int) -> bool:
	var st := get_station(pid, slot)
	if st.is_empty():
		return false
	match String(st["type"]):
		"grow":
			return not st["soil"] and not st["planted"]
		"mixing", "lab":
			return not st["busy"] and (st["output"] as Dictionary).is_empty()
		"storage":
			var inv := _get_storage_inv(pid, slot)
			for s in inv.slots:
				if s != null:
					return false
	return true


func uninstall_station(pid: String, slot: int) -> bool:
	if not can_uninstall(pid, slot):
		Events.toast("Vacía la estación antes de desmontarla.", "warn")
		return false
	var st := get_station(pid, slot)
	var kit := ""
	for id in ItemDB.all_ids():
		if String(ItemDB.get_prop(id, "station", "")) == String(st["type"]):
			kit = id
	if GameState.player_inventory.can_add(kit, 1) < 1:
		Events.toast("No tienes espacio para el kit.", "warn")
		return false
	if st.get("light", false):
		GameState.player_inventory.add("kit_grow_light", 1)
	GameState.player_inventory.add(kit, 1)
	properties[pid]["stations"].erase(str(slot))
	storages.erase("%s:%d" % [pid, slot])
	Events.property_state_changed.emit(pid)
	return true


func _get_storage_inv(pid: String, slot: int) -> Inventory:
	var key := "%s:%d" % [pid, slot]
	if not storages.has(key):
		storages[key] = Inventory.new(20, -1.0, "Estantería")
	return storages[key]


func storage_inventory(pid: String, slot: int) -> Inventory:
	return _get_storage_inv(pid, slot)


func property_storages(pid: String) -> Array:
	var out: Array = []
	if not properties.has(pid):
		return out
	for k in properties[pid]["stations"]:
		if properties[pid]["stations"][k].get("type", "") == "storage":
			out.append(_get_storage_inv(pid, int(k)))
	return out


# ---- Cultivo

func grow_action(pid: String, slot: int, held_id: String, held_slot: int) -> String:
	var st := get_station(pid, slot)
	if st.is_empty() or st["type"] != "grow":
		return ""
	var inv: Inventory = GameState.player_inventory
	if st["planted"] and float(st["growth"]) >= 1.0:
		return harvest(pid, slot, inv)
	if held_id == "kit_grow_light":
		if st["light"]:
			return "Esta maceta ya tiene lámpara."
		inv.remove("kit_grow_light", 1)
		st["light"] = true
		Events.property_state_changed.emit(pid)
		return "Lámpara de cultivo instalada."
	if not st["soil"]:
		for soil_id in ["premium_soil", "soil"]:
			if held_id == soil_id or (held_id == "" and inv.has(soil_id)):
				inv.remove(soil_id, 1)
				st["soil"] = true
				st["soil_quality"] = float(ItemDB.get_prop(soil_id, "soil_quality", 0.45))
				Audio.play("drop")
				Events.property_state_changed.emit(pid)
				return "Has echado %s." % ItemDB.display_name(soil_id).to_lower()
		return "Necesitas un saco de tierra."
	if not st["planted"]:
		if inv.has("glimmer_spores"):
			inv.remove("glimmer_spores", 1)
			st["planted"] = true
			st["growth"] = 0.0
			st["dry_minutes"] = 0
			Events.property_state_changed.emit(pid)
			return "Has plantado esporas de Glimmer. ¡Riégala!"
		return "Necesitas esporas de Glimmer."
	if held_id == "watering_can":
		var can = inv.get_slot(held_slot)
		var water := int(can["data"].get("water", 0))
		if water <= 0:
			return "La regadera está vacía. Rellénala en un fregadero."
		if float(st["water"]) > 0.9:
			return "La planta ya está bien regada."
		can["data"]["water"] = water - 1
		inv.changed.emit()
		st["water"] = 1.0
		Audio.play("water")
		Events.property_state_changed.emit(pid)
		return "Planta regada."
	return "Crecimiento: %d%%  Agua: %d%%  (equipa la regadera para regar)" % [int(float(st["growth"]) * 100.0), int(float(st["water"]) * 100.0)]


func harvest(pid: String, slot: int, target: Inventory) -> String:
	var st := get_station(pid, slot)
	if st.is_empty() or not st["planted"] or float(st["growth"]) < 1.0:
		return ""
	var quality := clampf(float(st["soil_quality"]) + (0.08 if st["light"] else 0.0) - float(st["dry_minutes"]) * 0.0006 + _rng.randf_range(-0.04, 0.04), 0.05, 1.0)
	var yield_n := 6 + (2 if float(st["soil_quality"]) > 0.6 else 0) + (1 if st["light"] else 0)
	var data := {"quality": quality, "effects": []}
	var fit := target.can_add("glimmer_bud", yield_n, data)
	if fit < yield_n:
		return "No tienes espacio para cosechar (%d cogollos)." % yield_n
	target.add("glimmer_bud", yield_n, data)
	st["planted"] = false
	st["soil"] = false
	st["growth"] = 0.0
	st["water"] = 0.0
	st["dry_minutes"] = 0
	GameState.stat_add("harvests", 1)
	GameState.add_xp(10)
	Audio.play("pickup")
	Events.harvested.emit("glimmer_bud", yield_n)
	Events.property_state_changed.emit(pid)
	return "Cosechados %d cogollos (calidad %d%%)." % [yield_n, int(quality * 100.0)]


# ---- Empaquetado

## Empaqueta una pila de producto sin empaquetar del inventario dado.
func package_stack(inv: Inventory, slot_i: int, packaging: String, max_units: int = 9999) -> int:
	var s = inv.get_slot(slot_i)
	if s == null or not ItemDB.is_product(s["id"]) or ItemDB.is_packed_product(s["id"]):
		return 0
	var product := ItemDB.product_type(s["id"])
	var per := int(ItemDB.get_prop(packaging, "units", 1))
	var out_id := ItemDB.packed_id(product, packaging)
	var data: Dictionary = s["data"].duplicate(true)
	var packs := mini(int(s["qty"]) / per, inv.count(packaging))
	packs = mini(packs, max_units / per)
	if packs <= 0:
		return 0
	# Comprobar espacio tras retirar el material
	var made := 0
	for i in packs:
		if inv.can_add(out_id, 1, data) < 1 and int(inv.get_slot(slot_i)["qty"]) > per:
			break
		inv.take_from_slot(slot_i, per)
		inv.remove(packaging, 1)
		inv.add(out_id, 1, data)
		made += 1
		if inv.get_slot(slot_i) == null:
			break
	if made > 0:
		GameState.stat_add("packaged", made * per)
		Events.packaged.emit(out_id, made * per)
	return made


# ---- Mezcla

func start_mix(pid: String, slot: int, product_slot: int, additive_id: String) -> String:
	var st := get_station(pid, slot)
	if st.is_empty() or st["busy"] or not (st["output"] as Dictionary).is_empty():
		return "La estación está ocupada."
	var inv: Inventory = GameState.player_inventory
	var s = inv.get_slot(product_slot)
	if s == null or not ItemDB.is_product(s["id"]) or ItemDB.is_packed_product(s["id"]):
		return "Elige producto sin empaquetar."
	var effect := String(ItemDB.get_prop(additive_id, "effect", ""))
	if effect == "":
		return "Elige un aditivo."
	var n := mini(mini(int(s["qty"]), inv.count(additive_id)), MIX_MAX)
	if n <= 0:
		return "Te faltan aditivos."
	var data: Dictionary = s["data"].duplicate(true)
	var effects: Array = data.get("effects", []).duplicate()
	if effects.has(effect):
		return "Ese producto ya tiene ese efecto."
	if effects.size() >= MAX_EFFECTS:
		effects.pop_front()
	effects.append(effect)
	data["effects"] = effects
	data["quality"] = clampf(float(data.get("quality", 0.5)) + 0.02, 0.0, 1.0)
	var id := String(s["id"])
	inv.take_from_slot(product_slot, n)
	inv.remove(additive_id, n)
	st["busy"] = true
	st["remaining"] = n * MIX_MINUTES_PER_UNIT
	st["output"] = {"id": id, "qty": n, "data": data}
	Audio.play("package")
	Events.property_state_changed.emit(pid)
	return "Mezclando %d unidades (%d min)." % [n, n * MIX_MINUTES_PER_UNIT]


func collect_output(pid: String, slot: int, target: Inventory) -> String:
	var st := get_station(pid, slot)
	if st.is_empty() or st["busy"] or (st["output"] as Dictionary).is_empty():
		return ""
	var o: Dictionary = st["output"]
	var left := target.add(String(o["id"]), int(o["qty"]), o["data"])
	var got := int(o["qty"]) - left
	if got > 0 and st["type"] == "mixing":
		Events.mixed.emit(String(o["id"]), got)
		GameState.stat_add("mixed", got)
	if got > 0 and st["type"] == "lab":
		Events.produced.emit(String(o["id"]), got)
	if left > 0:
		o["qty"] = left
		Events.property_state_changed.emit(pid)
		return "Recogidas %d unidades. No cabe más." % got
	st["output"] = {}
	Audio.play("pickup")
	Events.property_state_changed.emit(pid)
	return "Recogidas %d unidades de %s." % [got, ItemDB.display_name(String(o["id"]), o["data"])]


# ---- Laboratorio

func start_lab(pid: String, slot: int, inv: Inventory) -> String:
	var st := get_station(pid, slot)
	if st.is_empty() or st["busy"] or not (st["output"] as Dictionary).is_empty():
		return "El laboratorio está ocupado."
	if not inv.has("azure_salts") or not inv.has("azure_reagent"):
		return "Necesitas 1 sal mineral y 1 reactivo azul."
	inv.remove("azure_salts", 1)
	inv.remove("azure_reagent", 1)
	st["busy"] = true
	st["remaining"] = LAB_MINUTES
	st["output"] = {"id": "azure_shard", "qty": LAB_YIELD, "data": {"quality": clampf(0.55 + _rng.randf_range(-0.05, 0.15), 0.0, 1.0), "effects": []}}
	Audio.play("package")
	Events.property_state_changed.emit(pid)
	GameState.flags["azure_known"] = true
	return "Proceso iniciado: 6 horas."


# ------------------------------------------------------------------ Simulación

func _on_minute(_m: int, _d: int) -> void:
	for pid in properties:
		var changed := false
		for k in properties[pid]["stations"]:
			var st: Dictionary = properties[pid]["stations"][k]
			match String(st["type"]):
				"grow":
					if st["planted"] and float(st["growth"]) < 1.0:
						if float(st["water"]) > 0.0:
							var rate := 1.0 / GROW_MINUTES * (1.6 if st["light"] else 1.0)
							st["growth"] = minf(1.0, float(st["growth"]) + rate)
							st["water"] = maxf(0.0, float(st["water"]) - 1.0 / WATER_MINUTES)
						else:
							st["dry_minutes"] = int(st["dry_minutes"]) + 1
						if int(GameState.minute) % 10 == 0:
							changed = true
						if float(st["growth"]) >= 1.0:
							changed = true
				"mixing", "lab":
					if st["busy"]:
						st["remaining"] = int(st["remaining"]) - 1
						if int(st["remaining"]) <= 0:
							st["busy"] = false
							changed = true
		if changed:
			Events.property_state_changed.emit(pid)


func _on_hour(h: int, _d: int) -> void:
	if h == 7:
		_daily_costs()
	if h >= 6 and h <= 22:
		_employees_work()


func _daily_costs() -> void:
	var total := 0
	for pid in properties:
		if properties[pid]["rented"]:
			var rent := int(prop_defs[pid].get("rent", 0))
			var paid := GameState.charge(rent)
			total += paid
			if paid < rent:
				properties[pid]["rented"] = false
				Events.toast("No has podido pagar el alquiler de %s. Has perdido el acceso." % property_name(pid), "warn")
				Events.property_state_changed.emit(pid)
	for e in employees.duplicate():
		var wage := int(e["wage"])
		if GameState.cash + GameState.bank < wage:
			employees.erase(e)
			Events.toast("%s se ha marchado: no le pudiste pagar." % e["name"], "warn")
			Events.employees_changed.emit()
			continue
		total += GameState.charge(wage)
	if total > 0:
		Events.toast("Gastos diarios (alquiler y salarios): -$%d" % total, "money")


func _employees_work() -> void:
	for e in employees:
		var pid := String(e["property"])
		if not has_access(pid):
			e["status"] = "Sin acceso a la propiedad"
			continue
		var stores := property_storages(pid)
		if stores.is_empty():
			e["status"] = "Necesita una estantería en la propiedad"
			continue
		match String(e["role"]):
			"botanist":
				e["status"] = _botanist_work(pid, stores)
			"packager":
				e["status"] = _packager_work(pid, stores)
			"chemist":
				e["status"] = _chemist_work(pid, stores)
	Events.employees_changed.emit()


func _take_from_stores(stores: Array, id: String) -> bool:
	for inv in stores:
		if (inv as Inventory).has(id):
			(inv as Inventory).remove(id, 1)
			return true
	return false


func _store_has(stores: Array, id: String) -> bool:
	for inv in stores:
		if (inv as Inventory).has(id):
			return true
	return false


func _botanist_work(pid: String, stores: Array) -> String:
	var did := 0
	var missing := ""
	for k in properties[pid]["stations"]:
		var st: Dictionary = properties[pid]["stations"][k]
		if st["type"] != "grow":
			continue
		if st["planted"] and float(st["growth"]) >= 1.0:
			for inv in stores:
				if harvest(pid, int(k), inv) != "" and not st["planted"]:
					did += 1
					break
		if not st["soil"]:
			for soil_id in ["premium_soil", "soil"]:
				if _take_from_stores(stores, soil_id):
					st["soil"] = true
					st["soil_quality"] = float(ItemDB.get_prop(soil_id, "soil_quality", 0.45))
					did += 1
					break
			if not st["soil"]:
				missing = "tierra"
		if st["soil"] and not st["planted"]:
			if _take_from_stores(stores, "glimmer_spores"):
				st["planted"] = true
				st["growth"] = 0.0
				st["dry_minutes"] = 0
				did += 1
			else:
				missing = "esporas"
		if st["planted"] and float(st["water"]) < 0.6:
			st["water"] = 1.0
			did += 1
	if did > 0:
		Events.property_state_changed.emit(pid)
	if missing != "":
		return "Faltan %s en la estantería" % missing
	return "Trabajando (%d tareas esta hora)" % did if did > 0 else "Todo al día"


func _packager_work(pid: String, stores: Array) -> String:
	var budget := 20
	var made := 0
	for inv_v in stores:
		var inv: Inventory = inv_v
		for i in inv.size():
			var s = inv.get_slot(i)
			while budget > 0 and s != null and ItemDB.is_product(s["id"]) and not ItemDB.is_packed_product(s["id"]):
				var pack := ""
				if int(s["qty"]) >= 5 and budget >= 5 and _store_has(stores, "jar"):
					pack = "jar"
				elif _store_has(stores, "baggie"):
					pack = "baggie"
				if pack == "":
					break
				var per := int(ItemDB.get_prop(pack, "units", 1))
				var out_id := ItemDB.packed_id(ItemDB.product_type(s["id"]), pack)
				var data: Dictionary = s["data"].duplicate(true)
				var dest: Inventory = null
				for o in stores:
					if (o as Inventory).can_add(out_id, 1, data) >= 1:
						dest = o
						break
				if dest == null:
					break
				_take_from_stores(stores, pack)
				inv.take_from_slot(i, per)
				dest.add(out_id, 1, data)
				budget -= per
				made += per
				s = inv.get_slot(i)
	if made > 0:
		GameState.stat_add("packaged", made)
		Events.property_state_changed.emit(pid)
		return "Ha empaquetado %d unidades" % made
	return "Sin producto o sin bolsitas/tarros"


func _chemist_work(pid: String, stores: Array) -> String:
	var status := "Sin laboratorio"
	for k in properties[pid]["stations"]:
		var st: Dictionary = properties[pid]["stations"][k]
		if st["type"] != "lab":
			continue
		if not st["busy"] and not (st["output"] as Dictionary).is_empty():
			for inv in stores:
				collect_output(pid, int(k), inv)
				if (st["output"] as Dictionary).is_empty():
					break
		if not st["busy"] and (st["output"] as Dictionary).is_empty():
			if _store_has(stores, "azure_salts") and _store_has(stores, "azure_reagent"):
				_take_from_stores(stores, "azure_salts")
				_take_from_stores(stores, "azure_reagent")
				st["busy"] = true
				st["remaining"] = LAB_MINUTES
				st["output"] = {"id": "azure_shard", "qty": LAB_YIELD, "data": {"quality": clampf(0.6 + _rng.randf_range(-0.05, 0.1), 0.0, 1.0), "effects": []}}
				status = "Laboratorio en marcha"
			else:
				status = "Faltan sales o reactivo"
		else:
			status = "Laboratorio en marcha"
	return status


# ------------------------------------------------------------------ Empleados

func hire(candidate_id: String, pid: String) -> bool:
	var cand: Dictionary = {}
	for c in EMPLOYEE_CANDIDATES:
		if c["id"] == candidate_id:
			cand = c
	if cand.is_empty() or is_hired(candidate_id):
		return false
	if GameState.rank < int(cand["rank"]):
		Events.toast("Necesitas rango %s." % GameState.rank_name(int(cand["rank"])), "warn")
		return false
	if not has_access(pid):
		return false
	var fee := int(cand["wage"])
	if not GameState.spend(fee, "hire"):
		return false
	var e: Dictionary = cand.duplicate(true)
	e["property"] = pid
	e["status"] = "Recién contratado"
	employees.append(e)
	Audio.play("cash")
	Events.toast("Has contratado a %s (%s). Primer día pagado: $%d" % [e["name"], ROLE_NAMES[e["role"]], fee], "info")
	Events.employee_hired.emit(candidate_id)
	Events.employees_changed.emit()
	return true


func fire(candidate_id: String) -> void:
	for e in employees.duplicate():
		if e["id"] == candidate_id:
			employees.erase(e)
			Events.toast("%s ya no trabaja para ti." % e["name"], "info")
	Events.employees_changed.emit()


func is_hired(candidate_id: String) -> bool:
	for e in employees:
		if e["id"] == candidate_id:
			return true
	return false


func reassign(candidate_id: String, pid: String) -> void:
	for e in employees:
		if e["id"] == candidate_id and has_access(pid):
			e["property"] = pid
	Events.employees_changed.emit()


func daily_cost() -> int:
	var total := 0
	for pid in properties:
		if properties[pid]["rented"]:
			total += int(prop_defs[pid].get("rent", 0))
	for e in employees:
		total += int(e["wage"])
	return total


# ------------------------------------------------------------------ Redada policial

func police_raid() -> void:
	var best_pid := ""
	var best_count := 0
	for pid in properties:
		if not has_access(pid):
			continue
		var n := 0
		for inv in property_storages(pid):
			n += Police.contraband_count(inv)
		if n > best_count:
			best_count = n
			best_pid = pid
	if best_pid == "":
		Events.toast("La policía registró tus propiedades, pero no encontró nada.", "police")
		return
	var taken := 0
	for inv in property_storages(best_pid):
		for i in (inv as Inventory).size():
			var s = (inv as Inventory).get_slot(i)
			if s != null and ItemDB.is_contraband(s["id"]):
				var n := int(ceil(int(s["qty"]) * 0.5))
				(inv as Inventory).take_from_slot(i, n)
				taken += n
	Events.toast("¡Redada en %s! Han confiscado %d objetos." % [property_name(best_pid), taken], "police")
	Events.property_state_changed.emit(best_pid)


# ------------------------------------------------------------------ Persistencia

func to_dict() -> Dictionary:
	var st_inv := {}
	for k in storages:
		st_inv[k] = (storages[k] as Inventory).to_dict()
	return {"properties": properties.duplicate(true), "employees": employees.duplicate(true), "storages": st_inv}


func from_dict(d: Dictionary) -> void:
	reset()
	var props: Dictionary = d.get("properties", {})
	for pid in props:
		if properties.has(pid):
			properties[pid]["owned"] = bool(props[pid].get("owned", false))
			properties[pid]["rented"] = bool(props[pid].get("rented", false))
			var stations: Dictionary = props[pid].get("stations", {})
			for k in stations:
				var st: Dictionary = stations[k]
				for num_key in ["remaining", "dry_minutes"]:
					if st.has(num_key):
						st[num_key] = int(st[num_key])
				if st.get("output", {}) is Dictionary and not (st.get("output", {}) as Dictionary).is_empty():
					st["output"]["qty"] = int(st["output"]["qty"])
				properties[pid]["stations"][str(k)] = st
	for e in d.get("employees", []):
		if e is Dictionary and e.has("id"):
			e["wage"] = int(e.get("wage", 0))
			employees.append(e)
	var st_inv: Dictionary = d.get("storages", {})
	for k in st_inv:
		var inv := Inventory.new(20, -1.0, "Estantería")
		inv.from_dict(st_inv[k])
		inv.max_weight = -1.0
		storages[k] = inv
