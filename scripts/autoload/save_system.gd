extends Node
## Guardado y carga en JSON (user://saves/). Ranuras: "auto", "1", "2", "3".
## La carga siempre recarga la escena del juego para partir de un estado limpio.

const DIR := "user://saves"
const VERSION := 1
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const SLOTS := ["auto", "1", "2", "3"]

var pending_load: Dictionary = {}     # datos a aplicar cuando el mundo esté listo
var starting_new_game := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: String) -> String:
	return "%s/slot_%s.json" % [DIR, slot]


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func any_save() -> bool:
	for s in SLOTS:
		if has_save(s):
			return true
	return false


func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for s in SLOTS:
		if has_save(s):
			var t := FileAccess.get_modified_time(slot_path(s))
			if t > best_t:
				best_t = t
				best = s
	return best


func read_meta(slot: String) -> Dictionary:
	var d := _read(slot)
	return d.get("meta", {})


func _read(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		push_warning("No se pudo abrir la partida %s" % slot)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Partida %s corrupta" % slot)
		return {}
	return parsed


func save_game(slot: String) -> bool:
	if GameState.world == null:
		Events.toast("No se puede guardar ahora.", "warn")
		return false
	if Police.wanted >= Police.Wanted.PURSUIT:
		Events.toast("No puedes guardar mientras te persigue la policía.", "warn")
		return false
	var data := {
		"version": VERSION,
		"meta": {
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"day": GameState.day, "time": GameState.time_string(), "weekday": GameState.weekday_name(),
			"cash": GameState.cash, "bank": GameState.bank, "rank": GameState.rank_name(),
			"quest": Quests.title(Quests.get_tracked()),
		},
		"game": GameState.to_dict(),
		"quests": Quests.to_dict(),
		"customers": Customers.to_dict(),
		"police": Police.to_dict(),
		"business": Business.to_dict(),
		"events": RandomEvents.to_dict(),
		"world": GameState.world.to_save_dict(),
	}
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Events.toast("Error al guardar (%d)." % FileAccess.get_open_error(), "warn")
		return false
	f.store_string(JSON.stringify(_to_json_safe(data), "\t"))
	f.close()
	# Escritura atómica: se renombra el temporal sobre el definitivo
	var dir := DirAccess.open(DIR)
	if dir.file_exists(slot_path(slot).get_file()):
		dir.remove(slot_path(slot).get_file())
	var err := dir.rename(tmp.get_file(), slot_path(slot).get_file())
	if err != OK:
		Events.toast("Error al guardar (%d)." % err, "warn")
		return false
	Events.toast("Partida guardada (%s)." % ("autoguardado" if slot == "auto" else "ranura " + slot), "info")
	return true


## Convierte Vector3 y similares a tipos JSON.
func _to_json_safe(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[str(k)] = _to_json_safe(v[k])
			return out
		TYPE_ARRAY:
			var arr := []
			for x in v:
				arr.append(_to_json_safe(x))
			return arr
		TYPE_VECTOR3:
			return [v.x, v.y, v.z]
		TYPE_FLOAT:
			if is_nan(v) or is_inf(v):
				return 0.0
			return v
		_:
			return v


func load_game(slot: String) -> bool:
	var d := _read(slot)
	if d.is_empty():
		Events.toast("No se pudo cargar la partida.", "warn")
		return false
	if int(d.get("version", 0)) > VERSION:
		Events.toast("La partida es de una versión más nueva.", "warn")
		return false
	pending_load = d
	starting_new_game = false
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


func new_game() -> void:
	pending_load = {}
	starting_new_game = true
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func delete_save(slot: String) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


## Aplica los datos de los sistemas (antes de construir el mundo).
func apply_systems(d: Dictionary) -> void:
	GameState.from_dict(d.get("game", {}))
	Business.from_dict(d.get("business", {}))
	Customers.from_dict(d.get("customers", {}))
	Quests.from_dict(d.get("quests", {}))
	Police.from_dict(d.get("police", {}))
	RandomEvents.from_dict(d.get("events", {}))


func reset_all_for_new_game() -> void:
	GameState.new_game_setup()
	Business.reset()
	Customers.reset()
	Police.reset()
	RandomEvents.reset()
	Quests.new_game()


func to_menu() -> void:
	GameState.time_running = false
	GameState.world = null
	GameState.player = null
	Audio.set_siren(false)
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
