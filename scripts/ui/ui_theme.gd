class_name UITheme
extends RefCounted
## Tema visual común y utilidades para construir interfaces por código.

const BG := Color(0.07, 0.08, 0.1, 0.92)
const BG_LIGHT := Color(0.13, 0.15, 0.18, 0.95)
const BG_SLOT := Color(0.16, 0.18, 0.22, 0.95)
const ACCENT := Color(0.42, 0.82, 0.42)
const ACCENT_DIM := Color(0.25, 0.5, 0.28)
const MONEY := Color(0.45, 0.95, 0.45)
const WARN := Color(1.0, 0.75, 0.25)
const DANGER := Color(1.0, 0.35, 0.3)
const POLICE := Color(0.4, 0.6, 1.0)
const TEXT := Color(0.93, 0.94, 0.95)
const TEXT_DIM := Color(0.62, 0.65, 0.7)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	var panel := _box(BG, 10, Color(1, 1, 1, 0.06))
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := _box(Color(0.18, 0.21, 0.25, 0.95), 8, Color(1, 1, 1, 0.05))
	var btn_h := _box(Color(0.24, 0.3, 0.27, 1.0), 8, ACCENT_DIM)
	var btn_p := _box(Color(0.16, 0.36, 0.2, 1.0), 8, ACCENT)
	var btn_d := _box(Color(0.12, 0.13, 0.15, 0.8), 8, Color(1, 1, 1, 0.02))
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = {"normal": btn, "hover": btn_h, "pressed": btn_p, "disabled": btn_d, "focus": btn_h}[k]
		t.set_stylebox(k, "Button", sb)
		t.set_stylebox(k, "OptionButton", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.5))
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	var le := _box(Color(0.1, 0.11, 0.13, 1.0), 6, Color(1, 1, 1, 0.08))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", _box(Color(0.1, 0.11, 0.13, 1.0), 6, ACCENT_DIM))
	var bar_bg := _box(Color(0.1, 0.1, 0.12, 0.9), 4, Color(0, 0, 0, 0))
	var bar_fg := _box(ACCENT, 4, Color(0, 0, 0, 0))
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	t.set_stylebox("slider", "HSlider", _box(Color(0.2, 0.22, 0.25), 4, Color(0, 0, 0, 0)))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT_DIM, 4, Color(0, 0, 0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT, 4, Color(0, 0, 0, 0)))
	var tab_sel := _box(Color(0.18, 0.3, 0.22), 6, ACCENT_DIM)
	var tab_un := _box(Color(0.12, 0.13, 0.16), 6, Color(0, 0, 0, 0))
	t.set_stylebox("tab_selected", "TabBar", tab_sel)
	t.set_stylebox("tab_unselected", "TabBar", tab_un)
	t.set_stylebox("tab_hovered", "TabBar", tab_sel)
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", tab_un)
	t.set_stylebox("tab_hovered", "TabContainer", tab_sel)
	t.set_stylebox("panel", "TabContainer", _box(Color(0.09, 0.1, 0.12, 0.9), 8, Color(1, 1, 1, 0.04)))
	t.set_stylebox("panel", "ItemList", _box(Color(0.09, 0.1, 0.12, 0.9), 6, Color(1, 1, 1, 0.04)))
	t.set_stylebox("panel", "PopupMenu", _box(BG_LIGHT, 6, Color(1, 1, 1, 0.08)))
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.05, 0.06, 0.07, 0.97), 6, ACCENT_DIM))
	_theme = t
	return t


static func _box(c: Color, radius: int, border: Color, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w if border.a > 0.0 else 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = true
	return sb


static func panel_style(c: Color = BG, radius: int = 10, border: Color = Color(1, 1, 1, 0.06)) -> StyleBoxFlat:
	return _box(c, radius, border)


static func label(text: String, size: int = 17, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func shadow_label(text: String, size: int = 17, color: Color = TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	return l


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 36)
	b.pressed.connect(func() -> void: Audio.play("click", -4.0))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func title_bar(text: String, on_close: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var t := label(text, 24, ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if on_close.is_valid():
		var x := button("✕", on_close, 40)
		h.add_child(x)
	return h


static func window(size: Vector2, title: String, on_close: Callable) -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = size
	root.add_theme_stylebox_override("panel", panel_style(BG, 14, Color(1, 1, 1, 0.08)))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	root.add_child(margin)
	var v := VBoxContainer.new()
	margin.add_child(v)
	v.add_child(title_bar(title, on_close))
	var sep := HSeparator.new()
	v.add_child(sep)
	return {"root": root, "body": v}


static func center(ctrl: Control) -> void:
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	ctrl.reset_size()
	ctrl.position = (ctrl.get_viewport_rect().size - ctrl.size) * 0.5 if ctrl.is_inside_tree() else ctrl.position


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-$" if v < 0 else "$") + out
