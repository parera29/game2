extends Node
## Herramienta de pruebas: carga el juego, coloca al jugador y la hora según
## argumentos (-- x y z yaw pitch hora salida.png) y guarda una captura.

var _frames := 0
var args: PackedStringArray


func _ready() -> void:
	args = OS.get_cmdline_user_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if scene_file_path != "":
		var helper := Node.new()
		helper.set_script(load("res://tests/screenshot_runner.gd"))
		helper.name = "ScreenshotHelper"
		get_tree().root.add_child.call_deferred(helper)
		if args.size() > 0 and args[0] == "menu":
			get_tree().change_scene_to_file.call_deferred("res://scenes/main_menu.tscn")
		else:
			SaveSystem.new_game.call_deferred()


func _process(_delta: float) -> void:
	if scene_file_path != "":
		return
	_frames += 1
	if _frames == 50 and args.size() > 9 and args[9] == "talk":
		for n in GameState.world.npc_root.get_children():
			if n.npc_id == args[10]:
				n.interact(GameState.player)
	if _frames == 8 and args.size() > 9 and args[9] == "stations":
		var inv: Inventory = GameState.player_inventory
		for k in ["kit_grow_tent", "kit_mixing", "kit_packaging"]:
			inv.add(k, 1)
		Business.install_station("motel_room", 0, "kit_grow_tent")
		Business.install_station("motel_room", 1, "kit_mixing")
		Business.install_station("motel_room", 2, "kit_packaging")
		var st := Business.get_station("motel_room", 0)
		st.merge({"soil": true, "soil_quality": 0.6, "planted": true, "growth": 0.7, "water": 0.8, "light": true}, true)
		Events.property_state_changed.emit("motel_room")
	if _frames == 8 and args.size() > 9 and args[9] == "unlock":
		GameState.add_xp(9000)
	if _frames == 10 and GameState.player and args.size() >= 6:
		GameState.player.teleport(Vector3(float(args[0]), float(args[1]), float(args[2])), deg_to_rad(float(args[3])))
		GameState.player.head.rotation.x = deg_to_rad(float(args[4]))
		GameState.minute = float(args[5]) * 60.0
	if _frames == 60 and args.size() > 7 and args[7] != "":
		var ui := get_tree().get_first_node_in_group("ui_manager")
		if ui:
			ui.open(args[7], {"app": args[8], "shop": args[8]} if args.size() > 8 else {})
	if _frames == 90:
		var img := get_viewport().get_texture().get_image()
		var out := args[6] if args.size() > 6 else (args[1] if args.size() > 1 else "user://shot.png")
		img.save_png(out)
		print("SHOT_SAVED ", out)
		get_tree().quit()
