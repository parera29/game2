extends Node
## Opciones del juego (gráficos, audio, controles) persistidas en user://settings.cfg.
## También define el mapa de entrada por defecto y permite reasignar teclas.

const PATH := "user://settings.cfg"

## acción -> [etiqueta visible, binding por defecto]
const ACTIONS := {
	"move_forward": ["Avanzar", "key:87"],
	"move_back": ["Retroceder", "key:83"],
	"move_left": ["Izquierda", "key:65"],
	"move_right": ["Derecha", "key:68"],
	"sprint": ["Correr", "key:4194325"],
	"jump": ["Saltar", "key:32"],
	"crouch": ["Agacharse", "key:67"],
	"interact": ["Interactuar", "key:69"],
	"drop": ["Soltar objeto", "key:71"],
	"inventory": ["Inventario", "key:73"],
	"phone": ["Teléfono", "key:4194306"],
	"map": ["Mapa", "key:77"],
	"flashlight": ["Linterna", "key:70"],
	"use": ["Usar / Agarrar", "mouse:1"],
	"throw": ["Lanzar objeto agarrado", "mouse:2"],
	"quicksave": ["Guardado rápido", "key:4194336"],
	"quickload": ["Carga rápida", "key:4194340"],
	"slot_1": ["Casilla 1", "key:49"],
	"slot_2": ["Casilla 2", "key:50"],
	"slot_3": ["Casilla 3", "key:51"],
	"slot_4": ["Casilla 4", "key:52"],
	"slot_5": ["Casilla 5", "key:53"],
	"slot_6": ["Casilla 6", "key:54"],
	"slot_7": ["Casilla 7", "key:55"],
	"slot_8": ["Casilla 8", "key:56"],
}

var values := {
	"mouse_sensitivity": 0.25,
	"invert_y": false,
	"fov": 75.0,
	"fullscreen": false,
	"vsync": true,
	"shadows": 2,          # 0 off, 1 bajas, 2 altas
	"render_scale": 1.0,
	"view_distance": 220.0,
	"ssao": true,
	"glow": true,
	"msaa": 1,             # 0 off, 1 2x, 2 4x
	"max_fps": 0,
	"master_volume": 0.8,
	"music_volume": 0.5,
	"sfx_volume": 0.8,
	"ambient_volume": 0.6,
	"show_fps": false,
	"head_bob": true,
}

var bindings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		bindings[a] = ACTIONS[a][1]
	_ensure_ui_actions()
	load_settings()
	apply_bindings()
	apply_display()


func _ensure_ui_actions() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", ev)
	for a in ["scroll_up", "scroll_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_WHEEL_UP if a == "scroll_up" else MOUSE_BUTTON_WHEEL_DOWN
			InputMap.action_add_event(a, mb)


func get_value(key: String, default: Variant = null) -> Variant:
	return values.get(key, default)


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply_display()
	Events.settings_changed.emit()


static func event_from_string(s: String) -> InputEvent:
	var parts := s.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	return null


static func event_to_string(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return "key:%d" % code
	if ev is InputEventMouseButton:
		return "mouse:%d" % ev.button_index
	return ""


static func binding_label(s: String) -> String:
	var parts := s.split(":")
	if parts.size() != 2:
		return "?"
	if parts[0] == "key":
		var name := OS.get_keycode_string(int(parts[1]))
		return name if name != "" else "Tecla %s" % parts[1]
	match int(parts[1]):
		1: return "Clic izq."
		2: return "Clic der."
		3: return "Clic central"
		_: return "Ratón %s" % parts[1]


func rebind(action: String, ev: InputEvent) -> void:
	var s := event_to_string(ev)
	if s == "" or not ACTIONS.has(action):
		return
	# Si otra acción usaba esa tecla, se intercambian para no dejar conflictos.
	for other in bindings:
		if other != action and bindings[other] == s:
			bindings[other] = bindings[action]
	bindings[action] = s
	apply_bindings()
	save_settings()


func reset_bindings() -> void:
	for a in ACTIONS:
		bindings[a] = ACTIONS[a][1]
	apply_bindings()
	save_settings()


func apply_bindings() -> void:
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		var ev := event_from_string(String(bindings.get(a, ACTIONS[a][1])))
		if ev:
			InputMap.action_add_event(a, ev)
	# Flecha arriba como alternativa para el teléfono
	var up := InputEventKey.new()
	up.physical_keycode = KEY_UP
	InputMap.action_add_event("phone", up)


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	if win == null:
		return
	var want_fs: bool = values["fullscreen"]
	var mode := DisplayServer.window_get_mode()
	if want_fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(values["max_fps"])
	var vp := get_viewport()
	vp.scaling_3d_scale = clampf(float(values["render_scale"]), 0.5, 1.0)
	var msaa_modes := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
	vp.msaa_3d = msaa_modes[clampi(int(values["msaa"]), 0, 2)]
	match int(values["shadows"]):
		0:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
		_:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("game", k, values[k])
	for a in bindings:
		cf.set_value("bindings", a, bindings[a])
	var err := cf.save(PATH)
	if err != OK:
		push_warning("No se pudieron guardar las opciones (%d)" % err)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in values.keys():
		if cf.has_section_key("game", k):
			var v: Variant = cf.get_value("game", k)
			if typeof(v) == typeof(values[k]) or (typeof(values[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v
	for a in ACTIONS:
		if cf.has_section_key("bindings", a):
			var b := String(cf.get_value("bindings", a))
			if event_from_string(b) != null:
				bindings[a] = b
