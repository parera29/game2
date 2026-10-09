extends UIWindow
## Estación de empaquetado: convierte producto sin empaquetar en bolsitas (1 u) o tarros (5 u).

var pid := ""
var slot := 0
var _list: VBoxContainer
var _info: Label


func build() -> void:
	pid = String(payload.get("property", ""))
	slot = int(payload.get("slot", 0))
	var body := make_window(Vector2(640, 0), "Estación de empaquetado")
	_info = UITheme.label("", 15, UITheme.TEXT_DIM)
	body.add_child(_info)
	_list = VBoxContainer.new()
	body.add_child(_list)
	var h := HBoxContainer.new()
	body.add_child(h)
	var uninstall := func() -> void:
		if Business.uninstall_station(pid, slot):
			close()
	var un := UITheme.button("Desmontar estación", uninstall, 200)
	un.disabled = not Business.can_uninstall(pid, slot)
	h.add_child(un)
	GameState.player_inventory.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var inv: Inventory = GameState.player_inventory
	_info.text = "Bolsitas: %d · Tarros: %d   (se compran en el Gas-Mart y en el puesto de Ray)" % [inv.count("baggie"), inv.count("jar")]
	UITheme.clear(_list)
	var any := false
	for i in inv.size():
		var s = inv.get_slot(i)
		if s == null or not ItemDB.is_product(s["id"]) or ItemDB.is_packed_product(s["id"]):
			continue
		any = true
		var idx := i
		var h := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = ItemDB.get_icon(s["id"])
		icon.custom_minimum_size = Vector2(44, 44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.add_child(icon)
		var l := UITheme.label("%s x%d\nCalidad %d%%" % [ItemDB.display_name(s["id"], s["data"]), int(s["qty"]), int(float(s["data"].get("quality", 0.5)) * 100.0)], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UITheme.button("Bolsita x1", func() -> void: _pack(idx, "baggie", 1)))
		h.add_child(UITheme.button("Bolsitas (todo)", func() -> void: _pack(idx, "baggie", 9999)))
		h.add_child(UITheme.button("Tarros (todo)", func() -> void: _pack(idx, "jar", 9999)))
		_list.add_child(h)
	if not any:
		_list.add_child(UITheme.label("No llevas producto sin empaquetar (cogollos o fragmentos).", 15, UITheme.TEXT_DIM))


func _pack(idx: int, packaging: String, max_units: int) -> void:
	var inv: Inventory = GameState.player_inventory
	if not inv.has(packaging):
		Events.toast("Necesitas %s." % ItemDB.display_name(packaging).to_lower(), "warn")
		Audio.play("error", -6.0)
		return
	var made := Business.package_stack(inv, idx, packaging, max_units)
	if made > 0:
		Audio.play("package")
		Events.toast("Empaquetadas %d unidades." % (made * int(ItemDB.get_prop(packaging, "units", 1))), "info")
	else:
		Audio.play("error", -6.0)
		Events.toast("No hay suficiente producto para ese envase.", "warn")
