extends UIWindow
## Pantalla de guardado y carga con ranuras (autoguardado + 3 manuales).

var mode := "save"
var _list: VBoxContainer


func build() -> void:
	mode = String(payload.get("mode", "save"))
	var body := make_window(Vector2(640, 0), "Guardar partida" if mode == "save" else "Cargar partida")
	_list = VBoxContainer.new()
	body.add_child(_list)
	body.add_child(UITheme.button("Volver", _back, 140))
	_refresh()


func _back() -> void:
	if payload is Dictionary and payload.has("back") and ui:
		ui.open(String(payload["back"]))
	else:
		close()


func _refresh() -> void:
	UITheme.clear(_list)
	for slot in SaveSystem.SLOTS:
		var s: String = slot
		if mode == "save" and s == "auto":
			continue
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_LIGHT, 10))
		_list.add_child(p)
		var h := HBoxContainer.new()
		p.add_child(h)
		var meta := SaveSystem.read_meta(s)
		var title := "Autoguardado" if s == "auto" else "Ranura %s" % s
		var info := "Vacía"
		if not meta.is_empty():
			info = "%s, día %s, %s · %s · %s\n%s · Guardado: %s" % [meta.get("weekday", ""), str(meta.get("day", "?")), meta.get("time", ""), UITheme.money(int(meta.get("cash", 0))), meta.get("rank", ""), meta.get("quest", ""), String(meta.get("saved_at", "")).replace("T", " ")]
		var l := UITheme.label("%s\n%s" % [title, info], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if mode == "save":
			h.add_child(UITheme.button("Guardar", func() -> void: _save(s), 110))
		else:
			var b := UITheme.button("Cargar", func() -> void: SaveSystem.load_game(s), 110)
			b.disabled = meta.is_empty()
			h.add_child(b)
		if not meta.is_empty():
			var del := func() -> void:
				SaveSystem.delete_save(s)
				_refresh()
			h.add_child(UITheme.button("Borrar", del, 90))


func _save(s: String) -> void:
	if SaveSystem.save_game(s):
		Audio.play("quest", -6.0)
	_refresh()
