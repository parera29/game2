class_name ItemSlot
extends PanelContainer
## Casilla de inventario con icono, cantidad, arrastrar y soltar entre inventarios,
## Mayús+clic para transferir y clic derecho para usar.

signal hovered(slot: ItemSlot)
signal quick_transfer(slot: ItemSlot)
signal use_requested(slot: ItemSlot)

var inv: Inventory
var index := 0
var selected := false
var compact := false
var _icon: TextureRect
var _qty: Label
var _key: Label
var _style_normal: StyleBoxFlat
var _style_sel: StyleBoxFlat


func setup(p_inv: Inventory, p_index: int, size_px: int = 64, key_hint: String = "") -> void:
	inv = p_inv
	index = p_index
	custom_minimum_size = Vector2(size_px, size_px)
	_style_normal = UITheme.panel_style(UITheme.BG_SLOT, 8, Color(1, 1, 1, 0.07))
	_style_sel = UITheme.panel_style(Color(0.18, 0.3, 0.2, 0.95), 8, UITheme.ACCENT)
	_style_sel.set_border_width_all(2)
	for sb in [_style_normal, _style_sel]:
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", _style_normal)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_qty = UITheme.shadow_label("", 15, Color.WHITE)
	_qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_qty.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_qty)
	if key_hint != "":
		_key = UITheme.shadow_label(key_hint, 12, UITheme.TEXT_DIM)
		_key.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_key)
	mouse_entered.connect(func() -> void: hovered.emit(self))
	refresh()


func set_selected(v: bool) -> void:
	selected = v
	add_theme_stylebox_override("panel", _style_sel if v else _style_normal)


func refresh() -> void:
	if inv == null:
		return
	var s = inv.get_slot(index)
	if s == null:
		_icon.texture = null
		_qty.text = ""
		tooltip_text = ""
		return
	_icon.texture = ItemDB.get_icon(s["id"])
	_qty.text = str(s["qty"]) if int(s["qty"]) > 1 else ""
	if s["id"] == "watering_can":
		_qty.text = "%d" % int(s["data"].get("water", 0))
	tooltip_text = ""


func get_item() -> Variant:
	return inv.get_slot(index) if inv else null


func _get_drag_data(_at_position: Vector2) -> Variant:
	var s = get_item()
	if s == null:
		return null
	var prev := TextureRect.new()
	prev.texture = ItemDB.get_icon(s["id"])
	prev.custom_minimum_size = Vector2(56, 56)
	prev.size = Vector2(56, 56)
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.modulate = Color(1, 1, 1, 0.85)
	var c := Control.new()
	c.add_child(prev)
	prev.position = -Vector2(28, 28)
	set_drag_preview(c)
	var half := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_CTRL)
	return {"type": "item_slot", "inv": inv, "index": index, "half": half}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "item_slot"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var src: Inventory = data["inv"]
	var src_i: int = data["index"]
	var s = src.get_slot(src_i)
	if s == null:
		return
	var qty := -1
	if data.get("half", false) and int(s["qty"]) > 1:
		qty = int(s["qty"]) / 2
	if src.move_slot(src_i, inv, index, qty):
		Audio.play("pickup", -10.0)
	else:
		Audio.play("error", -8.0)
		if inv.max_weight >= 0.0 and src != inv:
			Events.toast("No cabe (límite de peso o casilla ocupada).", "warn")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			quick_transfer.emit(self)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			use_requested.emit(self)
			accept_event()
