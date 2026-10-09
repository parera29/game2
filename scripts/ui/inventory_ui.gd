extends UIWindow
## Inventario del jugador y, opcionalmente, un contenedor (estantería) al lado.
## Arrastrar y soltar entre casillas, Mayús+clic para transferir, clic derecho para usar.

var _player_slots: Array = []
var _cont_slots: Array = []
var _container: Inventory = null
var _detail_name: Label
var _detail_desc: Label
var _weight_bar: ProgressBar
var _weight_label: Label
var _sel_inv: Inventory
var _sel_index := -1


func build() -> void:
	var title := "Inventario"
	if payload is Dictionary and payload.has("inventory"):
		_container = payload["inventory"]
		title = "Inventario · %s" % String(payload.get("title", "Contenedor"))
	var body := make_window(Vector2(1080 if _container else 640, 520), title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	body.add_child(row)
	# Jugador
	var left := VBoxContainer.new()
	row.add_child(left)
	left.add_child(UITheme.label("Barra rápida (1-8) y mochila", 15, UITheme.TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var inv: Inventory = GameState.player_inventory
	for i in inv.size():
		var s := ItemSlot.new()
		s.setup(inv, i, 64, str(i + 1) if i < GameState.HOTBAR_SIZE else "")
		_connect_slot(s)
		grid.add_child(s)
		_player_slots.append(s)
	var wrow := HBoxContainer.new()
	left.add_child(wrow)
	_weight_label = UITheme.label("", 14, UITheme.TEXT_DIM)
	wrow.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.custom_minimum_size = Vector2(240, 10)
	_weight_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weight_bar.show_percentage = false
	wrow.add_child(_weight_bar)
	wrow.add_child(UITheme.label("   Efectivo: %s" % UITheme.money(GameState.cash), 15, UITheme.MONEY))
	# Contenedor
	if _container:
		var right := VBoxContainer.new()
		row.add_child(right)
		right.add_child(UITheme.label(String(payload.get("title", "Contenedor")) + "  (Mayús+clic para transferir)", 15, UITheme.TEXT_DIM))
		var cg := GridContainer.new()
		cg.columns = 5
		cg.add_theme_constant_override("h_separation", 6)
		cg.add_theme_constant_override("v_separation", 6)
		right.add_child(cg)
		for i in _container.size():
			var s2 := ItemSlot.new()
			s2.setup(_container, i, 64)
			_connect_slot(s2)
			cg.add_child(s2)
			_cont_slots.append(s2)
		var brow := HBoxContainer.new()
		right.add_child(brow)
		brow.add_child(UITheme.button("Guardar todo el producto", _store_products))
		brow.add_child(UITheme.button("Coger todo", _take_all))
		_container.changed.connect(_refresh)
	# Detalle
	var det := PanelContainer.new()
	det.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG_LIGHT, 8))
	det.custom_minimum_size = Vector2(0, 120)
	body.add_child(det)
	var dv := VBoxContainer.new()
	det.add_child(dv)
	_detail_name = UITheme.label("Pasa el ratón sobre un objeto", 18, UITheme.ACCENT)
	dv.add_child(_detail_name)
	_detail_desc = UITheme.label("Arrastra para mover · Ctrl+arrastrar: mitad de la pila · Clic derecho: usar", 14, UITheme.TEXT_DIM)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_detail_desc)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	actions.add_child(UITheme.button("Usar / equipar", _use_selected))
	actions.add_child(UITheme.button("Soltar 1", func() -> void: _drop_selected(false)))
	actions.add_child(UITheme.button("Soltar pila", func() -> void: _drop_selected(true)))
	inv.changed.connect(_refresh)
	_refresh()


func _connect_slot(s: ItemSlot) -> void:
	s.hovered.connect(_on_hover)
	s.quick_transfer.connect(_on_quick)
	s.use_requested.connect(func(sl: ItemSlot) -> void:
		_on_hover(sl)
		_use_selected())


func _on_hover(s: ItemSlot) -> void:
	_sel_inv = s.inv
	_sel_index = s.index
	var it = s.get_item()
	if it == null:
		_detail_name.text = "Casilla vacía"
		_detail_desc.text = ""
		return
	_detail_name.text = "%s  x%d   (%s)" % [ItemDB.display_name(it["id"], it["data"]), int(it["qty"]), ItemDB.CATEGORY_NAMES.get(ItemDB.category(it["id"]), "")]
	_detail_desc.text = ItemDB.describe(it["id"], it["data"])


func _on_quick(s: ItemSlot) -> void:
	if _container == null:
		return
	var target: Inventory = _container if s.inv == GameState.player_inventory else GameState.player_inventory
	var moved := s.inv.quick_transfer(s.index, target)
	if moved > 0:
		Audio.play("pickup", -10.0)
	else:
		Audio.play("error", -8.0)


func _store_products() -> void:
	var inv: Inventory = GameState.player_inventory
	for i in inv.size():
		var s = inv.get_slot(i)
		if s != null and (ItemDB.is_product(s["id"]) or ItemDB.category(s["id"]) in ["supply", "packaging", "additive"]):
			inv.quick_transfer(i, _container)
	Audio.play("pickup", -8.0)


func _take_all() -> void:
	for i in _container.size():
		if _container.get_slot(i) != null:
			_container.quick_transfer(i, GameState.player_inventory)
	Audio.play("pickup", -8.0)


func _use_selected() -> void:
	if _sel_inv != GameState.player_inventory or _sel_index < 0:
		return
	var s = _sel_inv.get_slot(_sel_index)
	if s == null:
		return
	var p := GameState.player
	if p == null:
		return
	var prev: int = p.hotbar_index
	if _sel_index < GameState.HOTBAR_SIZE:
		p.hotbar_index = _sel_index
		p.use_held()
		p.hotbar_index = prev
	else:
		# Para usar desde la mochila se intercambia temporalmente con la casilla activa
		var cat := ItemDB.category(s["id"])
		if cat in ["consumable", "equipment"]:
			_sel_inv.move_slot(_sel_index, _sel_inv, prev)
			p.use_held()
		else:
			Events.toast("Este objeto se usa desde la barra rápida o sobre una estación.", "info")


func _drop_selected(all: bool) -> void:
	if _sel_inv != GameState.player_inventory or _sel_index < 0:
		return
	var p := GameState.player
	if p == null:
		return
	var prev: int = p.hotbar_index
	p.hotbar_index = _sel_index
	p.drop_held(all)
	p.hotbar_index = prev


func _refresh() -> void:
	for s in _player_slots:
		(s as ItemSlot).refresh()
	for s in _cont_slots:
		(s as ItemSlot).refresh()
	var inv: Inventory = GameState.player_inventory
	_weight_label.text = "Peso: %.1f / %.0f kg" % [inv.total_weight(), inv.max_weight]
	_weight_bar.max_value = inv.max_weight
	_weight_bar.value = inv.total_weight()
