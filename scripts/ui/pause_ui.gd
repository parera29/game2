extends UIWindow
## Menú de pausa (detiene el juego).


func build() -> void:
	var body := make_window(Vector2(380, 0), "Pausa")
	body.add_child(UITheme.label("%s · Día %d · %s" % [GameState.weekday_name(), GameState.day, GameState.time_string()], 15, UITheme.TEXT_DIM))
	for b in [
		["Continuar", close],
		["Guardar partida", func() -> void: ui.open("saveload", {"mode": "save", "back": "pause"})],
		["Cargar partida", func() -> void: ui.open("saveload", {"mode": "load", "back": "pause"})],
		["Opciones", func() -> void: ui.open("settings", {"back": "pause"})],
		["Ayuda y controles", func() -> void: ui.open("help", {"back": "pause"})],
		["Menú principal", func() -> void: ui.open("confirm", {"title": "Salir al menú", "text": "Se perderá el progreso no guardado. ¿Salir al menú principal?", "on_yes": SaveSystem.to_menu})],
		["Salir del juego", func() -> void: ui.open("confirm", {"title": "Salir", "text": "Se perderá el progreso no guardado. ¿Salir del juego?", "on_yes": func() -> void: get_tree().quit()})],
	]:
		var btn := UITheme.button(String(b[0]), b[1], 340)
		btn.custom_minimum_size.y = 44
		body.add_child(btn)
