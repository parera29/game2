extends Node
## Prueba de integración automática del bucle principal de juego.
## Ejecutar: godot --headless --path . res://tests/test_runner.tscn
## Sale con código 0 si todo pasa, 1 si algo falla.

var _fails: Array = []
var _passes := 0


func _ready() -> void:
	if scene_file_path != "":
		var helper := Node.new()
		helper.set_script(load("res://tests/test_runner.gd"))
		helper.name = "TestHelper"
		get_tree().root.add_child.call_deferred(helper)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	if cond:
		_passes += 1
		print("  OK   ", what)
	else:
		_fails.append(what)
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ui() -> Node:
	return get_tree().get_first_node_in_group("ui_manager")


func _run() -> void:
	print("== Redmont Hustle: prueba de integración ==")
	SaveSystem.delete_save("3")
	SaveSystem.new_game()
	await frames(20)
	var w: World = GameState.world
	check(w != null, "el mundo se ha construido")
	check(GameState.player != null, "existe el jugador")
	check(GameState.cash == GameState.START_CASH, "dinero inicial = %d" % GameState.START_CASH)
	check(GameState.player_inventory.has("watering_can"), "inventario inicial con regadera")
	check(Quests.is_active("q_welcome"), "misión inicial activa")
	check(w.nav.astar.get_point_count() > 60, "grafo de navegación (%d puntos)" % w.nav.astar.get_point_count())
	check(w.meeting_points.size() >= 12, "puntos de encuentro (%d)" % w.meeting_points.size())
	check(w.npc_root.get_child_count() > 40, "NPC creados (%d)" % w.npc_root.get_child_count())
	check(w.doors.size() >= 12, "puertas (%d)" % w.doors.size())
	check(get_tree().get_nodes_in_group("police").size() >= 5, "policías patrullando")

	# --- Puerta de la habitación del motel (propiedad alquilada) debe abrirse
	var motel_door: Door = null
	for d in w.doors:
		if (d as Door).door_name.contains("habitación 4"):
			motel_door = d
	check(motel_door != null and motel_door.get_prompt(GameState.player).begins_with("Abrir"), "la puerta de la habitación se puede abrir")
	motel_door.interact(GameState.player)
	await frames(30)
	check(motel_door.is_open, "puerta abierta")

	# --- Ir al diner y hablar con Marco
	GameState.player.teleport(w.locations["diner"], 0.0)
	await frames(10)
	check(Quests.current_objective("q_welcome").get("type", "") == "talk", "al entrar al diner se avanza al objetivo de hablar")
	var marco: NPC = null
	for n in w.npc_root.get_children():
		if n is NPC and n.npc_id == "marco":
			marco = n
	check(marco != null, "Marco existe")
	GameState.player.teleport(marco.global_position + Vector3(0, 0, 1.5), 0.0)
	await frames(5)
	marco.interact(GameState.player)
	await frames(3)
	check(_ui().current_name == "dialogue", "se abre el diálogo con Marco")
	var dlg = _ui().current
	(dlg._opts.get_child(0) as Button).pressed.emit()
	await frames(3)
	check(Quests.is_completed("q_welcome"), "misión 'Bienvenido' completada")
	check(GameState.player_inventory.count("glimmer_bag") == 6, "recompensa: 6 bolsitas de Glimmer")
	check(Quests.is_active("q_first_deal"), "misión 'Primer cliente' activa")
	_ui().close()

	# --- Pedido de Kyle
	GameState.skip_minutes(25)
	check(not Customers.get_order("kyle").is_empty(), "Kyle envía un pedido por el teléfono")
	var cash_before := GameState.cash
	Customers.accept_order("kyle")
	check(Customers.has_deal("kyle"), "entrega programada con Kyle")
	var dl := Customers.get_deal("kyle")
	check(w.meeting_points.has(String(dl["location"])), "punto de encuentro válido: %s" % dl["location_name"])
	# El cliente camina hasta el punto
	var kyle: NPC = w.customers_npcs["kyle"]
	await frames(30)
	check(kyle.state in ["go_deal", "wait_deal"], "Kyle se dirige a la cita (estado %s)" % kyle.state)
	# Entrega mediante diálogo
	GameState.player.teleport(kyle.global_position + Vector3(1.2, 0.2, 0), 0.0)
	await frames(5)
	kyle.interact(GameState.player)
	await frames(3)
	dlg = _ui().current
	(dlg._opts.get_child(0) as Button).pressed.emit()
	await frames(3)
	check(GameState.cash > cash_before, "cobrado por la entrega (+$%d)" % (GameState.cash - cash_before))
	check(int(GameState.stats["deals"]) == 1, "estadística de ventas = 1")
	check(Quests.is_active("q_setup"), "misión 'Montar el negocio' activa")
	_ui().close()

	# --- Compras en tiendas (a través de la UI de tienda)
	GameState.minute = 10 * 60
	GameState.cash = 1000
	_ui().open("shop", {"shop": "hardware"})
	await frames(2)
	var shop = _ui().current
	shop._buy("kit_grow_tent", 1)
	shop._buy("soil", 2)
	shop._buy("kit_packaging", 1)
	_ui().close()
	_ui().open("shop", {"shop": "ray"})
	await frames(2)
	shop = _ui().current
	shop._buy("glimmer_spores", 1)
	_ui().close()
	_ui().open("shop", {"shop": "gasmart"})
	await frames(2)
	_ui().current._buy("baggie", 20)
	_ui().close()
	check(GameState.player_inventory.has("kit_grow_tent") and GameState.player_inventory.count("soil") == 2 and GameState.player_inventory.has("glimmer_spores"), "compras realizadas")
	check(GameState.cash < 1000, "el dinero se ha descontado ($%d)" % GameState.cash)

	# --- Instalar y cultivar
	check(Business.install_station("motel_room", 0, "kit_grow_tent"), "maceta instalada en el motel")
	await frames(2)
	check(Quests.is_active("q_grow"), "misión 'Mano verde' activa")
	var r1 := Business.grow_action("motel_room", 0, "soil", 0)
	var r2 := Business.grow_action("motel_room", 0, "", 0)
	var can_i := GameState.player_inventory.find_first(func(s): return s["id"] == "watering_can")
	GameState.player_inventory.get_slot(can_i)["data"]["water"] = 6
	var r3 := Business.grow_action("motel_room", 0, "watering_can", can_i)
	check(Business.get_station("motel_room", 0)["planted"] and float(Business.get_station("motel_room", 0)["water"]) > 0.9, "tierra, plantación y riego (%s / %s / %s)" % [r1, r2, r3])
	for i in 3:
		GameState.skip_minutes(250)
		if float(Business.get_station("motel_room", 0)["growth"]) < 1.0:
			Business.grow_action("motel_room", 0, "watering_can", can_i)
	GameState.skip_minutes(100)
	var st := Business.get_station("motel_room", 0)
	check(float(st["growth"]) >= 1.0, "la planta ha crecido (%.0f%%)" % (float(st["growth"]) * 100.0))
	var hr := Business.grow_action("motel_room", 0, "", 0)
	check(GameState.player_inventory.count("glimmer_bud") >= 6, "cosecha: %s" % hr)
	check(Quests.is_active("q_package"), "misión 'Buena presentación' activa")

	# --- Empaquetar
	Business.install_station("motel_room", 1, "kit_packaging")
	var bud_i := GameState.player_inventory.find_first(func(s): return s["id"] == "glimmer_bud")
	var made := Business.package_stack(GameState.player_inventory, bud_i, "baggie", 9999)
	check(made >= 6, "empaquetadas %d bolsitas" % made)
	await frames(2)
	check(Quests.is_active("q_network"), "misión 'Red de clientes' activa")

	# --- Muestra a cliente potencial
	var res := ""
	for attempt in 6:
		Customers.state["jess"]["cooldown_until"] = 0
		res = Customers.give_sample("jess")
		if res == "success":
			break
	check(res == "success" and Customers.is_unlocked("jess"), "muestra gratis convierte a Jess en cliente (%s)" % res)

	# --- Guardar y cargar
	GameState.player.teleport(w.property_spawns["motel_room"]["pos"], 0.0)
	await frames(5)
	var saved_cash := GameState.cash
	var saved_bags := GameState.player_inventory.count("glimmer_bag")
	var saved_day := GameState.day
	check(SaveSystem.save_game("3"), "partida guardada en la ranura 3")
	GameState.cash = 1
	GameState.player_inventory.clear()
	SaveSystem.load_game("3")
	await frames(25)
	w = GameState.world
	check(w != null and is_instance_valid(w), "mundo recargado tras cargar partida")
	check(GameState.cash == saved_cash, "dinero restaurado ($%d)" % GameState.cash)
	check(GameState.player_inventory.count("glimmer_bag") == saved_bags, "inventario restaurado (%d bolsitas)" % saved_bags)
	check(GameState.day == saved_day, "día restaurado")
	check(Business.get_station("motel_room", 1).get("type", "") == "packaging", "estaciones restauradas")
	check(Quests.is_active("q_network") and Quests.is_completed("q_first_deal"), "misiones restauradas")
	check(Customers.is_unlocked("jess"), "relaciones con clientes restauradas")
	check(GameState.player.global_position.distance_to(w.property_spawns["motel_room"]["pos"]) < 1.5, "posición del jugador restaurada")

	# --- Policía: detención y confiscación
	GameState.cash = 500
	var contraband := Police.contraband_count(GameState.player_inventory)
	check(contraband > 0, "el jugador lleva material ilegal (%d)" % contraband)
	Police.set_wanted(Police.Wanted.PURSUIT)
	Police.arrest()
	await frames(3)
	check(Police.contraband_count(GameState.player_inventory) == 0, "material confiscado")
	check(GameState.cash < 500, "multa cobrada ($%d restantes)" % GameState.cash)
	check(int(GameState.stats["arrests"]) == 1, "detención registrada")
	check(GameState.player.global_position.distance_to(w.police_station_pos) < 2.0, "trasladado a la comisaría")
	_ui().close()

	# --- Rango y desbloqueo de distrito
	GameState.add_xp(200)
	await frames(3)
	check(GameState.is_district_unlocked("downtown"), "Downtown desbloqueado al subir de rango")
	var barrier_open := true
	for n in w.barriers["downtown"]:
		if (n as Node3D).visible:
			barrier_open = false
	check(barrier_open, "barrera de Downtown retirada")

	# --- Todas las ventanas de UI se abren sin errores
	for ui_name in ["inventory", "phone", "map", "pause", "settings", "saveload", "help", "atm", "sleep"]:
		_ui().open(ui_name, {"mode": "load"} if ui_name == "saveload" else {})
		await frames(2)
		check(_ui().current_name == ui_name, "UI '%s' abierta" % ui_name)
		_ui().close()
	_ui().open("phone", {"app": "messages"})
	await frames(2)
	for app in ["contacts", "map", "quests", "products", "business", "staff", "stats", "news"]:
		_ui().current._go(app)
		await frames(1)
	check(_ui().current_name == "phone", "todas las apps del teléfono se abren")
	_ui().close()

	SaveSystem.delete_save("3")
	print("== Resultado: %d OK, %d FALLOS ==" % [_passes, _fails.size()])
	for f in _fails:
		print("   - ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)
