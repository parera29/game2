extends UIWindow
## Diálogos con NPC. Construye nodos de conversación según el rol y el estado
## (misiones, tienda, clientes, muestras, policía, empleados). Los NPC pueden
## rechazar hablar o abandonar la conversación.

const TIPS := {
	"marco": ["El ciclo es simple: tierra y esporas, plantar, regar, cosechar, empaquetar y vender.", "Nunca hagas tratos delante de la policía. Y vigila a los mirones.", "Guarda el dinero en el banco: si te detienen, solo pierdes el efectivo."],
	"rosa": ["¿Café? Invita la casa, cielo.", "Marco viene todos los días. Es buena gente... a su manera."],
	"tony": ["Este barrio es tranquilo, pero de noche salen los atracadores.", "Si alguien te ataca, empújalo con todas tus fuerzas."],
	"gloria": ["El alquiler de la habitación es de $40 al día, se cobra a las 7:00.", "Si no puedes pagar, perderás la habitación. Aviso."],
	"teller": ["Use el cajero automático para ingresar o retirar dinero.", "El dinero del banco está a salvo de... imprevistos."],
	"vince": ["En Downtown la gente paga más por productos con efectos.", "Una buena mezcla vale más que el doble de su peso."],
	"lena": ["El Azure se paga muy bien en Uptown y en Los Muelles.", "Sin laboratorio no hay Azure. Así de simple."],
	"hank": ["Las macetas con lámpara crecen mucho más rápido.", "La tierra premium da más cosecha y más calidad."],
	"ray": ["Esporas frescas, amigo. No preguntes de dónde salen.", "Los tarros salen más a cuenta si vendes al por mayor."],
	"sal": ["Compro casi cualquier cosa... legal, claro.", "¿Has visto mi reloj? Ah, no, olvídalo."],
	"clerk_gasmart": ["Las bebidas energéticas te dan alas. Bueno, piernas.", "Abrimos de 6:00 a medianoche."],
	"clerk_uptown": ["Tenemos lo último en tecnología de cultivo.", "Uptown no es para cualquiera."],
}
const PED_LINES := ["Bonito día, ¿verdad?", "Llego tarde al trabajo.", "¿Has visto qué precio tiene la gasolina?", "Dicen que la policía está muy activa últimamente.", "No soy de por aquí.", "Hoy hay partido, ¿lo sabías?"]
const PED_REFUSE := ["No hablo con desconocidos.", "Déjame en paz.", "Ahora no, tengo prisa."]

var npc: NPC
var _name: Label
var _text: RichTextLabel
var _opts: VBoxContainer
var _rng := RandomNumberGenerator.new()


func build() -> void:
	dim = false
	_rng.randomize()
	npc = payload.get("npc")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.BG, 14, Color(1, 1, 1, 0.08)))
	panel.custom_minimum_size = Vector2(760, 0)
	add_child(panel)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 18)
	panel.add_child(m)
	var v := VBoxContainer.new()
	m.add_child(v)
	_name = UITheme.label(npc.display_name, 22, UITheme.ACCENT)
	v.add_child(_name)
	_text = RichTextLabel.new()
	_text.fit_content = true
	_text.bbcode_enabled = true
	_text.custom_minimum_size = Vector2(720, 40)
	_text.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(_text)
	v.add_child(HSeparator.new())
	_opts = VBoxContainer.new()
	v.add_child(_opts)
	npc.begin_talk()
	Events.npc_talked.emit(npc.npc_id)
	_panel = panel
	_show(_root())


var _panel: PanelContainer


func _place_panel() -> void:
	if _panel == null:
		return
	var vs := get_viewport_rect().size
	_panel.reset_size()
	_panel.position = Vector2((vs.x - _panel.size.x) * 0.5, vs.y - _panel.size.y - 40.0)


func _exit_tree() -> void:
	if is_instance_valid(npc):
		npc.end_talk()


func _process(_d: float) -> void:
	_place_panel()
	if not is_instance_valid(npc) or (GameState.player and npc.global_position.distance_to(GameState.player.global_position) > 6.0):
		close()


func _show(node: Variant) -> void:
	if not (node is Dictionary) or (node as Dictionary).is_empty():
		close()
		return
	_text.text = String(node.get("text", ""))
	UITheme.clear(_opts)
	var i := 1
	for o in node.get("options", []):
		var cb: Callable = o["cb"]
		var b := UITheme.button("%d. %s" % [i, o["text"]], func() -> void: _show(cb.call()))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_opts.add_child(b)
		i += 1


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_1
			if idx < _opts.get_child_count():
				(_opts.get_child(idx) as Button).pressed.emit()
				get_viewport().set_input_as_handled()


func _end() -> Variant:
	return null


func _opt(text: String, cb: Callable) -> Dictionary:
	return {"text": text, "cb": cb}


func _back_to_root() -> Variant:
	return _root()


# ------------------------------------------------------------------ Nodos

func _root() -> Dictionary:
	var id := npc.npc_id
	if npc.is_angry():
		return {"text": "¡Aléjate de mí! ¡Ni se te ocurra volver a tocarme!", "options": [_opt("(Irse)", _end)]}
	var talk := Quests.pending_talk(id)
	if not talk.is_empty():
		return {"text": String(talk["line"]), "options": [_opt("Entendido.", func() -> Variant:
			Quests.complete_talk(id)
			npc.refresh_marker()
			return _root())]}
	match npc.role:
		"customer":
			return _customer_root()
		"police":
			return _police_root()
		"pedestrian":
			return _pedestrian_root()
		"employee":
			return _employee_root()
	return _generic_root()


func _generic_root() -> Dictionary:
	var id := npc.npc_id
	var options: Array = []
	var text := "¿Qué tal?"
	if npc.shop_id != "":
		var shop := ShopData.get_shop(npc.shop_id)
		text = "Bienvenido a %s. ¿Qué necesitas?" % shop.get("name", "la tienda")
		options.append(_opt("Quiero ver lo que tienes.", func() -> Variant:
			if not ShopData.is_open(npc.shop_id):
				return {"text": "Lo siento, estamos cerrados. Horario: %s." % ShopData.hours_text(npc.shop_id), "options": [_opt("Vale.", _back_to_root)]}
			var sid := npc.shop_id
			var mgr := ui
			mgr.call_deferred("open", "shop", {"shop": sid})
			return null))
	for d in Quests.pending_deliveries(id):
		var dd: Dictionary = d
		options.append(_opt("Entregar: %s x%d" % [ItemDB.display_name(dd["item"]), int(dd["count"])], func() -> Variant:
			if Quests.try_deliver(dd["quest"]):
				npc.refresh_marker()
				return {"text": "¡Perfecto! Muchas gracias. Aquí tienes lo prometido.", "options": [_opt("Un placer.", _back_to_root)]}
			return {"text": "Todavía no tienes lo que te pedí.", "options": [_opt("Vale.", _back_to_root)]}))
	for q in Quests.offers_for(id):
		var qid: String = q
		options.append(_opt("¿Tienes algún trabajo para mí?", func() -> Variant:
			return {"text": String(Quests.defs[qid].get("offer", "Tengo algo para ti.")), "options": [
				_opt("Acepto.", func() -> Variant:
					Quests.start(qid)
					npc.refresh_marker()
					return {"text": "Genial. Cuento contigo.", "options": [_opt("Hasta luego.", _end)]}),
				_opt("Ahora no.", _back_to_root)]}))
	if TIPS.has(id):
		options.append(_opt("¿Algún consejo?", func() -> Variant:
			var tips: Array = TIPS[id]
			return {"text": String(tips[_rng.randi() % tips.size()]), "options": [_opt("Gracias.", _back_to_root)]}))
		if text == "¿Qué tal?":
			text = String(TIPS[id][0])
	if id == "gloria":
		text = "Recepción del Motel Sunset. Tu habitación es la número 4."
		options.append(_opt("¿Cuánto debo de alquiler?", func() -> Variant:
			var st := "al día" if Business.properties["motel_room"]["rented"] else "(ya no la tienes alquilada)"
			return {"text": "Son $40 %s, se cobran a las 7:00. Gastos diarios totales: $%d." % [st, Business.daily_cost()], "options": [_opt("Entendido.", _back_to_root)]}))
		if not Business.has_access("motel_room"):
			options.append(_opt("Quiero volver a alquilar la habitación ($40).", func() -> Variant:
				if GameState.spend(40):
					Business.properties["motel_room"]["rented"] = true
					Events.property_state_changed.emit("motel_room")
					return {"text": "Aquí tienes la llave. Habitación 4.", "options": [_opt("Gracias.", _back_to_root)]}
				return {"text": "No te llega el dinero, cariño.", "options": [_opt("Vaya.", _back_to_root)]}))
	options.append(_opt("Adiós.", _end))
	return {"text": text, "options": options}


func _customer_root() -> Dictionary:
	var id := npc.npc_id
	var d: Dictionary = Customers.defs[id]
	if not Customers.is_unlocked(id):
		if not GameState.is_district_unlocked(String(d["district"])):
			return {"text": "No te conozco.", "options": [_opt("Adiós.", _end)]}
		return {"text": "¿Nos conocemos? No sé quién eres.", "options": [
			_opt("Te ofrezco una muestra gratis (1 bolsita).", _give_sample),
			_opt("Nada, perdona.", _end)]}
	if Customers.has_deal(id):
		var dl := Customers.get_deal(id)
		var pname: String = ItemDB.PRODUCTS[dl["product"]]["name"]
		return {"text": "¿Traes lo mío? Quedamos en %d de %s por %s." % [int(dl["qty"]), pname, UITheme.money(int(dl["price"]))], "options": [
			_opt("Aquí tienes. (Entregar %d de %s)" % [int(dl["qty"]), pname], _complete_deal),
			_opt("Todavía no lo tengo.", func() -> Variant: return {"text": "Pues date prisa. Te quedan %d minutos." % Customers.minutes_left(id), "options": [_opt("Voy.", _end)]}),
			_opt("Cancelar el trato.", func() -> Variant:
				Customers.cancel_deal(id)
				return {"text": "¿En serio? Qué decepción.", "options": [_opt("Lo siento.", _end)]})]}
	var h := GameState.hour()
	if h >= 23 or h < 6:
		return {"text": "Es muy tarde. Déjame en paz.", "options": [_opt("Perdona.", _end)]}
	var prefs: Array = []
	for e in d["prefs"]:
		prefs.append(ItemDB.EFFECTS[e]["name"])
	var rel := Customers.relationship(id)
	var greet := "¡Hombre, tú por aquí!" if rel >= 60 else ("Hola." if rel >= 30 else "Ah... eres tú.")
	return {"text": "%s  [color=#9aa]Relación: %s (%d) · Le gusta: %s[/color]" % [greet, Customers.relationship_label(id), rel, ", ".join(prefs)], "options": [
		_opt("¿Te interesa comprar algo ahora?", _direct_offer),
		_opt("Adiós.", _end)]}


func _direct_offer() -> Variant:
	var id := npc.npc_id
	if not Customers.get_order(id).is_empty():
		return {"text": "Ya te he escrito con lo que quiero. Mira el teléfono.", "options": [_opt("Vale.", _end)]}
	if int(Customers.state[id]["cooldown_until"]) > GameState.absolute_minute() or _rng.randf() < 0.25:
		return {"text": "Ahora no, gracias. Ya te escribiré.", "options": [_opt("Como quieras.", _end)]}
	var product := Customers.preferred_product(id)
	if product == "":
		return {"text": "No me interesa lo que tienes.", "options": [_opt("Vale.", _end)]}
	Customers.create_order(id)
	var o := Customers.get_order(id)
	return _order_node(o)


func _order_node(o: Dictionary) -> Dictionary:
	var id := npc.npc_id
	var pname: String = ItemDB.PRODUCTS[o["product"]]["name"]
	var price := int(o["price"])
	return {"text": "Vale, quiero %d de %s. Te doy %s." % [int(o["qty"]), pname, UITheme.money(price)], "options": [
		_opt("Trato hecho.", func() -> Variant:
			Customers.accept_order_here(id)
			return _customer_root()),
		_opt("Pide %s (+15%%)" % UITheme.money(int(price * 1.15)), func() -> Variant: return _counter(int(price * 1.15))),
		_opt("Pide %s (+30%%)" % UITheme.money(int(price * 1.3)), func() -> Variant: return _counter(int(price * 1.3))),
		_opt("Mejor no.", func() -> Variant:
			Customers.decline_order(id)
			return {"text": "Vale, otra vez será.", "options": [_opt("Adiós.", _end)]})]}


func _counter(total: int) -> Variant:
	var id := npc.npc_id
	var r := Customers.counter_offer_here(id, total)
	match r:
		"accepted":
			return {"text": "Bueno... vale, %s. Pero que sea bueno." % UITheme.money(total), "options": [_opt("Aquí lo tienes.", _complete_deal), _opt("Ahora vuelvo con ello.", _end)]}
		"rejected":
			var o := Customers.get_order(id)
			var n := _order_node(o)
			n["text"] = "Ni hablar, es demasiado. Mi oferta sigue siendo %s." % UITheme.money(int(o["price"]))
			return n
	return {"text": "¿Sabes qué? Olvídalo. Ya buscaré a otro.", "options": [_opt("(Se marcha)", _end)]}


func _complete_deal() -> Variant:
	var id := npc.npc_id
	var res := Customers.complete_deal(id, npc.global_position)
	if res.is_empty():
		return {"text": "¿Me tomas el pelo? No traes lo que acordamos. Necesito producto empaquetado.", "options": [_opt("Ahora vuelvo.", _end)]}
	npc.leave_after_deal()
	var tip := " (+%s de propina)" % UITheme.money(int(res["tip"])) if int(res["tip"]) > 0 else ""
	return {"text": "%s\n[color=#7f7]Cobras %s%s[/color]" % [res["verdict"], UITheme.money(int(res["total"])), tip], "options": [_opt("Un placer.", _end)]}


func _give_sample() -> Variant:
	var id := npc.npc_id
	match Customers.give_sample(id):
		"success":
			npc.refresh_marker()
			return {"text": "¡Vaya! Esto está muy bien. Toma mi número, te escribiré.", "options": [_opt("Perfecto.", _end)]}
		"fail":
			return {"text": "Mmm... no, no es para mí. Quizá con algo de más calidad o con otro efecto.", "options": [_opt("Otra vez será.", _end)]}
		"no_product":
			return {"text": "¿Qué me vas a dar, aire? (Necesitas al menos una bolsita de producto)", "options": [_opt("Vaya.", _end)]}
		"cooldown":
			return {"text": "Ya te dije que no. Vuelve mañana.", "options": [_opt("Vale.", _end)]}
	return {"text": "Ya somos socios, ¿no?", "options": [_opt("Cierto.", _end)]}


func _police_root() -> Dictionary:
	if Police.wanted == Police.Wanted.INVESTIGATING:
		return {"text": "Precisamente quería hablar con usted. Registro rutinario. No se mueva.", "options": [
			_opt("(Cooperar)", func() -> Variant:
				Police.begin_search(npc)
				npc.state = "searching"
				return null),
			_opt("(Salir corriendo)", func() -> Variant:
				Police.player_resisted()
				return null)]}
	var lines := ["Circule, ciudadano.", "Todo en orden por aquí.", "Recuerde que hay toque de queda de 22:00 a 05:00."]
	if Police.is_crackdown():
		lines = ["Estamos en pleno operativo. No me haga perder el tiempo."]
	return {"text": lines[_rng.randi() % lines.size()], "options": [_opt("Buenas, agente.", _end)]}


func _pedestrian_root() -> Dictionary:
	if _rng.randf() < 0.25 or GameState.is_night():
		return {"text": PED_REFUSE[_rng.randi() % PED_REFUSE.size()], "options": [_opt("(Irse)", _end)]}
	return {"text": PED_LINES[_rng.randi() % PED_LINES.size()], "options": [_opt("Sí, claro.", _end)]}


func _employee_root() -> Dictionary:
	var id := npc.npc_id
	var e: Dictionary = {}
	for x in Business.employees:
		if x["id"] == id:
			e = x
	if e.is_empty():
		return {"text": "...", "options": [_opt("Adiós.", _end)]}
	return {"text": "%s (%s) · Salario: %s/día\nEstado: %s\n[color=#9aa]%s[/color]" % [e["name"], Business.ROLE_NAMES[e["role"]], UITheme.money(int(e["wage"])), e.get("status", "-"), Business.ROLE_DESC[e["role"]]], "options": [
		_opt("Sigue así.", _end),
		_opt("Estás despedido.", func() -> Variant:
			Business.fire(id)
			return {"text": "¿Qué? Bueno... tú te lo pierdes.", "options": [_opt("Adiós.", _end)]})]}
