extends UIWindow
## Estación de mezcla: combina producto sin empaquetar con un aditivo para añadir efectos.

var pid := ""
var slot := 0
var _prod: OptionButton
var _add: OptionButton
var _preview: Label
var _prod_slots: Array = []
var _add_ids: Array = []


func build() -> void:
	pid = String(payload.get("property", ""))
	slot = int(payload.get("slot", 0))
	var body := make_window(Vector2(600, 0), "Estación de mezcla")
	var st := Business.get_station(pid, slot)
	if st.get("busy", false):
		body.add_child(UITheme.label("Mezclando... faltan %d min." % int(st["remaining"]), 17, UITheme.WARN))
		body.add_child(UITheme.button("Cerrar", close, 120))
		return
	body.add_child(UITheme.label("Mezcla hasta %d unidades de producto sin empaquetar con el mismo número de aditivos.\nCada aditivo añade un efecto (máx. %d) que aumenta el valor." % [Business.MIX_MAX, Business.MAX_EFFECTS], 14, UITheme.TEXT_DIM))
	var g := GridContainer.new()
	g.columns = 2
	body.add_child(g)
	g.add_child(UITheme.label("Producto:", 15))
	_prod = OptionButton.new()
	_prod.custom_minimum_size = Vector2(380, 0)
	g.add_child(_prod)
	g.add_child(UITheme.label("Aditivo:", 15))
	_add = OptionButton.new()
	g.add_child(_add)
	_preview = UITheme.label("", 15, UITheme.ACCENT)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size = Vector2(560, 0)
	body.add_child(_preview)
	var h := HBoxContainer.new()
	body.add_child(h)
	h.add_child(UITheme.button("Mezclar", _mix, 140))
	var uninstall := func() -> void:
		if Business.uninstall_station(pid, slot):
			close()
	var un := UITheme.button("Desmontar estación", uninstall, 200)
	un.disabled = not Business.can_uninstall(pid, slot)
	h.add_child(un)
	_prod.item_selected.connect(func(_i: int) -> void: _update_preview())
	_add.item_selected.connect(func(_i: int) -> void: _update_preview())
	_fill()


func _fill() -> void:
	var inv: Inventory = GameState.player_inventory
	_prod.clear()
	_add.clear()
	_prod_slots.clear()
	_add_ids.clear()
	for i in inv.size():
		var s = inv.get_slot(i)
		if s != null and ItemDB.is_product(s["id"]) and not ItemDB.is_packed_product(s["id"]):
			_prod.add_icon_item(ItemDB.get_icon(s["id"]), "%s x%d (Q %d%%)" % [ItemDB.display_name(s["id"], s["data"]), int(s["qty"]), int(float(s["data"].get("quality", 0.5)) * 100.0)])
			_prod_slots.append(i)
	var seen := {}
	for s in inv.slots:
		if s != null and ItemDB.category(s["id"]) == "additive" and not seen.has(s["id"]):
			seen[s["id"]] = true
			var eff := String(ItemDB.get_prop(s["id"], "effect", ""))
			_add.add_icon_item(ItemDB.get_icon(s["id"]), "%s x%d → %s" % [ItemDB.display_name(s["id"]), inv.count(s["id"]), ItemDB.EFFECTS[eff]["name"]])
			_add_ids.append(String(s["id"]))
	_update_preview()


func _update_preview() -> void:
	if _prod_slots.is_empty():
		_preview.text = "No llevas producto sin empaquetar."
		return
	if _add_ids.is_empty():
		_preview.text = "No llevas aditivos (Gas-Mart, Ray, Sal...)."
		return
	var s = GameState.player_inventory.get_slot(_prod_slots[_prod.selected])
	var add_id: String = _add_ids[_add.selected]
	var eff := String(ItemDB.get_prop(add_id, "effect", ""))
	var data: Dictionary = s["data"].duplicate(true)
	var before := ItemDB.unit_value(ItemDB.product_type(s["id"]), data)
	var effects: Array = data.get("effects", []).duplicate()
	if effects.has(eff):
		_preview.text = "Ese producto ya tiene el efecto %s." % ItemDB.EFFECTS[eff]["name"]
		return
	if effects.size() >= Business.MAX_EFFECTS:
		effects.pop_front()
	effects.append(eff)
	data["effects"] = effects
	var after := ItemDB.unit_value(ItemDB.product_type(s["id"]), data)
	var n := mini(mini(int(s["qty"]), GameState.player_inventory.count(add_id)), Business.MIX_MAX)
	_preview.text = "Resultado: %s\nValor por unidad: %s → %s · Unidades: %d · Tiempo: %d min" % [ItemDB.display_name(s["id"], data), UITheme.money(before), UITheme.money(after), n, n * Business.MIX_MINUTES_PER_UNIT]


func _mix() -> void:
	if _prod_slots.is_empty() or _add_ids.is_empty():
		return
	var msg := Business.start_mix(pid, slot, _prod_slots[_prod.selected], _add_ids[_add.selected])
	Events.toast(msg, "info")
	if Business.get_station(pid, slot).get("busy", false):
		close()
	else:
		_fill()
