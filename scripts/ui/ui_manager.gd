extends CanvasLayer
## Gestor de interfaz: HUD permanente y una ventana modal a la vez.
## Controla el modo del ratón, la entrada del jugador, la pausa y los atajos.

const WINDOWS := {
	"inventory": "res://scripts/ui/inventory_ui.gd",
	"container": "res://scripts/ui/inventory_ui.gd",
	"shop": "res://scripts/ui/shop_ui.gd",
	"dialogue": "res://scripts/ui/dialogue_ui.gd",
	"phone": "res://scripts/ui/phone_ui.gd",
	"map": "res://scripts/ui/map_ui.gd",
	"pause": "res://scripts/ui/pause_ui.gd",
	"settings": "res://scripts/ui/settings_ui.gd",
	"saveload": "res://scripts/ui/saveload_ui.gd",
	"help": "res://scripts/ui/help_ui.gd",
	"mixing": "res://scripts/ui/mixing_ui.gd",
	"packaging": "res://scripts/ui/packaging_ui.gd",
	"atm": "res://scripts/ui/atm_ui.gd",
	"confirm": "res://scripts/ui/confirm_ui.gd",
	"sleep": "res://scripts/ui/sleep_ui.gd",
	"arrested": "res://scripts/ui/arrest_ui.gd",
}
const PAUSING := ["pause", "settings", "saveload", "help", "arrested"]

var hud: HUD
var current: UIWindow = null
var current_name := ""
var _root: Control
var _modal_root: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("ui_manager")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	_root.add_child(hud)
	_modal_root = Control.new()
	_modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal_root)
	Events.request_ui.connect(open)
	Events.player_arrested.connect(func(fine: int, items: int) -> void: open.call_deferred("arrested", {"fine": fine, "items": items}))
	_capture_mouse(true)


func _capture_mouse(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_open() -> bool:
	return current != null


func open(ui_name: String, payload: Variant = null) -> void:
	if not WINDOWS.has(ui_name):
		push_warning("UI desconocida: %s" % ui_name)
		return
	if current:
		_close_current()
	var script: GDScript = load(WINDOWS[ui_name])
	var w: UIWindow = script.new()
	w.ui = self
	w.payload = payload if payload != null else {}
	w.process_mode = Node.PROCESS_MODE_ALWAYS if ui_name in PAUSING else Node.PROCESS_MODE_INHERIT
	current = w
	current_name = ui_name
	_modal_root.add_child(w)
	get_tree().paused = ui_name in PAUSING
	_capture_mouse(false)
	if GameState.player:
		GameState.player.set_input_enabled(false)
	hud.set_modal(true)


func _close_current() -> void:
	if current and is_instance_valid(current):
		_modal_root.remove_child(current)
		current.queue_free()
		Events.ui_closed.emit(current_name)
	current = null
	current_name = ""


func close() -> void:
	_close_current()
	get_tree().paused = false
	_capture_mouse(true)
	if GameState.player:
		GameState.player.set_input_enabled(true)
	hud.set_modal(false)


func _input(event: InputEvent) -> void:
	# Se procesa antes que la GUI para que Tab/Esc no los consuma el foco de los botones.
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.is_action_pressed("pause"):
		if current:
			if current_name in ["settings", "saveload", "help"] and current.payload is Dictionary and current.payload.has("back"):
				open(String(current.payload["back"]))
			else:
				close()
		else:
			open("pause")
		get_viewport().set_input_as_handled()
		return
	if current:
		if (event.is_action_pressed("inventory") and current_name in ["inventory", "container"]) \
				or (event.is_action_pressed("phone") and current_name == "phone") \
				or (event.is_action_pressed("map") and current_name == "map"):
			close()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if current:
		return
	if event.is_action_pressed("inventory"):
		open("inventory")
	elif event.is_action_pressed("phone"):
		open("phone")
	elif event.is_action_pressed("map"):
		open("map")
	elif event.is_action_pressed("quicksave"):
		SaveSystem.save_game("1")
	elif event.is_action_pressed("quickload"):
		if SaveSystem.has_save("1"):
			SaveSystem.load_game("1")
		else:
			Events.toast("No hay partida en la ranura 1.", "warn")
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Al perder el foco de la ventana se abre la pausa para no seguir jugando a ciegas
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and current == null and GameState.time_running and DisplayServer.get_name() != "headless":
		open("pause")
