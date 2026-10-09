extends Node
## Gestor de misiones data-driven (data/quests.json). Cada misión tiene una lista de
## objetivos secuenciales. Los objetivos de tipo "contador" escuchan eventos del bus;
## los de tipo "estado" se comprueban periódicamente.

const PATH := "res://data/quests.json"

var defs: Dictionary = {}
var active: Dictionary = {}      # id -> {"stage": int, "progress": int}
var completed: Array = []
var tracked: String = ""


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			defs = parsed
	if defs.is_empty():
		push_error("QuestManager: no se pudieron cargar las misiones")
	Events.item_bought.connect(func(id, q): _count("buy", q, {"item": id}))
	Events.deal_completed.connect(func(_c, _u, _t): _count("deal", 1))
	Events.harvested.connect(func(_i, _q): _count("harvest", 1))
	Events.packaged.connect(func(_i, q): _count("package", q))
	Events.mixed.connect(func(_i, q): _count("mix", q))
	Events.produced.connect(func(id, q): _count("produce", q, {"item": id}))
	Events.station_installed.connect(func(st, _p): _count("install", 1, {"station": st}))
	Events.location_reached.connect(func(loc): _count("reach", 1, {"location": loc}))
	Events.minute_passed.connect(_on_minute)
	Events.rank_changed.connect(func(_r): check_states())
	Events.property_acquired.connect(func(_p): check_states())
	Events.customer_unlocked.connect(func(_c): check_states())
	Events.employee_hired.connect(func(_e): check_states())
	GameState.player_inventory.changed.connect(check_states)


func _on_minute(m: int, _d: int) -> void:
	if m % 5 == 0:
		check_states()


func reset() -> void:
	active.clear()
	completed.clear()
	tracked = ""
	if not GameState.player_inventory.changed.is_connected(check_states):
		GameState.player_inventory.changed.connect(check_states)


func new_game() -> void:
	reset()
	start("q_welcome")


# ------------------------------------------------------------------ API

func is_active(id: String) -> bool:
	return active.has(id)


func is_completed(id: String) -> bool:
	return completed.has(id)


func is_available(id: String) -> bool:
	return defs.has(id) and not active.has(id) and not completed.has(id)


func title(id: String) -> String:
	return String(defs.get(id, {}).get("title", id))


func current_objective(id: String) -> Dictionary:
	if not active.has(id):
		return {}
	var objs: Array = defs[id]["objectives"]
	var st := int(active[id]["stage"])
	if st >= objs.size():
		return {}
	return objs[st]


func objective_text(id: String) -> String:
	var o := current_objective(id)
	if o.is_empty():
		return ""
	var t := String(o.get("text", ""))
	var target := _target_count(o)
	if target > 1:
		t += " (%d/%d)" % [mini(_current_count(id, o), target), target]
	return t


func start(id: String) -> void:
	if not defs.has(id) or active.has(id) or completed.has(id):
		return
	active[id] = {"stage": 0, "progress": 0}
	var d: Dictionary = defs[id]
	for it in d.get("start_items", []):
		GameState.player_inventory.add(String(it[0]), int(it[1]), it[2] if it.size() > 2 else {})
	if d.has("spawn_item"):
		_spawn_quest_item(id)
	if tracked == "" or String(d.get("kind", "")) == "main":
		tracked = id
	Audio.play("quest")
	Events.toast("Nueva misión: %s" % d.get("title", id), "quest")
	Events.quest_started.emit(id)
	check_states()


## Diálogo: devuelve la frase de misión pendiente con un NPC (objetivo talk).
func pending_talk(npc_id: String) -> Dictionary:
	for id in active.keys():
		var o := current_objective(id)
		if o.get("type", "") == "talk" and o.get("npc", "") == npc_id:
			var line := String(defs[id].get("talk_lines", {}).get(npc_id, "..."))
			return {"quest": id, "line": line}
	return {}


func complete_talk(npc_id: String) -> void:
	for id in active.keys():
		var o := current_objective(id)
		if o.get("type", "") == "talk" and o.get("npc", "") == npc_id:
			_advance(id)


## Diálogo: objetivos de entrega disponibles con un NPC.
func pending_deliveries(npc_id: String) -> Array:
	var out: Array = []
	for id in active.keys():
		var o := current_objective(id)
		if o.get("type", "") == "deliver" and o.get("npc", "") == npc_id:
			out.append({"quest": id, "item": String(o["item"]), "count": int(o.get("count", 1))})
	return out


func try_deliver(quest_id: String) -> bool:
	var o := current_objective(quest_id)
	if o.get("type", "") != "deliver":
		return false
	var item := String(o["item"])
	var n := int(o.get("count", 1))
	if not GameState.player_inventory.remove(item, n):
		Events.toast("No llevas %d x %s." % [n, ItemDB.display_name(item)], "warn")
		return false
	Events.item_delivered.emit(String(o["npc"]), item, n)
	_advance(quest_id)
	return true


## Misiones secundarias que ofrece un NPC.
func offers_for(npc_id: String) -> Array:
	var out: Array = []
	for id in defs:
		var d: Dictionary = defs[id]
		if d.get("kind", "") == "side" and d.get("giver", "") == npc_id and is_available(id):
			out.append(id)
	return out


func set_tracked(id: String) -> void:
	if active.has(id):
		tracked = id
		Events.quest_updated.emit(id)


func get_tracked() -> String:
	if active.has(tracked):
		return tracked
	for id in active:
		if String(defs[id].get("kind", "")) == "main":
			tracked = id
			return id
	if active.size() > 0:
		tracked = active.keys()[0]
		return tracked
	return ""


# ------------------------------------------------------------------ Progreso interno

func _target_count(o: Dictionary) -> int:
	match String(o.get("type", "")):
		"buy", "deal", "harvest", "package", "mix", "produce", "install", "customers", "property", "hire", "deliver":
			return int(o.get("count", 1))
		_:
			return 1


func _current_count(id: String, o: Dictionary) -> int:
	match String(o.get("type", "")):
		"customers":
			return Customers.unlocked_count()
		"property":
			return Business.owned_property_count(false)
		"hire":
			return Business.employees.size()
		_:
			return int(active[id]["progress"])


func _count(kind: String, amount: int, match_fields: Dictionary = {}) -> void:
	for id in active.keys():
		var o := current_objective(id)
		if o.get("type", "") != kind:
			continue
		var ok := true
		for k in match_fields:
			if o.has(k) and String(o[k]) != String(match_fields[k]):
				ok = false
		if not ok:
			continue
		active[id]["progress"] = int(active[id]["progress"]) + amount
		if int(active[id]["progress"]) >= _target_count(o):
			_advance(id)
		else:
			Events.quest_updated.emit(id)


func check_states() -> void:
	for id in active.keys():
		if not active.has(id):
			continue
		var o := current_objective(id)
		var done := false
		match String(o.get("type", "")):
			"rank":
				done = GameState.rank >= int(o.get("value", 0))
			"customers":
				done = Customers.unlocked_count() >= int(o.get("count", 1))
			"revenue":
				done = int(GameState.stats.get("revenue", 0)) >= int(o.get("amount", 0))
			"property":
				done = Business.owned_property_count(false) >= int(o.get("count", 1))
			"own":
				done = Business.owns(String(o.get("property", "")))
			"hire":
				done = Business.employees.size() >= int(o.get("count", 1))
			"pickup":
				done = GameState.player_inventory.has(String(o.get("item", "")))
			"install":
				# Cuenta también las estaciones instaladas antes de llegar al objetivo.
				done = Business.count_stations(String(o.get("station", ""))) >= int(o.get("count", 1))
		if done:
			_advance(id)


func _advance(id: String) -> void:
	if not active.has(id):
		return
	active[id]["stage"] = int(active[id]["stage"]) + 1
	active[id]["progress"] = 0
	var objs: Array = defs[id]["objectives"]
	if int(active[id]["stage"]) >= objs.size():
		_complete(id)
	else:
		Audio.play("notify")
		Events.toast("Objetivo: %s" % objective_text(id), "quest")
		Events.quest_updated.emit(id)
		check_states.call_deferred()


func _complete(id: String) -> void:
	active.erase(id)
	completed.append(id)
	var d: Dictionary = defs[id]
	var r: Dictionary = d.get("rewards", {})
	if int(r.get("cash", 0)) > 0:
		GameState.add_cash(int(r["cash"]))
	for it in r.get("items", []):
		var left := GameState.player_inventory.add(String(it[0]), int(it[1]), it[2] if it.size() > 2 else {})
		if left > 0 and GameState.world:
			GameState.world.spawn_item_near_player(String(it[0]), left, it[2] if it.size() > 2 else {})
	GameState.stat_add("quests_done", 1)
	Audio.play("quest")
	Events.toast("Misión completada: %s" % d.get("title", id), "quest")
	if int(r.get("cash", 0)) > 0:
		Events.toast("+$%d" % int(r["cash"]), "money")
	Events.quest_completed.emit(id)
	if int(r.get("xp", 0)) > 0:
		GameState.add_xp(int(r["xp"]))
	_on_completed_hook(id)
	if d.has("next"):
		start(String(d["next"]))
	if tracked == id:
		tracked = ""
		get_tracked()


func _on_completed_hook(id: String) -> void:
	match id:
		"q_welcome":
			Customers.force_order("kyle", 20)
		"q_docks":
			pass


func _spawn_quest_item(id: String) -> void:
	var si: Dictionary = defs[id].get("spawn_item", {})
	if si.is_empty() or GameState.world == null:
		return
	var item := String(si["item"])
	if GameState.player_inventory.has(item):
		return
	GameState.world.spawn_quest_item(item, String(si["location"]))


## Tras cargar el mundo: recrea objetos de misión que aún hay que recoger.
func respawn_quest_items() -> void:
	for id in active:
		var o := current_objective(id)
		if o.get("type", "") == "pickup":
			_spawn_quest_item(id)


# ------------------------------------------------------------------ Persistencia

func to_dict() -> Dictionary:
	return {"active": active.duplicate(true), "completed": completed.duplicate(), "tracked": tracked}


func from_dict(d: Dictionary) -> void:
	reset()
	var a: Dictionary = d.get("active", {})
	for id in a:
		if defs.has(id):
			active[id] = {"stage": int(a[id].get("stage", 0)), "progress": int(a[id].get("progress", 0))}
	for id in d.get("completed", []):
		if defs.has(id):
			completed.append(String(id))
	tracked = String(d.get("tracked", ""))
