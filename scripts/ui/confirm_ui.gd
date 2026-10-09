extends UIWindow
## Diálogo de confirmación genérico (payload: title, text, on_yes).


func build() -> void:
	var body := make_window(Vector2(520, 0), String(payload.get("title", "Confirmar")))
	var l := UITheme.label(String(payload.get("text", "¿Seguro?")), 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	body.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UITheme.button("Cancelar", close, 120))
	var accept := func() -> void:
		var cb: Callable = payload.get("on_yes", Callable())
		close()
		if cb.is_valid():
			cb.call()
	h.add_child(UITheme.button("Aceptar", accept, 120))
