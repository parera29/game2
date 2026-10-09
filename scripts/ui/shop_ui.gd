extends UIWindow
## Tienda: catálogo con precios (y bloqueos por rango), compra por cantidad
## y, si la tienda compra objetos, pestaña de venta.

var shop_id := ""
var _list: VBoxContainer
var _sell_list: VBoxContainer
var _cash: Label
var _weight: Label


func build() -> void:
	shop_id = String(payload.get("shop", ""))
	var shop := ShopData.get_shop(shop_id)
	var body := make_window(Vector2(760, 600), String(shop.get("name", "Tienda")))
	var info := HBoxContainer.new()
	body.add_child(info)
	_cash = UITheme.label("", 20, UITheme.MONEY)
	_cash.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_cash)
	_weight = UITheme.label("", 15, UITheme.TEXT_DIM)
	info.add_child(_weight)
	if RandomEvents.shop_discount() < 1.0:
		body.add_child(UITheme.label("¡Rebajas! Todo un 25% más barato.", 15, UITheme.WARN))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(720, 440)
	body.add_child(tabs)
	var buy_scroll := ScrollContainer.new()
	buy_scroll.name = "Comprar"
	tabs.add_child(buy_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.add_child(_list)
	if not (shop.get("buys", []) as Array).is_empty():
		var sell_scroll := ScrollContainer.new()
		sell_scroll.name = "Vender"
		tabs.add_child(sell_scroll)
		_sell_list = VBoxContainer.new()
		_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell_scroll.add_child(_sell_list)
	GameState.player_inventory.changed.connect(_refresh)
	Events.money_changed.connect(func(_c: int, _b: int) -> void: _refresh_header())
	_refresh()


func _refresh_header() -> void:
	_cash.text = "Efectivo: %s" % UITheme.money(GameState.cash)
	var inv: Inventory = GameState.player_inventory
	_weight.text = "Carga: %.1f / %.0f kg" % [inv.total_weight(), inv.max_weight]


func _refresh() -> void:
	_refresh_header()
	UITheme.clear(_list)
	var shop := ShopData.get_shop(shop_id)
	for id in shop.get("items", []):
		_list.add_child(_buy_row(String(id)))
	if _sell_list:
		UITheme.clear(_sell_list)
		var seen := {}
		var any := false
		for s in GameState.player_inventory.slots:
			if s == null or seen.has(s["id"]):
				continue
			seen[s["id"]] = true
			var price := ShopData.sell_price(shop_id, s["id"])
			if price > 0:
				_sell_list.add_child(_sell_row(String(s["id"]), price))
				any = true
		if not any:
			_sell_list.add_child(UITheme.label("No llevas nada que esta tienda quiera comprar.\n(No se aceptan productos ilegales.)", 15, UITheme.TEXT_DIM))


func _row_base(id: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(680, 56)
	var icon := TextureRect.new()
	icon.texture = ItemDB.get_icon(id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UITheme.label(ItemDB.display_name(id), 17, UITheme.TEXT))
	var d := UITheme.label(String(ItemDB.get_prop(id, "desc", "")), 13, UITheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(360, 0)
	v.add_child(d)
	return h


func _buy_row(id: String) -> Control:
	var h := _row_base(id)
	var price := ShopData.buy_price(id)
	var req_rank := int(ItemDB.get_prop(id, "rank", 0))
	var locked := GameState.rank < req_rank
	var owned := GameState.player_inventory.count(id)
	h.add_child(UITheme.label("(tienes %d)" % owned, 13, UITheme.TEXT_DIM))
	h.add_child(UITheme.label(UITheme.money(price), 18, UITheme.MONEY))
	if locked:
		h.add_child(UITheme.label("Bloqueado · rango %s" % GameState.rank_name(req_rank), 14, UITheme.DANGER))
		return h
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = maxi(1, ItemDB.max_stack(id))
	spin.value = 1
	spin.custom_minimum_size = Vector2(90, 0)
	h.add_child(spin)
	h.add_child(UITheme.button("Comprar", func() -> void: _buy(id, int(spin.value)), 110))
	return h


func _sell_row(id: String, price: int) -> Control:
	var h := _row_base(id)
	var have := GameState.player_inventory.count(id)
	h.add_child(UITheme.label("x%d" % have, 15, UITheme.TEXT))
	h.add_child(UITheme.label(UITheme.money(price) + " c/u", 17, UITheme.MONEY))
	h.add_child(UITheme.button("Vender 1", func() -> void: _sell(id, 1), 100))
	h.add_child(UITheme.button("Vender todo", func() -> void: _sell(id, GameState.player_inventory.count(id)), 120))
	return h


func _buy(id: String, qty: int) -> void:
	if not ShopData.is_open(shop_id):
		Events.toast("La tienda está cerrada.", "warn")
		return
	var inv: Inventory = GameState.player_inventory
	var data := {}
	if id == "watering_can":
		data = {"water": 0}
	var fit := inv.can_add(id, qty, data)
	if fit <= 0:
		Audio.play("error")
		Events.toast("No tienes espacio o vas demasiado cargado.", "warn")
		return
	qty = mini(qty, fit)
	var total := ShopData.buy_price(id) * qty
	if not GameState.spend(total, "shop"):
		return
	inv.add(id, qty, data)
	GameState.stat_add("items_bought", qty)
	Audio.play("cash", -4.0)
	Events.toast("Comprado: %s x%d (-%s)" % [ItemDB.display_name(id), qty, UITheme.money(total)], "money")
	Events.item_bought.emit(id, qty)
	_refresh()


func _sell(id: String, qty: int) -> void:
	var price := ShopData.sell_price(shop_id, id)
	if price <= 0 or qty <= 0:
		return
	if not GameState.player_inventory.remove(id, qty):
		return
	GameState.add_cash(price * qty)
	Audio.play("cash", -4.0)
	Events.toast("Vendido: %s x%d (+%s)" % [ItemDB.display_name(id), qty, UITheme.money(price * qty)], "money")
	Events.item_sold.emit(id, qty, price * qty)
	_refresh()
