extends UIWindow
## Mapa a pantalla completa.


func build() -> void:
	var body := make_window(Vector2(980, 820), "Mapa de Redmont")
	var mv := MapView.new()
	mv.custom_minimum_size = Vector2(940, 700)
	mv.waypoint_selected.connect(func(pos: Vector3, n: String) -> void:
		if ui and ui.hud:
			ui.hud.set_waypoint(pos, n))
	body.add_child(mv)
	var h := HBoxContainer.new()
	body.add_child(h)
	for l in [["Tiendas", Color(0.95, 0.75, 0.25)], ["Misiones", Color(1.0, 0.55, 0.3)], ["Propiedades", Color(0.6, 0.85, 0.6)], ["Hogar", Color(0.4, 0.95, 0.5)], ["Banco", Color(0.4, 0.9, 0.9)], ["Entregas", Color(0.3, 1.0, 0.3)], ["Policía", Color(0.35, 0.55, 1.0)]]:
		h.add_child(UITheme.label("● " + String(l[0]) + "   ", 14, l[1]))
	h.add_child(UITheme.button("Quitar destino", func() -> void:
		if ui and ui.hud:
			ui.hud.waypoint_pos = Vector3.ZERO))
