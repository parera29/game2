extends UIWindow
## Opciones: gráficos, audio, controles (con reasignación de teclas) y juego.
## Todo se aplica al momento y se guarda en user://settings.cfg.

var _waiting_action := ""
var _bind_buttons: Dictionary = {}


func build() -> void:
	var body := make_window(Vector2(760, 0), "Opciones")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(720, 520)
	body.add_child(tabs)
	tabs.add_child(_graphics_tab())
	tabs.add_child(_audio_tab())
	tabs.add_child(_controls_tab())
	tabs.add_child(_game_tab())
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UITheme.button("Volver", _back, 140))


func _back() -> void:
	Settings.save_settings()
	if payload is Dictionary and payload.has("back") and ui:
		ui.open(String(payload["back"]))
	else:
		close()


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	return v


func _row(parent: VBoxContainer, label: String, ctrl: Control) -> void:
	var h := HBoxContainer.new()
	var l := UITheme.label(label, 15)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	parent.add_child(h)


func _check(key: String) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key, false))
	c.toggled.connect(func(v: bool) -> void: Settings.set_value(key, v))
	return c


func _slider(key: String, mn: float, mx: float, step: float, fmt: String = "%.2f") -> HBoxContainer:
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = float(Settings.get_value(key, mn))
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UITheme.label(fmt % s.value, 14, UITheme.TEXT_DIM)
	l.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(v: float) -> void:
		l.text = fmt % v
		Settings.set_value(key, v))
	h.add_child(s)
	h.add_child(l)
	return h


func _option(key: String, items: Array) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(String(it))
	o.selected = clampi(int(Settings.get_value(key, 0)), 0, items.size() - 1)
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, i))
	return o


func _graphics_tab() -> Control:
	var v := _tab("Gráficos")
	_row(v, "Pantalla completa", _check("fullscreen"))
	_row(v, "Sincronización vertical (V-Sync)", _check("vsync"))
	_row(v, "Calidad de sombras", _option("shadows", ["Desactivadas", "Bajas", "Altas"]))
	_row(v, "Antialiasing (MSAA)", _option("msaa", ["Desactivado", "2x", "4x"]))
	_row(v, "Escala de resolución 3D", _slider("render_scale", 0.5, 1.0, 0.05))
	_row(v, "Distancia de visión (m)", _slider("view_distance", 100.0, 400.0, 10.0, "%.0f"))
	_row(v, "Oclusión ambiental (SSAO)", _check("ssao"))
	_row(v, "Resplandor (glow)", _check("glow"))
	_row(v, "Límite de FPS (0 = sin límite)", _slider("max_fps", 0.0, 240.0, 30.0, "%.0f"))
	_row(v, "Mostrar FPS", _check("show_fps"))
	return v.get_parent()


func _audio_tab() -> Control:
	var v := _tab("Audio")
	_row(v, "Volumen general", _slider("master_volume", 0.0, 1.0, 0.05))
	_row(v, "Música", _slider("music_volume", 0.0, 1.0, 0.05))
	_row(v, "Efectos", _slider("sfx_volume", 0.0, 1.0, 0.05))
	_row(v, "Ambiente", _slider("ambient_volume", 0.0, 1.0, 0.05))
	return v.get_parent()


func _controls_tab() -> Control:
	var v := _tab("Controles")
	_row(v, "Sensibilidad del ratón", _slider("mouse_sensitivity", 0.05, 1.0, 0.01))
	_row(v, "Invertir eje Y", _check("invert_y"))
	v.add_child(UITheme.label("Haz clic en una tecla y pulsa la nueva (Esc para cancelar).", 14, UITheme.TEXT_DIM))
	for a in Settings.ACTIONS:
		var action: String = a
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 32)
		b.text = Settings.binding_label(String(Settings.bindings[action]))
		b.pressed.connect(func() -> void:
			_waiting_action = action
			b.text = "Pulsa una tecla...")
		_bind_buttons[action] = b
		_row(v, String(Settings.ACTIONS[action][0]), b)
	v.add_child(UITheme.button("Restablecer controles", func() -> void:
		Settings.reset_bindings()
		_refresh_bindings()))
	return v.get_parent()


func _game_tab() -> Control:
	var v := _tab("Juego")
	_row(v, "Campo de visión (FOV)", _slider("fov", 60.0, 100.0, 1.0, "%.0f"))
	_row(v, "Balanceo de cámara al andar", _check("head_bob"))
	return v.get_parent()


func _refresh_bindings() -> void:
	for a in _bind_buttons:
		(_bind_buttons[a] as Button).text = Settings.binding_label(String(Settings.bindings[a]))


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_waiting_action = ""
			_refresh_bindings()
		else:
			Settings.rebind(_waiting_action, event)
			_waiting_action = ""
			_refresh_bindings()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		# Evitar capturar el propio clic del botón
		if event.button_index == MOUSE_BUTTON_LEFT and _bind_buttons[_waiting_action].get_global_rect().has_point(event.position):
			return
		Settings.rebind(_waiting_action, event)
		_waiting_action = ""
		_refresh_bindings()
		get_viewport().set_input_as_handled()
