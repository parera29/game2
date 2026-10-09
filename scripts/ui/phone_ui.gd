extends UIWindow
## Teléfono virtual: mensajes y pedidos de clientes, contactos, mapa, misiones,
## precios de productos, propiedades, empleados, estadísticas y noticias.

const APPS := [
	["messages", "Mensajes", "MSG", Color(0.3, 0.75, 0.4)],
	["contacts", "Clientes", "CLI", Color(0.35, 0.55, 0.95)],
	["map", "Mapa", "MAP", Color(0.9, 0.6, 0.25)],
	["quests", "Misiones", "MIS", Color(0.95, 0.8, 0.25)],
	["products", "Productos", "PRD", Color(0.55, 0.85, 0.35)],
	["business", "Propiedades", "PRO", Color(0.7, 0.45, 0.9)],
	["staff", "Empleados", "EMP", Color(0.9, 0.4, 0.5)],
	["stats", "Estadísticas", "EST", Color(0.4, 0.8, 0.85)],
	["news", "Noticias", "NOT", Color(0.85, 0.85, 0.85)],
]

var _screen: VBoxContainer
var _header: Label
var _status: Label
var _page := "home"
var _conv := ""


func build() -> void:
	dim = false
	var phone := PanelContainer.new()
	var frame := UITheme.panel_style(Color(0.04, 0.04, 0.05, 0.98), 28, Color(0.3, 0.32, 0.35))
	frame.set_border_width_all(3)
	frame.content_margin_left = 12
	frame.content_margin_right = 12
	frame.content_margin_top = 14
	frame.content_margin_bottom = 14
	phone.add_theme_stylebox_override("panel", frame)
	phone.custom_minimum_size = Vector2(440, 740)
	add_child(phone)
	_phone = phone
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.09, 0.1, 0.13, 1.0), 18, Color(0, 0, 0, 0)))
	phone.add_child(inner)
	var v := VBoxContainer.new()
	inner.add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	_status = UITheme.label("", 14, UITheme.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status)
	bar.add_child(UITheme.button("Inicio", func() -> void: _go("home"), 70))
	bar.add_child(UITheme.button("✕", close, 36))
	_header = UITheme.label("", 22, UITheme.ACCENT)
	v.add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_screen = VBoxContainer.new()
	_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_screen)
	Events.messages_changed.connect(func(_c: String) -> void: _refresh())
	Events.employees_changed.connect(_refresh)
	Events.property_state_changed.connect(func(_p: String) -> void: _refresh())
	var start := "home"
	if payload is Dictionary and payload.has("app"):
		start = String(payload["app"])
	_go(start)
	Audio.play("click", -6.0)


var _phone: PanelContainer


func _process(_d: float) -> void:
	var vs := get_viewport_rect().size
	_phone.position = Vector2(vs.x - _phone.size.x - 30.0, maxf(10.0, vs.y - _phone.size.y - 30.0))
	_status.text = "%s %s   %s" % [GameState.weekday_name().substr(0, 3), GameState.time_string(), UITheme.money(GameState.cash)]


func _go(page: String, conv: String = "") -> void:
	_page = page
	_conv = conv
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	UITheme.clear(_screen)
	match _page:
		"home": _home()
		"messages": _messages()
		"conversation": _conversation()
		"contacts": _contacts()
		"map": _map()
		"quests": _quests()
		"products": _products()
		"business": _business()
		"staff": _staff()
		"stats": _stats()
		"news": _news()


func _lbl(t: String, sz: int = 15, col: Color = UITheme.TEXT) -> Label:
	var l := UITheme.label(t, sz, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	return l


func _card() -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.14, 0.16, 0.2), 10, Color(1, 1, 1, 0.05)))
	_screen.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


# ------------------------------------------------------------------ Inicio

func _home() -> void:
	_header.text = "Redmont OS"
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_screen.add_child(grid)
	for a in APPS:
		var id: String = a[0]
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 100)
		var badge := _badge(id)
		b.text = "%s\n%s%s" % [a[2], a[1], ("  (%d)" % badge) if badge > 0 else ""]
		var sb := UITheme.panel_style((a[3] as Color).darkened(0.45), 16, (a[3] as Color).darkened(0.1))
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", UITheme.panel_style((a[3] as Color).darkened(0.25), 16, a[3]))
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func() -> void:
			Audio.play("click", -4.0)
			_go(id))
		grid.add_child(b)
	var deals := 0
	for id in Customers.state:
		if Customers.has_deal(id):
			deals += 1
	_screen.add_child(_lbl("\nEntregas activas: %d · Gastos diarios: %s" % [deals, UITheme.money(Business.daily_cost())], 14, UITheme.TEXT_DIM))
	_screen.add_child(_lbl("Sospecha policial: %d%%%s" % [int(Police.suspicion), "  (operativo activo)" if Police.is_crackdown() else ""], 14, UITheme.POLICE))


func _badge(app: String) -> int:
	if app == "messages":
		var n := 0
		for id in Customers.state:
			if not Customers.get_order(id).is_empty():
				n += 1
		return n
	if app == "news":
		return RandomEvents.active_events.size()
	return 0


# ------------------------------------------------------------------ Mensajes

func _messages() -> void:
	_header.text = "Mensajes"
	var ids: Array = []
	for id in Customers.state:
		if Customers.is_unlocked(id):
			ids.append(id)
	ids.sort_custom(func(a, b) -> bool:
		var pa := 0 if not Customers.get_order(a).is_empty() else (1 if Customers.has_deal(a) else 2)
		var pb := 0 if not Customers.get_order(b).is_empty() else (1 if Customers.has_deal(b) else 2)
		return pa < pb)
	if ids.is_empty():
		_screen.add_child(_lbl("Aún no tienes clientes.", 15, UITheme.TEXT_DIM))
	for id in ids:
		var cid: String = id
		var msgs: Array = Customers.state[cid]["messages"]
		var last := String(msgs[-1]["text"]) if msgs.size() > 0 else "(sin mensajes)"
		var tag := ""
		if not Customers.get_order(cid).is_empty():
			tag = "  [PEDIDO]"
		elif Customers.has_deal(cid):
			tag = "  [ENTREGA]"
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(390, 58)
		b.clip_text = true
		b.text = "%s%s\n%s" % [Customers.name_of(cid), tag, last.substr(0, 48)]
		if tag != "":
			b.add_theme_color_override("font_color", UITheme.WARN if tag == "  [PEDIDO]" else UITheme.MONEY)
		b.pressed.connect(func() -> void: _go("conversation", cid))
		_screen.add_child(b)


func _conversation() -> void:
	var id := _conv
	_header.text = Customers.name_of(id)
	_screen.add_child(UITheme.button("‹ Volver", func() -> void: _go("messages")))
	var msgs: Array = Customers.state[id]["messages"]
	for m in msgs.slice(maxi(0, msgs.size() - 12)):
		var me := bool(m["me"])
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.18, 0.4, 0.25) if me else Color(0.2, 0.22, 0.27), 12, Color(0, 0, 0, 0)))
		p.size_flags_horizontal = Control.SIZE_SHRINK_END if me else Control.SIZE_SHRINK_BEGIN
		var l := UITheme.label("%s\n%s" % [m["text"], m["t"]], 14, Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(280, 0)
		p.add_child(l)
		_screen.add_child(p)
	var o := Customers.get_order(id)
	if not o.is_empty():
		var c := _card()
		var pname: String = ItemDB.PRODUCTS[o["product"]]["name"]
		var have := Customers.units_available(String(o["product"]))
		c.add_child(_lbl("Pedido: %d de %s por %s" % [int(o["qty"]), pname, UITheme.money(int(o["price"]))], 16, UITheme.WARN))
		c.add_child(_lbl("Llevas %d unidades empaquetadas de %s." % [have, pname], 13, UITheme.TEXT_DIM if have >= int(o["qty"]) else UITheme.DANGER))
		var h := HBoxContainer.new()
		c.add_child(h)
		h.add_child(UITheme.button("Aceptar", func() -> void:
			Customers.accept_order(id)
			_refresh()))
		h.add_child(UITheme.button("Rechazar", func() -> void:
			Customers.decline_order(id)
			_refresh()))
		var h2 := HBoxContainer.new()
		c.add_child(h2)
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 99999
		spin.value = int(int(o["price"]) * 1.15)
		spin.prefix = "$"
		spin.custom_minimum_size = Vector2(140, 0)
		h2.add_child(spin)
		h2.add_child(UITheme.button("Contraoferta", func() -> void:
			var r := Customers.counter_offer(id, int(spin.value))
			if r == "accepted":
				Audio.play("cash", -6.0)
			_refresh()))
	elif Customers.has_deal(id):
		var dl := Customers.get_deal(id)
		var c2 := _card()
		var left := Customers.minutes_left(id)
		c2.add_child(_lbl("Entrega acordada: %d de %s por %s" % [int(dl["qty"]), ItemDB.PRODUCTS[dl["product"]]["name"], UITheme.money(int(dl["price"]))], 16, UITheme.MONEY))
		c2.add_child(_lbl("Lugar: %s · Tiempo restante: %dh %02dmin" % [dl["location_name"], left / 60, left % 60], 14))
		var h3 := HBoxContainer.new()
		c2.add_child(h3)
		h3.add_child(UITheme.button("Marcar en el mapa", func() -> void: _mark_deal(id)))
		h3.add_child(UITheme.button("Cancelar", func() -> void:
			Customers.cancel_deal(id)
			_refresh()))


func _mark_deal(id: String) -> void:
	var dl := Customers.get_deal(id)
	var mp: Dictionary = GameState.world.get_meeting_point_data(String(dl.get("location", ""))) if GameState.world else {}
	var pos: Vector3 = mp.get("pos", Vector3.ZERO)
	if mp.is_empty() and GameState.world and GameState.world.customers_npcs.has(id):
		pos = GameState.world.customers_npcs[id].global_position
	if pos != Vector3.ZERO and ui and ui.hud:
		ui.hud.set_waypoint(pos, "Entrega con %s" % Customers.name_of(id))


# ------------------------------------------------------------------ Clientes

func _contacts() -> void:
	_header.text = "Clientes (%d)" % Customers.unlocked_count()
	var potential := 0
	for id in Customers.defs:
		var d: Dictionary = Customers.defs[id]
		if not Customers.is_unlocked(id):
			if GameState.is_district_unlocked(String(d["district"])):
				potential += 1
			continue
		var c := _card()
		c.add_child(_lbl("%s · %s" % [d["name"], GameState.DISTRICTS[d["district"]]["name"]], 16, UITheme.ACCENT))
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = Customers.relationship(id)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(360, 8)
		c.add_child(bar)
		var prefs: Array = []
		for e in d["prefs"]:
			prefs.append(ItemDB.EFFECTS[e]["name"])
		var std := float(d["standards"])
		var std_t := "Baja" if std < 0.35 else ("Media" if std < 0.55 else "Alta")
		var bud := float(d["budget"])
		var bud_t := "Bajo" if bud < 1.1 else ("Medio" if bud < 1.5 else "Alto")
		var prods: Array = []
		for p in d["products"]:
			prods.append(ItemDB.PRODUCTS[p]["name"])
		c.add_child(_lbl("Relación: %s (%d) · Compras: %d" % [Customers.relationship_label(id), Customers.relationship(id), int(Customers.state[id]["deals_done"])], 13))
		c.add_child(_lbl("Le gusta: %s · Exigencia: %s · Presupuesto: %s" % [", ".join(prods) + " / " + ", ".join(prefs), std_t, bud_t], 13, UITheme.TEXT_DIM))
		c.add_child(_lbl("Paga hasta ~%s por unidad de Glimmer" % UITheme.money(Customers.max_willing(id, "glimmer")), 13, UITheme.TEXT_DIM))
	_screen.add_child(_lbl("\nClientes potenciales en zonas accesibles: %d. Búscalos por la calle (marcados con '?') y ofréceles una muestra." % potential, 14, UITheme.WARN))


# ------------------------------------------------------------------ Mapa

func _map() -> void:
	_header.text = "Mapa"
	var mv := MapView.new()
	mv.custom_minimum_size = Vector2(400, 420)
	mv.waypoint_selected.connect(func(pos: Vector3, n: String) -> void:
		if ui and ui.hud:
			ui.hud.set_waypoint(pos, n))
	_screen.add_child(mv)
	_screen.add_child(_lbl("Pulsa M para el mapa a pantalla completa.", 13, UITheme.TEXT_DIM))
	var legend := [["Tiendas", Color(0.95, 0.75, 0.25)], ["Misiones", Color(1.0, 0.55, 0.3)], ["Propiedades", Color(0.6, 0.85, 0.6)], ["Entregas", Color(0.3, 1.0, 0.3)], ["Policía", Color(0.35, 0.55, 1.0)]]
	for l in legend:
		var lab := _lbl("● " + String(l[0]), 13, l[1])
		_screen.add_child(lab)


# ------------------------------------------------------------------ Misiones

func _quests() -> void:
	_header.text = "Misiones"
	if Quests.active.is_empty():
		_screen.add_child(_lbl("No tienes misiones activas.", 15, UITheme.TEXT_DIM))
	for id in Quests.active:
		var qid: String = id
		var d: Dictionary = Quests.defs[qid]
		var c := _card()
		var tracked := Quests.get_tracked() == qid
		c.add_child(_lbl(("▶ " if tracked else "") + String(d["title"]) + ("  (principal)" if d.get("kind", "") == "main" else "  (secundaria)"), 16, UITheme.WARN if tracked else UITheme.ACCENT))
		c.add_child(_lbl(String(d.get("desc", "")), 13, UITheme.TEXT_DIM))
		var objs: Array = d["objectives"]
		var st := int(Quests.active[qid]["stage"])
		for i in objs.size():
			var mark := "✔ " if i < st else ("› " if i == st else "  ")
			var text := Quests.objective_text(qid) if i == st else String(objs[i]["text"])
			c.add_child(_lbl(mark + text, 14, UITheme.TEXT if i == st else UITheme.TEXT_DIM))
		if not tracked:
			c.add_child(UITheme.button("Seguir esta misión", func() -> void:
				Quests.set_tracked(qid)
				_refresh()))
	if Quests.completed.size() > 0:
		_screen.add_child(_lbl("\nCompletadas:", 15, UITheme.TEXT_DIM))
		for id in Quests.completed:
			_screen.add_child(_lbl("✔ " + Quests.title(String(id)), 13, UITheme.TEXT_DIM))


# ------------------------------------------------------------------ Productos

func _products() -> void:
	_header.text = "Productos y precios"
	_screen.add_child(_lbl("Fija tu precio por unidad. Los clientes pagan hasta su máximo; por encima te harán una contraoferta más baja.", 13, UITheme.TEXT_DIM))
	for p in ItemDB.PRODUCTS:
		var pid: String = p
		if pid == "azure" and not GameState.flags.get("azure_known", false) and not Quests.is_completed("q_docks"):
			var lc := _card()
			lc.add_child(_lbl("Azure: bloqueado (misión 'Cristal azul').", 14, UITheme.TEXT_DIM))
			continue
		var c := _card()
		c.add_child(_lbl(String(ItemDB.PRODUCTS[pid]["name"]), 18, UITheme.ACCENT))
		c.add_child(_lbl("Valor base: %s/unidad (calidad normal sin efectos)" % UITheme.money(ItemDB.unit_value(pid, {"quality": 0.5})), 13))
		var h := HBoxContainer.new()
		c.add_child(h)
		h.add_child(UITheme.label("Tu precio:", 15))
		var spin := SpinBox.new()
		spin.min_value = 1
		spin.max_value = 9999
		spin.prefix = "$"
		spin.value = int(GameState.listing_prices.get(pid, 40))
		spin.value_changed.connect(func(v: float) -> void: GameState.listing_prices[pid] = int(v))
		h.add_child(spin)
		var mk: Array = []
		for d in GameState.unlocked_districts:
			mk.append("%s x%.2f" % [GameState.DISTRICTS[d]["name"], RandomEvents.market_mult(d, pid)])
		c.add_child(_lbl("Mercado hoy: " + ", ".join(mk), 13, UITheme.TEXT_DIM))


# ------------------------------------------------------------------ Propiedades

func _business() -> void:
	_header.text = "Propiedades"
	_screen.add_child(_lbl("Gastos diarios (7:00): %s" % UITheme.money(Business.daily_cost()), 14, UITheme.WARN))
	for pid in Business.prop_defs:
		var p: String = pid
		var d: Dictionary = Business.prop_defs[p]
		var c := _card()
		var status := "Propia" if Business.owns(p) else ("Alquilada ($%d/día)" % int(d["rent"]) if Business.properties[p]["rented"] else ("En venta: %s" % UITheme.money(int(d["price"])) if int(d["price"]) > 0 else "Sin acceso"))
		c.add_child(_lbl("%s · %s" % [d["name"], GameState.DISTRICTS[d["district"]]["name"]], 16, UITheme.ACCENT))
		c.add_child(_lbl(status, 14, UITheme.MONEY if Business.has_access(p) else UITheme.TEXT_DIM))
		if Business.has_access(p):
			var used := 0
			var summary: Array = []
			for k in Business.properties[p]["stations"]:
				used += 1
				var st: Dictionary = Business.properties[p]["stations"][k]
				var s := String(Business.STATION_NAMES.get(st["type"], st["type"]))
				if st["type"] == "grow" and st.get("planted", false):
					s += " (%d%%)" % int(float(st["growth"]) * 100.0)
				elif st["type"] in ["mixing", "lab"] and st.get("busy", false):
					s += " (%d min)" % int(st["remaining"])
				summary.append(s)
			c.add_child(_lbl("Huecos: %d/%d" % [used, int(d["slots"])], 13))
			if summary.size() > 0:
				c.add_child(_lbl(", ".join(summary), 13, UITheme.TEXT_DIM))
		c.add_child(UITheme.button("Marcar en el mapa", func() -> void: _mark_property(p)))


func _mark_property(pid: String) -> void:
	if GameState.world == null or not GameState.world.property_spawns.has(pid):
		return
	if ui and ui.hud:
		ui.hud.set_waypoint(GameState.world.property_spawns[pid]["pos"], Business.property_name(pid))


# ------------------------------------------------------------------ Empleados

func _staff() -> void:
	_header.text = "Empleados"
	var props := Business.accessible_properties()
	if Business.employees.size() > 0:
		_screen.add_child(_lbl("Plantilla:", 15, UITheme.TEXT_DIM))
	for e in Business.employees:
		var eid: String = e["id"]
		var c := _card()
		c.add_child(_lbl("%s · %s · %s/día" % [e["name"], Business.ROLE_NAMES[e["role"]], UITheme.money(int(e["wage"]))], 16, UITheme.ACCENT))
		c.add_child(_lbl("En: %s" % Business.property_name(String(e["property"])), 13))
		c.add_child(_lbl("Estado: %s" % e.get("status", "-"), 13, UITheme.TEXT_DIM))
		var h := HBoxContainer.new()
		c.add_child(h)
		if props.size() > 1:
			h.add_child(UITheme.button("Cambiar de propiedad", func() -> void:
				var i := props.find(String(e["property"]))
				Business.reassign(eid, props[(i + 1) % props.size()])
				_refresh()))
		h.add_child(UITheme.button("Despedir", func() -> void:
			Business.fire(eid)
			_refresh()))
	_screen.add_child(_lbl("\nCandidatos (cobran el primer día al contratar):", 15, UITheme.TEXT_DIM))
	for cand in Business.EMPLOYEE_CANDIDATES:
		if Business.is_hired(cand["id"]):
			continue
		var cid: String = cand["id"]
		var c2 := _card()
		c2.add_child(_lbl("%s · %s · %s/día" % [cand["name"], Business.ROLE_NAMES[cand["role"]], UITheme.money(int(cand["wage"]))], 15, UITheme.TEXT))
		c2.add_child(_lbl(String(Business.ROLE_DESC[cand["role"]]), 13, UITheme.TEXT_DIM))
		if GameState.rank < int(cand["rank"]):
			c2.add_child(_lbl("Requiere rango %s" % GameState.rank_name(int(cand["rank"])), 13, UITheme.DANGER))
			continue
		var h2 := HBoxContainer.new()
		c2.add_child(h2)
		var opt := OptionButton.new()
		for p in props:
			opt.add_item(Business.property_name(p))
		h2.add_child(opt)
		h2.add_child(UITheme.button("Contratar", func() -> void:
			if props.is_empty():
				return
			Business.hire(cid, props[opt.selected])
			_refresh()))


# ------------------------------------------------------------------ Estadísticas

func _stats() -> void:
	_header.text = "Estadísticas"
	var s := GameState.stats
	var c := _card()
	c.add_child(_lbl("Rango: %s (%d XP)" % [GameState.rank_name(), GameState.xp], 16, UITheme.WARN))
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = GameState.rank_progress()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(360, 8)
	c.add_child(bar)
	if GameState.rank + 1 < GameState.RANKS.size():
		c.add_child(_lbl("Siguiente: %s (%d XP)" % [GameState.rank_name(GameState.rank + 1), int(GameState.RANKS[GameState.rank + 1]["xp"])], 13, UITheme.TEXT_DIM))
	var rows := [
		["Día", str(GameState.day)], ["Efectivo", UITheme.money(GameState.cash)], ["Banco", UITheme.money(GameState.bank)],
		["Ventas realizadas", str(s.get("deals", 0))], ["Unidades vendidas", str(s.get("units_sold", 0))],
		["Ingresos por ventas", UITheme.money(int(s.get("revenue", 0)))], ["Gastos totales", UITheme.money(int(s.get("expenses", 0)))],
		["Clientes", str(Customers.unlocked_count())], ["Muestras regaladas", str(s.get("samples_given", 0))],
		["Cosechas", str(s.get("harvests", 0))], ["Unidades empaquetadas", str(s.get("packaged", 0))], ["Unidades mezcladas", str(s.get("mixed", 0))],
		["Detenciones", str(s.get("arrests", 0))], ["Multas pagadas", UITheme.money(int(s.get("fines_paid", 0)))],
		["Misiones completadas", str(s.get("quests_done", 0))], ["Distancia recorrida", "%.1f km" % (float(s.get("distance", 0.0)) / 1000.0)],
		["Propiedades", str(Business.owned_property_count(true))], ["Empleados", str(Business.employees.size())],
	]
	for r in rows:
		var h := HBoxContainer.new()
		var a := UITheme.label(String(r[0]), 14, UITheme.TEXT_DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(UITheme.label(String(r[1]), 14, UITheme.TEXT))
		_screen.add_child(h)


# ------------------------------------------------------------------ Noticias

func _news() -> void:
	_header.text = "Noticias de Redmont"
	if RandomEvents.active_events.is_empty():
		_screen.add_child(_lbl("Nada destacable ahora mismo.", 14, UITheme.TEXT_DIM))
	for e in RandomEvents.active_events:
		var c := _card()
		var left := int(e["until"]) - GameState.absolute_minute()
		c.add_child(_lbl(String(e["title"]), 16, UITheme.WARN))
		c.add_child(_lbl("%s (quedan %dh %02dmin)" % [e["desc"], left / 60, left % 60], 13))
	if Police.is_crackdown():
		var c2 := _card()
		c2.add_child(_lbl("Patrullas reforzadas: la sospecha sube más deprisa.", 14, UITheme.POLICE))
	for d in GameState.lockdowns:
		var c3 := _card()
		c3.add_child(_lbl("%s cerrado por la policía." % GameState.DISTRICTS[d]["name"], 14, UITheme.POLICE))
	if RandomEvents.news.size() > 0:
		_screen.add_child(_lbl("\nTitulares:", 15, UITheme.TEXT_DIM))
		for n in RandomEvents.news:
			_screen.add_child(_lbl("· " + String(n), 13, UITheme.TEXT_DIM))
