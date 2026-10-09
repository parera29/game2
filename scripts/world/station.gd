class_name Station
extends StaticBody3D
## Hueco de estación dentro de una propiedad. Muestra un marcador si está libre
## o el modelo de la estación instalada, y redirige la interacción al negocio.

var property_id := ""
var slot := 0
var _visual: Node3D
var _label: Label3D
var _shape: CollisionShape3D
var _type := ""


func setup(pid: String, slot_index: int) -> void:
	property_id = pid
	slot = slot_index
	collision_layer = Geo.LAYER_INTERACT
	collision_mask = 0
	_shape = CollisionShape3D.new()
	add_child(_shape)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.003
	_label.font_size = 44
	_label.outline_size = 10
	_label.position = Vector3(0, 1.9, 0)
	_label.modulate = Color(1, 1, 1, 0.9)
	_label.no_depth_test = false
	add_child(_label)
	Events.property_state_changed.connect(_on_state_changed)
	Events.minute_passed.connect(_on_minute)
	refresh()


func _on_state_changed(pid: String) -> void:
	if pid == property_id:
		refresh()


func _on_minute(_m: int, _d: int) -> void:
	if _type in ["mixing", "lab", "grow"]:
		_update_label()


func _st() -> Dictionary:
	return Business.get_station(property_id, slot)


func refresh() -> void:
	var st := _st()
	var t := String(st.get("type", ""))
	if t != _type or t == "grow" or t == "storage":
		_type = t
		_rebuild(st)
	_update_label()


func _rebuild(st: Dictionary) -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	var sh := BoxShape3D.new()
	var wood := Mats.color(Color(0.45, 0.32, 0.22), 0.7)
	var metal := Mats.color(Color(0.55, 0.58, 0.62), 0.35, 0.7)
	match _type:
		"":
			sh.size = Vector3(1.4, 0.1, 1.4)
			_shape.position = Vector3(0, 0.05, 0)
			collision_layer = Geo.LAYER_INTERACT
			var mk := Mats.color(Color(0.4, 1.0, 0.5, 0.35), 0.5)
			for p in [Vector3(0, 0.01, 0.68), Vector3(0, 0.01, -0.68)]:
				Geo.box(_visual, Vector3(1.4, 0.02, 0.06), p, mk, false, 0.0, false)
			for p in [Vector3(0.68, 0.01, 0), Vector3(-0.68, 0.01, 0)]:
				Geo.box(_visual, Vector3(0.06, 0.02, 1.4), p, mk, false, 0.0, false)
		"grow":
			sh.size = Vector3(0.9, 1.0, 0.9)
			_shape.position = Vector3(0, 0.5, 0)
			collision_layer = Geo.LAYER_WORLD | Geo.LAYER_INTERACT
			Geo.box(_visual, Vector3(1.0, 0.3, 1.0), Vector3(0, 0.15, 0), wood, false)
			Geo.cylinder(_visual, 0.3, 0.45, Vector3(0, 0.52, 0), Mats.color(Color(0.72, 0.38, 0.22), 0.8), false, 0.4, 14)
			if st.get("soil", false):
				Geo.cylinder(_visual, 0.37, 0.04, Vector3(0, 0.74, 0), Mats.color(Color(0.25, 0.16, 0.1), 1.0), false, -1.0, 14)
			if st.get("planted", false):
				var g := float(st.get("growth", 0.0))
				var s := 0.15 + 0.85 * g
				var leaf := Mats.color(Color(0.25, 0.6, 0.2).lerp(Color(0.35, 0.75, 0.25), g), 0.7)
				Geo.cylinder(_visual, 0.025, 0.8 * s, Vector3(0, 0.76 + 0.4 * s, 0), Mats.color(Color(0.3, 0.5, 0.2)), false)
				for i in 6:
					var a := TAU * i / 6.0
					var h := 0.8 + 0.6 * s * (0.3 + 0.12 * i)
					var lm := Geo.sphere(_visual, 0.16 * s + 0.03, Vector3(cos(a) * 0.18 * s, h, sin(a) * 0.18 * s), leaf, 6)
					lm.scale = Vector3(1.4, 0.5, 0.8)
					lm.rotation.y = a
				Geo.sphere(_visual, 0.2 * s, Vector3(0, 0.78 + 0.85 * s, 0), leaf, 8)
				if g >= 1.0:
					for i in 5:
						var a2 := TAU * i / 5.0 + 0.3
						Geo.sphere(_visual, 0.07, Vector3(cos(a2) * 0.2, 1.3 + 0.1 * (i % 2), sin(a2) * 0.2), Mats.emissive(Color(0.75, 1.0, 0.4), 0.6), 6)
			if st.get("light", false):
				Geo.box(_visual, Vector3(0.8, 0.06, 0.5), Vector3(0, 2.1, 0), metal, false)
				Geo.box(_visual, Vector3(0.7, 0.02, 0.4), Vector3(0, 2.06, 0), Mats.emissive(Color(1.0, 0.45, 0.9), 3.0), false)
				Geo.cylinder(_visual, 0.01, 0.9, Vector3(0, 2.55, 0), metal, false)
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.5, 0.9)
				l.light_energy = 1.2
				l.omni_range = 3.0
				l.position = Vector3(0, 1.9, 0)
				_visual.add_child(l)
		"mixing":
			sh.size = Vector3(1.4, 1.0, 0.8)
			_shape.position = Vector3(0, 0.5, 0)
			collision_layer = Geo.LAYER_WORLD | Geo.LAYER_INTERACT
			_table(_visual, Vector3(1.4, 0.9, 0.8), metal)
			Geo.box(_visual, Vector3(0.5, 0.45, 0.45), Vector3(-0.3, 1.12, 0), Mats.color(Color(0.38, 0.45, 0.8), 0.4, 0.3), false)
			Geo.cylinder(_visual, 0.22, 0.25, Vector3(0.35, 1.03, 0), Mats.color(Color(0.85, 0.85, 0.9), 0.2, 0.6), false, 0.28)
			Geo.box(_visual, Vector3(0.08, 0.08, 0.02), Vector3(-0.3, 1.2, 0.23), Mats.emissive(Color(0.3, 1.0, 0.4), 2.0), false)
		"packaging":
			sh.size = Vector3(1.6, 1.0, 0.8)
			_shape.position = Vector3(0, 0.5, 0)
			collision_layer = Geo.LAYER_WORLD | Geo.LAYER_INTERACT
			_table(_visual, Vector3(1.6, 0.9, 0.8), wood)
			Geo.box(_visual, Vector3(0.35, 0.06, 0.3), Vector3(-0.45, 0.93, 0), metal, false)
			Geo.box(_visual, Vector3(0.3, 0.12, 0.25), Vector3(0.1, 0.96, 0.05), Mats.color(Color(0.8, 0.9, 0.95), 0.3), false)
			for i in 3:
				Geo.cylinder(_visual, 0.06, 0.14, Vector3(0.45 + i * 0.13, 0.97, -0.15), Mats.color(Color(0.7, 0.85, 0.75, 0.8), 0.1), false)
		"storage":
			sh.size = Vector3(1.6, 2.0, 0.6)
			_shape.position = Vector3(0, 1.0, 0)
			collision_layer = Geo.LAYER_WORLD | Geo.LAYER_INTERACT
			for x in [-0.78, 0.78]:
				for z in [-0.27, 0.27]:
					Geo.box(_visual, Vector3(0.05, 2.0, 0.05), Vector3(x, 1.0, z), metal, false)
			var inv := Business.storage_inventory(property_id, slot)
			var filled := 0
			for s in inv.slots:
				if s != null:
					filled += 1
			for i in 4:
				Geo.box(_visual, Vector3(1.6, 0.04, 0.6), Vector3(0, 0.1 + i * 0.6, 0), metal, false)
			for i in mini(filled, 12):
				var shelf := i / 4
				var col := i % 4
				Geo.box(_visual, Vector3(0.3, 0.3, 0.4), Vector3(-0.55 + col * 0.37, 0.27 + shelf * 0.6, 0), Mats.color(Color(0.6, 0.48, 0.32), 0.9), false)
		"lab":
			sh.size = Vector3(1.6, 1.0, 0.8)
			_shape.position = Vector3(0, 0.5, 0)
			collision_layer = Geo.LAYER_WORLD | Geo.LAYER_INTERACT
			_table(_visual, Vector3(1.6, 0.9, 0.8), Mats.color(Color(0.9, 0.9, 0.92), 0.3))
			var busy := bool(st.get("busy", false))
			var liquid := Mats.emissive(Color(0.2, 0.55, 1.0), 2.5 if busy else 0.3)
			for i in 3:
				Geo.cylinder(_visual, 0.1, 0.3, Vector3(-0.5 + i * 0.4, 1.05, 0), Mats.glass(), false, 0.04)
				Geo.cylinder(_visual, 0.085, 0.14, Vector3(-0.5 + i * 0.4, 0.98, 0), liquid, false, 0.06)
			Geo.box(_visual, Vector3(0.4, 0.3, 0.35), Vector3(0.6, 1.05, 0), metal, false)
	_shape.shape = sh


func _table(parent: Node3D, size: Vector3, mat: Material) -> void:
	Geo.box(parent, Vector3(size.x, 0.06, size.z), Vector3(0, size.y - 0.03, 0), mat, false)
	for x in [-1, 1]:
		for z in [-1, 1]:
			Geo.box(parent, Vector3(0.06, size.y - 0.06, 0.06), Vector3(x * (size.x * 0.5 - 0.06), (size.y - 0.06) * 0.5, z * (size.z * 0.5 - 0.06)), mat, false)


func _update_label() -> void:
	var st := _st()
	match _type:
		"":
			_label.text = "Hueco libre" if Business.has_access(property_id) else ""
			_label.position.y = 0.6
		"grow":
			_label.position.y = 1.9
			if not st.get("soil", false):
				_label.text = "Maceta vacía"
			elif not st.get("planted", false):
				_label.text = "Lista para plantar"
			elif float(st["growth"]) >= 1.0:
				_label.text = "¡Lista para cosechar!"
			else:
				var water := float(st["water"])
				_label.text = "Crecimiento %d%%\nAgua %d%%%s" % [int(float(st["growth"]) * 100.0), int(water * 100.0), "  ¡SECA!" if water <= 0.0 else ""]
		"mixing", "lab":
			_label.position.y = 1.7
			if st.get("busy", false):
				_label.text = "Procesando... %d min" % int(st["remaining"])
			elif not (st.get("output", {}) as Dictionary).is_empty():
				_label.text = "¡Listo para recoger!"
			else:
				_label.text = Business.STATION_NAMES[_type]
		_:
			_label.position.y = 2.3 if _type == "storage" else 1.5
			_label.text = Business.STATION_NAMES.get(_type, "")


func get_prompt(player: Node) -> String:
	if not Business.has_access(property_id):
		return ""
	var st := _st()
	var held := _held_id(player)
	match _type:
		"":
			var kit := _kit_to_install(player)
			if kit != "":
				return "Instalar %s" % ItemDB.display_name(kit)
			return "Hueco libre (necesitas un kit de instalación)"
		"grow":
			var extra := "  (Agachado+E: desmontar)" if Business.can_uninstall(property_id, slot) else ""
			if st["planted"] and float(st["growth"]) >= 1.0:
				return "Cosechar"
			if held == "kit_grow_light" and not st["light"]:
				return "Instalar lámpara de cultivo"
			if not st["soil"]:
				return "Añadir tierra" + extra
			if not st["planted"]:
				return "Plantar esporas"
			if held == "watering_can":
				return "Regar planta"
			return "Ver planta (equipa la regadera para regar)"
		"mixing":
			if not st["busy"] and not (st["output"] as Dictionary).is_empty():
				return "Recoger mezcla"
			return "Usar estación de mezcla"
		"packaging":
			return "Usar estación de empaquetado"
		"storage":
			return "Abrir estantería"
		"lab":
			if not st["busy"] and not (st["output"] as Dictionary).is_empty():
				return "Recoger Azure"
			if st["busy"]:
				return "Laboratorio en marcha (%d min)" % int(st["remaining"])
			return "Iniciar laboratorio (1 sal + 1 reactivo)"
	return ""


func interact(player: Node) -> void:
	if not Business.has_access(property_id):
		return
	var st := _st()
	var crouching := bool(player.get("crouching"))
	if crouching and _type != "" and Business.can_uninstall(property_id, slot):
		if Business.uninstall_station(property_id, slot):
			Events.toast("Estación desmontada.", "info")
		return
	match _type:
		"":
			var kit := _kit_to_install(player)
			if kit == "":
				Events.toast("Compra un kit en la ferretería para instalar algo aquí.", "info")
				return
			Business.install_station(property_id, slot, kit)
		"grow":
			var held := _held_id(player)
			var held_slot := int(player.get("hotbar_index"))
			var msg := Business.grow_action(property_id, slot, held, held_slot)
			if msg != "":
				Events.toast(msg, "info")
		"mixing":
			if not st["busy"] and not (st["output"] as Dictionary).is_empty():
				Events.toast(Business.collect_output(property_id, slot, GameState.player_inventory), "info")
			else:
				Events.request_ui.emit("mixing", {"property": property_id, "slot": slot})
		"packaging":
			Events.request_ui.emit("packaging", {"property": property_id, "slot": slot})
		"storage":
			Events.request_ui.emit("container", {"inventory": Business.storage_inventory(property_id, slot), "title": "Estantería", "property": property_id})
		"lab":
			if not st["busy"] and not (st["output"] as Dictionary).is_empty():
				Events.toast(Business.collect_output(property_id, slot, GameState.player_inventory), "info")
			elif not st["busy"]:
				Events.toast(Business.start_lab(property_id, slot, GameState.player_inventory), "info")


func _held_id(player: Node) -> String:
	if player and player.has_method("held_item_id"):
		return String(player.held_item_id())
	return ""


func _kit_to_install(player: Node) -> String:
	var held := _held_id(player)
	if held != "" and ItemDB.get_prop(held, "station", "") != "":
		return held
	for s in GameState.player_inventory.slots:
		if s != null and ItemDB.get_prop(s["id"], "station", "") != "":
			return String(s["id"])
	return ""
