extends Node
## Eventos aleatorios y mercado: fluctuación diaria de precios por distrito,
## auge de demanda, operativos policiales, rebajas, atracadores y pedidos urgentes.

var market: Dictionary = {}          # "district:product" -> multiplicador diario
var active_events: Array = []        # [{"type", "title", "desc", "until", "district"}]
var news: Array = []                 # titulares recientes
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Events.day_started.connect(func(_d): _roll_market())
	Events.hour_passed.connect(_on_hour)
	reset()


func reset() -> void:
	active_events.clear()
	news.clear()
	_roll_market()


func _roll_market() -> void:
	for d in GameState.DISTRICTS:
		for p in ItemDB.PRODUCTS:
			market["%s:%s" % [d, p]] = snappedf(_rng.randf_range(0.88, 1.15), 0.01)


func market_mult(district: String, product: String) -> float:
	var m := float(market.get("%s:%s" % [district, product], 1.0))
	for e in active_events:
		if e["type"] == "boom" and e["district"] == district:
			m *= 1.35
	return m


func shop_discount() -> float:
	for e in active_events:
		if e["type"] == "sale":
			return 0.75
	return 1.0


func _add_event(type: String, title: String, desc: String, hours: int, district: String = "") -> void:
	active_events.append({"type": type, "title": title, "desc": desc, "until": GameState.absolute_minute() + hours * 60, "district": district})
	news.push_front("%s %s - %s" % [GameState.weekday_name().substr(0, 3), GameState.time_string(), title])
	while news.size() > 12:
		news.pop_back()
	Audio.play("notify")
	Events.toast("Noticias: %s" % title, "phone")


func _on_hour(h: int, _d: int) -> void:
	var now := GameState.absolute_minute()
	for e in active_events.duplicate():
		if int(e["until"]) <= now:
			active_events.erase(e)
	if GameState.world == null:
		return
	# Atracador nocturno (solo si el jugador está en la calle)
	if (h >= 22 or h <= 3) and _rng.randf() < 0.12 and GameState.player and not GameState.player.get("is_indoors"):
		GameState.world.spawn_mugger()
		return
	if _rng.randf() > 0.18:
		return
	var roll := _rng.randi() % 4
	match roll:
		0:
			var opts: Array = GameState.unlocked_districts.duplicate()
			var d: String = opts[_rng.randi() % opts.size()]
			_add_event("boom", "Fiesta en %s: la demanda se dispara" % GameState.DISTRICTS[d]["name"],
				"Los clientes de %s pagan un 35%% más durante 12 h." % GameState.DISTRICTS[d]["name"], 12, d)
		1:
			Police.crackdown_until = maxi(Police.crackdown_until, now + 6 * 60)
			_add_event("crackdown", "Operativo policial en la ciudad",
				"Durante 6 h la sospecha aumenta más rápido y hay más patrullas.", 6)
			GameState.world.spawn_reinforcements(Vector3.ZERO)
		2:
			_add_event("sale", "Rebajas en las tiendas de Redmont", "Todo un 25% más barato durante 8 h.", 8)
		3:
			var candidates: Array = []
			for id in Customers.state:
				if Customers.is_unlocked(id) and Customers.get_order(id).is_empty() and not Customers.has_deal(id):
					candidates.append(id)
			if candidates.size() > 0 and h >= 9 and h <= 20:
				var c: String = candidates[_rng.randi() % candidates.size()]
				Customers.create_order(c)
				var o := Customers.get_order(c)
				o["price"] = int(int(o["price"]) * 1.5)
				Customers.add_message(c, false, "¡Es urgente! Te pago $%d si vienes rápido." % int(o["price"]))


func to_dict() -> Dictionary:
	return {"market": market.duplicate(), "events": active_events.duplicate(true), "news": news.duplicate()}


func from_dict(d: Dictionary) -> void:
	reset()
	var m: Dictionary = d.get("market", {})
	for k in m:
		market[k] = float(m[k])
	for e in d.get("events", []):
		if e is Dictionary:
			e["until"] = int(e.get("until", 0))
			active_events.append(e)
	for n in d.get("news", []):
		news.append(String(n))
