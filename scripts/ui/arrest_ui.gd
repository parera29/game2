extends UIWindow
## Pantalla de detención con el resumen de las consecuencias.


func build() -> void:
	var body := make_window(Vector2(560, 0), "DETENIDO")
	var fine := int(payload.get("fine", 0))
	var items := int(payload.get("items", 0))
	var l := UITheme.label("Has pasado unas horas en el calabozo de la comisaría.\n\nMulta pagada: %s\nObjetos ilegales confiscados: %d\n\nLa policía te tendrá vigilado durante un tiempo y el distrito donde te detuvieron puede quedar cerrado temporalmente." % [UITheme.money(fine), items], 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	body.add_child(l)
	body.add_child(UITheme.button("Continuar", close, 160))
