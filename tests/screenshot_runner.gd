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
		SaveSystem.new_game.call_deferred()


func _process(_delta: float) -> void:
	if scene_file_path != "":
		return
	_frames += 1
	if _frames == 10 and GameState.player and args.size() >= 6:
		GameState.player.teleport(Vector3(float(args[0]), float(args[1]), float(args[2])), deg_to_rad(float(args[3])))
		GameState.player.head.rotation.x = deg_to_rad(float(args[4]))
		GameState.minute = float(args[5]) * 60.0
	if _frames == 60 and args.size() > 7 and args[7] != "":
		var ui := get_tree().get_first_node_in_group("ui_manager")
		if ui:
			ui.open(args[7], {"app": args[8]} if args.size() > 8 else {})
	if _frames == 90:
		var img := get_viewport().get_texture().get_image()
		var out := args[6] if args.size() > 6 else "user://shot.png"
		img.save_png(out)
		print("SHOT_SAVED ", out)
		get_tree().quit()
