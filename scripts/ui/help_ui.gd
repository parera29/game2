extends UIWindow
## Ayuda: controles actuales y guía rápida del bucle de juego.


func build() -> void:
	var body := make_window(Vector2(820, 0), "Ayuda")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 560)
	body.add_child(scroll)
	var v := VBoxContainer.new()
	scroll.add_child(v)
	v.add_child(UITheme.label("Controles", 20, UITheme.ACCENT))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 24)
	v.add_child(g)
	for a in Settings.ACTIONS:
		g.add_child(UITheme.label(String(Settings.ACTIONS[a][0]), 14, UITheme.TEXT_DIM))
		g.add_child(UITheme.label(Settings.binding_label(String(Settings.bindings[a])), 14))
	g.add_child(UITheme.label("Menú / cerrar", 14, UITheme.TEXT_DIM))
	g.add_child(UITheme.label("Escape", 14))
	v.add_child(UITheme.label("\nCómo funciona el negocio", 20, UITheme.ACCENT))
	var guide := """1. Compra un kit de maceta (Ferretería de Hank), tierra y esporas de Glimmer (puesto de Ray).
2. Instala la maceta en un hueco libre de tu propiedad (E sobre el marcador verde).
3. Echa tierra, planta las esporas y riega con la regadera (se rellena en el fregadero). Tarda unas 12 h de juego.
4. Cosecha, instala una estación de empaquetado y empaqueta en bolsitas (1 u) o tarros (5 u).
5. Mezcla con aditivos en la estación de mezcla para añadir efectos y valor.
6. Responde a los pedidos en el teléfono (Tab), acude al punto de encuentro y entrega el producto.
7. Regala muestras a los vecinos marcados con '?' para conseguir clientes nuevos.
8. Evita a la policía: no vendas delante de agentes ni testigos, respeta el toque de queda (22:00-05:00) y no huyas de los registros.
9. Duerme en tu cama (a partir de las 19:00) para pasar la noche y autoguardar. Paga el alquiler y los salarios a las 7:00.
10. Sube de rango para desbloquear Downtown, Los Muelles y Uptown, nuevos productos, propiedades y empleados."""
	var l := UITheme.label(guide, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	v.add_child(l)
	var back := func() -> void:
		if payload is Dictionary and payload.has("back"):
			ui.open(String(payload["back"]))
		else:
			close()
	body.add_child(UITheme.button("Volver", back, 140))
