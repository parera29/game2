class_name ShopData
extends RefCounted
## Acceso a data/shops.json, horarios de apertura y precios con descuentos.

static var _shops: Dictionary = {}


static func all() -> Dictionary:
	if _shops.is_empty():
		var f := FileAccess.open("res://data/shops.json", FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_shops = parsed
		if _shops.is_empty():
			push_error("ShopData: no se pudo cargar shops.json")
	return _shops


static func get_shop(id: String) -> Dictionary:
	return all().get(id, {})


static func is_open(id: String) -> bool:
	var s := get_shop(id)
	if s.is_empty():
		return false
	return hours_contain(int(s.get("open", 0)), int(s.get("close", 24)), GameState.hour())


static func hours_contain(open_h: int, close_h: int, h: int) -> bool:
	if close_h > 24:
		return h >= open_h or h < close_h - 24
	return h >= open_h and h < close_h


static func hours_text(id: String) -> String:
	var s := get_shop(id)
	return "%02d:00 - %02d:00" % [int(s.get("open", 0)), int(s.get("close", 24)) % 24]


static func buy_price(item_id: String) -> int:
	return maxi(1, int(round(ItemDB.price(item_id) * RandomEvents.shop_discount())))


static func sell_price(shop_id: String, item_id: String) -> int:
	var s := get_shop(shop_id)
	var buys: Array = s.get("buys", [])
	if buys.is_empty() or ItemDB.is_contraband(item_id):
		return 0
	if not (buys.has("*") or buys.has(item_id)):
		return 0
	var explicit := int(ItemDB.get_prop(item_id, "sell", 0))
	if explicit > 0:
		return explicit
	if ItemDB.category(item_id) == "quest":
		return 0
	return int(floor(ItemDB.price(item_id) * float(s.get("buy_rate", 0.4))))
