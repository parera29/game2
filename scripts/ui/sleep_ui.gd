extends UIWindow
## Dormir: confirma, funde a negro, avanza el tiempo hasta las 7:00 y autoguarda.

var _fade: ColorRect


func build() -> void:
	var body := make_window(Vector2(480, 0), "Dormir")
	var l := UITheme.label("¿Dormir hasta las 7:00?\nLas plantas seguirán creciendo, se cobrarán los gastos diarios y la partida se guardará automáticamente.", 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	body.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(h)
	h.add_child(UITheme.button("No", close, 100))
	h.add_child(UITheme.button("Dormir", _sleep, 120))


func _sleep() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		GameState.sleep()
		SaveSystem.save_game("auto"))
	tw.tween_interval(0.6)
	tw.tween_property(_fade, "color:a", 0.0, 0.8)
	tw.tween_callback(close)
