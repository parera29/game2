extends Node
## Clientes: relaciones, pedidos por teléfono, negociación, entregas, muestras gratis
## y recomendaciones. Los cuerpos 3D de los clientes los gestiona el mundo (NPC),
## que consulta aquí su estado (p. ej. si tienen una cita pendiente).

const PATH := "res://data/customers.json"
const ORDER_EXPIRE_MIN := 120
const DEAL_WINDOW_MIN := 240
const MAX_OPEN_ORDERS := 4

const ORDER_LINES := [
	"Ey, ¿tienes algo? Necesito %d de %s. Te doy $%d.",
	"¿Estás libre? Me vendrían bien %d de %s. Pago $%d.",
	"Hola, busco %d de %s. ¿$%d te vale?",
	"Necesito %d de %s, urgente. Tengo $%d.",
]
const ACCEPT_LINES := ["Perfecto, nos vemos en %s.", "Genial. Te espero en %s.", "Hecho. Estaré en %s."]
const REJECT_LINES := ["Uf, eso es demasiado.", "Ni de broma, es muy caro.", "No puedo pagar eso."]
const QUIT_LINES := ["Olvídalo, ya buscaré a otro.", "Paso. Hablamos otro día.", "Déjalo, me lo pensaré."]
const THANKS_LINES := ["¡Gracias! Justo lo que necesitaba.", "Buen material. Repetiré.", "Un placer hacer negocios."]

var defs: Dictionary = {}
var state: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			defs = parsed
	if defs.is_empty():
		push_error("CustomerManager: no se pudieron cargar los clientes")
	Events.hour_passed.connect(_on_hour)
	Events.minute_passed.connect(_on_minute)
	reset()


func reset() -> void:
	state.clear()
	for id in defs:
		state[id] = {
			"unlocked": bool(defs[id].get("unlocked", false)),
			"relationship": 25 if defs[id].get("unlocked", false) else 0,
			"order": {}, "deal": {}, "rejections": 0, "messages": [],
			"cooldown_until": 0, "deals_done": 0, "last_seen_effects": [],
		}


# ------------------------------------------------------------------ Consultas

func name_of(id: String) -> String:
	return String(defs.get(id, {}).get("name", id))


func is_unlocked(id: String) -> bool:
	return state.has(id) and bool(state[id]["unlocked"])


func unlocked_count() -> int:
	var n := 0
	for id in state:
		if state[id]["unlocked"]:
			n += 1
	return n


func relationship(id: String) -> int:
	return int(state.get(id, {}).get("relationship", 0))


func relationship_label(id: String) -> String:
	var r := relationship(id)
	if r >= 80:
		return "Leal"
	if r >= 60:
		return "Amistosa"
	if r >= 40:
		return "Buena"
	if r >= 20:
		return "Neutral"
	return "Desconfiada"


func has_deal(id: String) -> bool:
	return state.has(id) and not (state[id]["deal"] as Dictionary).is_empty()


func get_deal(id: String) -> Dictionary:
	return state.get(id, {}).get("deal", {})


func get_order(id: String) -> Dictionary:
	return state.get(id, {}).get("order", {})


func open_orders() -> int:
	var n := 0
	for id in state:
		if not (state[id]["order"] as Dictionary).is_empty() or not (state[id]["deal"] as Dictionary).is_empty():
			n += 1
	return n


func market_mult(id: String, product: String) -> float:
	var d := String(defs[id]["district"])
	return RandomEvents.market_mult(d, product)


## Precio máximo por unidad que el cliente está dispuesto a pagar.
func max_willing(id: String, product: String) -> int:
	var d: Dictionary = defs[id]
	var base := float(ItemDB.PRODUCTS[product]["base_value"])
	var rel := float(relationship(id))
	var v := base * float(d["budget"]) * (0.95 + rel / 300.0) * market_mult(id, product) * 1.25
	return int(round(v))


func preferred_product(id: String) -> String:
	var prods: Array = defs[id].get("products", ["glimmer"])
	if prods.has("azure") and GameState.flags.get("azure_known", false):
		if prods.size() == 1 or _rng.randf() < 0.5:
			return "azure"
	if prods.has("glimmer"):
		return "glimmer"
	return "azure" if GameState.flags.get("azure_known", false) else ""


# ------------------------------------------------------------------ Mensajería

func add_message(id: String, from_me: bool, text: String) -> void:
	var msgs: Array = state[id]["messages"]
	msgs.append({"me": from_me, "text": text, "t": "%s %s" % [GameState.weekday_name().substr(0, 3), GameState.time_string()]})
	while msgs.size() > 40:
		msgs.pop_front()
	Events.messages_changed.emit(id)


func _on_hour(h: int, _day: int) -> void:
	if h < 8 or h > 22:
		return
	for id in state:
		var s: Dictionary = state[id]
		if not s["unlocked"] or not (s["order"] as Dictionary).is_empty() or not (s["deal"] as Dictionary).is_empty():
			continue
		if int(s["cooldown_until"]) > GameState.absolute_minute():
			continue
		if open_orders() >= MAX_OPEN_ORDERS:
			return
		if not GameState.is_district_unlocked(String(defs[id]["district"])):
			continue
		var chance := float(defs[id]["freq"]) * (1.0 + float(s["relationship"]) / 100.0)
		if _rng.randf() < chance:
			create_order(id)


func _on_minute(_m: int, _d: int) -> void:
	var now := GameState.absolute_minute()
	_check_forced_orders(now)
	for id in state:
		var s: Dictionary = state[id]
		var o: Dictionary = s["order"]
		if not o.is_empty() and now > int(o["created"]) + ORDER_EXPIRE_MIN:
			s["order"] = {}
			_change_rel(id, -2)
			add_message(id, false, "Bueno, da igual. Ya no lo necesito.")
		var dl: Dictionary = s["deal"]
		if not dl.is_empty() and now > int(dl["deadline"]):
			s["deal"] = {}
			_change_rel(id, -10)
			add_message(id, false, "Me has dejado plantado. No me hagas perder el tiempo.")
			Events.toast("%s se ha cansado de esperar." % name_of(id), "warn")
			Events.deal_cancelled.emit(id)


func force_order(id: String, delay_minutes: int = 0) -> void:
	if not state.has(id):
		return
	if delay_minutes <= 0:
		create_order(id, 2)
	else:
		GameState.flags["forced_order_" + id] = GameState.absolute_minute() + delay_minutes


func _check_forced_orders(now: int) -> void:
	for k in GameState.flags.keys():
		if not String(k).begins_with("forced_order_"):
			continue
		if now >= int(GameState.flags[k]):
			var id := String(k).substr(13)
			GameState.flags.erase(k)
			if state.has(id) and (state[id]["order"] as Dictionary).is_empty() and (state[id]["deal"] as Dictionary).is_empty():
				create_order(id, 2)


func create_order(id: String, fixed_qty: int = 0) -> void:
	var product := preferred_product(id)
	if product == "":
		return
	var s: Dictionary = state[id]
	var rel := float(s["relationship"])
	var qty := fixed_qty if fixed_qty > 0 else _rng.randi_range(1, 2 + int(rel / 30.0))
	var willing := max_willing(id, product)
	var listing := int(GameState.listing_prices.get(product, willing))
	var unit_price := mini(listing, willing)
	s["order"] = {"product": product, "qty": qty, "price": unit_price * qty, "created": GameState.absolute_minute()}
	s["rejections"] = 0
	var line: String = ORDER_LINES[_rng.randi() % ORDER_LINES.size()]
	add_message(id, false, line % [qty, ItemDB.PRODUCTS[product]["name"], unit_price * qty])
	Audio.play("notify")
	Events.toast("Mensaje de %s: quiere %d de %s ($%d)" % [name_of(id), qty, ItemDB.PRODUCTS[product]["name"], unit_price * qty], "phone")


## Aceptar el pedido tal cual.
func accept_order(id: String) -> bool:
	var o: Dictionary = state[id]["order"]
	if o.is_empty():
		return false
	add_message(id, true, "Trato hecho.")
	_schedule_deal(id, o)
	return true


## Aceptar un pedido hecho cara a cara: la entrega es inmediata, en el sitio.
func accept_order_here(id: String) -> bool:
	var o: Dictionary = state[id]["order"]
	if o.is_empty():
		return false
	_schedule_deal(id, o, true)
	return true


func counter_offer_here(id: String, total_price: int) -> String:
	return counter_offer(id, total_price, true)


## Contraoferta con un precio total distinto. Devuelve "accepted", "rejected" o "quit".
func counter_offer(id: String, total_price: int, here: bool = false) -> String:
	var s: Dictionary = state[id]
	var o: Dictionary = s["order"]
	if o.is_empty():
		return "quit"
	var qty := int(o["qty"])
	var per_unit := float(total_price) / float(qty)
	var willing := float(max_willing(id, String(o["product"])))
	add_message(id, true, "¿Qué tal $%d?" % total_price)
	var chance := 1.0
	if per_unit > willing:
		chance = clampf(1.0 - (per_unit / willing - 1.0) * 4.0, 0.0, 1.0)
	if total_price <= int(o["price"]):
		chance = 1.0
	if _rng.randf() <= chance:
		o["price"] = total_price
		_schedule_deal(id, o, here)
		return "accepted"
	s["rejections"] = int(s["rejections"]) + 1
	_change_rel(id, -1)
	if int(s["rejections"]) >= 2:
		add_message(id, false, QUIT_LINES[_rng.randi() % QUIT_LINES.size()])
		s["order"] = {}
		s["cooldown_until"] = GameState.absolute_minute() + 180
		return "quit"
	add_message(id, false, REJECT_LINES[_rng.randi() % REJECT_LINES.size()])
	return "rejected"


func decline_order(id: String) -> void:
	if (state[id]["order"] as Dictionary).is_empty():
		return
	add_message(id, true, "Ahora no puedo, lo siento.")
	add_message(id, false, "Vale, otra vez será.")
	state[id]["order"] = {}
	_change_rel(id, -2)
	state[id]["cooldown_until"] = GameState.absolute_minute() + 120


func _schedule_deal(id: String, o: Dictionary, here: bool = false) -> void:
	var s: Dictionary = state[id]
	var loc := {"id": "", "name": "aquí mismo"}
	if not here and GameState.world and GameState.world.has_method("get_meeting_point"):
		loc = GameState.world.get_meeting_point(String(defs[id]["district"]), id)
	s["deal"] = {
		"product": o["product"], "qty": o["qty"], "price": o["price"],
		"deadline": GameState.absolute_minute() + DEAL_WINDOW_MIN,
		"location": loc["id"], "location_name": loc["name"],
	}
	s["order"] = {}
	if not here:
		add_message(id, false, ACCEPT_LINES[_rng.randi() % ACCEPT_LINES.size()] % loc["name"])
		Events.toast("Entrega con %s en %s (tienes 4 h)" % [name_of(id), loc["name"]], "phone")
	Events.deal_scheduled.emit(id)


func cancel_deal(id: String) -> void:
	if not has_deal(id):
		return
	state[id]["deal"] = {}
	add_message(id, true, "Lo siento, no puedo ir.")
	add_message(id, false, "Qué decepción.")
	_change_rel(id, -6)
	Events.deal_cancelled.emit(id)


func minutes_left(id: String) -> int:
	if not has_deal(id):
		return 0
	return int(get_deal(id)["deadline"]) - GameState.absolute_minute()


# ------------------------------------------------------------------ Entregas

## Busca en el inventario pilas de producto empaquetado del tipo pedido.
func matching_stacks(product: String) -> Array:
	var out: Array = []
	var inv: Inventory = GameState.player_inventory
	for i in inv.size():
		var s = inv.get_slot(i)
		if s != null and ItemDB.is_packed_product(s["id"]) and ItemDB.product_type(s["id"]) == product:
			out.append(i)
	return out


func units_available(product: String) -> int:
	var total := 0
	for i in matching_stacks(product):
		var s = GameState.player_inventory.get_slot(i)
		total += int(s["qty"]) * ItemDB.units_of(s["id"])
	return total


## Completa la entrega usando producto del inventario. Devuelve un resumen o {} si falla.
func complete_deal(id: String, witnesses_pos: Vector3 = Vector3.ZERO) -> Dictionary:
	if not has_deal(id):
		return {}
	var dl: Dictionary = get_deal(id)
	var product := String(dl["product"])
	var need := int(dl["qty"])
	if units_available(product) < need:
		Events.toast("No llevas suficiente %s empaquetado (%d/%d)." % [ItemDB.PRODUCTS[product]["name"], units_available(product), need], "warn")
		Audio.play("error")
		return {}
	# Retira unidades: primero bolsitas, después tarros (sin partir tarros en exceso)
	var inv: Inventory = GameState.player_inventory
	var given_quality := 0.0
	var given_effects: Array = []
	var remaining := need
	var stacks := matching_stacks(product)
	stacks.sort_custom(func(a, b): return ItemDB.units_of(inv.get_slot(a)["id"]) < ItemDB.units_of(inv.get_slot(b)["id"]))
	var extra_units := 0
	for i in stacks:
		if remaining <= 0:
			break
		var s = inv.get_slot(i)
		if s == null:
			continue
		var u := ItemDB.units_of(s["id"])
		var take := mini(int(s["qty"]), int(ceil(float(remaining) / float(u))))
		var units := take * u
		given_quality += float(s["data"].get("quality", 0.5)) * mini(units, remaining)
		for e in s["data"].get("effects", []):
			if not given_effects.has(e):
				given_effects.append(e)
		inv.take_from_slot(i, take)
		if units > remaining:
			extra_units += units - remaining
		remaining -= units
	given_quality /= float(need)
	var d: Dictionary = defs[id]
	var matches := 0
	for e in given_effects:
		if (d["prefs"] as Array).has(e):
			matches += 1
	var standards := float(d["standards"])
	var satisfaction := 0.5 + (given_quality - standards) + 0.15 * matches
	var rel_delta := int(round((satisfaction - 0.5) * 20.0)) + 4
	var price := int(dl["price"])
	var tip := int(round(price * 0.1 * matches))
	if extra_units > 0:
		# Pagan algo extra por las unidades de más de un tarro
		tip += int(float(price) / float(need) * extra_units * 0.8)
	var total := price + tip
	GameState.add_cash(total, "sale")
	GameState.stat_add("deals", 1)
	GameState.stat_add("units_sold", need)
	_change_rel(id, rel_delta)
	state[id]["deal"] = {}
	state[id]["deals_done"] = int(state[id]["deals_done"]) + 1
	state[id]["last_seen_effects"] = given_effects
	var verdict: String = THANKS_LINES[_rng.randi() % THANKS_LINES.size()]
	if given_quality < standards - 0.1:
		verdict = "Esto es de bastante mala calidad... Espero algo mejor la próxima vez."
	elif matches > 0:
		verdict = "¡Me encanta el efecto! Toma algo extra."
	add_message(id, false, verdict)
	Audio.play("cash")
	Events.toast("+$%d (%s)" % [total, name_of(id)], "money")
	Events.deal_completed.emit(id, need, total)
	GameState.add_xp(8 + need * 5)
	Police.report_illegal_activity(witnesses_pos, 18.0, "venta")
	_check_referrals(id)
	return {"total": total, "tip": tip, "rel_delta": rel_delta, "verdict": verdict}


func _check_referrals(id: String) -> void:
	if relationship(id) < 55:
		return
	for other in defs:
		if String(defs[other].get("referrer", "")) == id and not is_unlocked(other):
			if not GameState.is_district_unlocked(String(defs[other]["district"])):
				continue
			unlock(other, 25)
			add_message(id, false, "Por cierto, le he hablado de ti a %s. Te escribirá." % name_of(other))
			add_message(other, false, "Hola, %s me ha dado tu número." % name_of(id))
			return


func unlock(id: String, rel: int = 30) -> void:
	if is_unlocked(id):
		return
	state[id]["unlocked"] = true
	state[id]["relationship"] = maxi(rel, int(state[id]["relationship"]))
	Audio.play("quest")
	Events.toast("Nuevo cliente: %s" % name_of(id), "quest")
	Events.customer_unlocked.emit(id)
	GameState.add_xp(15)


## Muestra gratis a un cliente potencial. Consume 1 bolsita del producto más valioso.
func give_sample(id: String) -> String:
	if is_unlocked(id):
		return "already"
	if int(state[id]["cooldown_until"]) > GameState.absolute_minute():
		return "cooldown"
	var inv: Inventory = GameState.player_inventory
	var best := -1
	var best_val := -1
	for i in inv.size():
		var s = inv.get_slot(i)
		if s != null and ItemDB.is_packed_product(s["id"]) and ItemDB.units_of(s["id"]) == 1:
			var v := ItemDB.unit_value(ItemDB.product_type(s["id"]), s["data"])
			if v > best_val:
				best_val = v
				best = i
	if best < 0:
		return "no_product"
	var slot: Dictionary = inv.get_slot(best)
	var q := float(slot["data"].get("quality", 0.5))
	var effects: Array = slot["data"].get("effects", [])
	inv.take_from_slot(best, 1)
	GameState.stat_add("samples_given", 1)
	var d: Dictionary = defs[id]
	var matches := 0
	for e in effects:
		if (d["prefs"] as Array).has(e):
			matches += 1
	var chance := 0.35 + (q - float(d["standards"])) * 1.5 + 0.2 * matches
	var ref := String(d.get("referrer", ""))
	if ref != "" and relationship(ref) >= 40:
		chance += 0.15
	chance = clampf(chance, 0.05, 0.95)
	Police.report_illegal_activity(GameState.player.global_position if GameState.player else Vector3.ZERO, 12.0, "muestra")
	if _rng.randf() < chance:
		unlock(id, 30)
		add_message(id, false, "Oye, eso estaba muy bien. Te escribiré cuando necesite más.")
		return "success"
	state[id]["cooldown_until"] = GameState.absolute_minute() + 1440
	return "fail"


func _change_rel(id: String, delta: int) -> void:
	state[id]["relationship"] = clampi(int(state[id]["relationship"]) + delta, 0, 100)


# ------------------------------------------------------------------ Persistencia

func to_dict() -> Dictionary:
	return state.duplicate(true)


func from_dict(d: Dictionary) -> void:
	reset()
	for id in d:
		if not state.has(id):
			continue
		var src: Dictionary = d[id]
		for k in state[id].keys():
			if src.has(k):
				state[id][k] = src[k]
		state[id]["relationship"] = int(state[id]["relationship"])
		state[id]["cooldown_until"] = int(state[id]["cooldown_until"])
