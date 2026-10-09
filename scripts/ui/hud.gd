class_name HUD
extends Control
## HUD: reloj, dinero, rango, sospecha policial, mira, indicador de interacción,
## barra rápida, resistencia, misión activa, entregas, notificaciones y destino.

var _clock: Label
var _district: Label
var _cash: Label
var _bank: Label
var _rank: Label
var _xp: ProgressBar
var _heat_box: PanelContainer
var _heat_label: Label
var _heat_bar: ProgressBar
var _search_bar: ProgressBar
var _crosshair: Control
var _prompt: Label
var _hotbar: HBoxContainer
var _slots: Array = []
var _held_name: Label
var _stamina: ProgressBar
var _weight: Label
var _quest_title: Label
var _quest_obj: Label
var _deals: VBoxContainer
var _notes: VBoxContainer
var _waypoint: Label
var _fps: Label
var _hint: Label
var _modal := false
var waypoint_pos := Vector3.ZERO
var waypoint_name := ""
var _deal_timer := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_top_right()
	_build_heat()
	_build_center()
	_build_hotbar()
	_build_right()
	_build_notes()
	Events.notify.connect(_on_notify)
	Events.money_changed.connect(func(_c: int, _b: int) -> void: _refresh_money())
	Events.xp_changed.connect(func(_x: int, _r: int) -> void: _refresh_money())
	Events.heat_changed.connect(func(_s: float, _w: int) -> void: _refresh_heat())
	Events.quest_started.connect(func(_q: String) -> void: _refresh_quest())
	Events.quest_updated.connect(func(_q: String) -> void: _refresh_quest())
	Events.quest_completed.connect(func(_q: String) -> void: _refresh_quest())
	Events.deal_scheduled.connect(func(_c: String) -> void: _refresh_deals())
	Events.deal_cancelled.connect(func(_c: String) -> void: _refresh_deals())
	Events.deal_completed.connect(func(_c: String, _u: int, _t: int) -> void: _refresh_deals())
	GameState.player_inventory.changed.connect(_refresh_hotbar)
	_refresh_money()
	_refresh_heat()
	_refresh_quest()
	_refresh_hotbar()
	_refresh_deals()


func _panel(pos_preset: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.05, 0.06, 0.08, 0.72), 10, Color(1, 1, 1, 0.05)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	p.set_anchors_preset(pos_preset)
	return p


func _build_top_left() -> void:
	var p := _panel(Control.PRESET_TOP_LEFT)
	p.position = Vector2(16, 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	_clock = UITheme.label("", 26, Color.WHITE)
	v.add_child(_clock)
	_district = UITheme.label("", 15, UITheme.TEXT_DIM)
	v.add_child(_district)


func _build_top_right() -> void:
	var p := _panel(Control.PRESET_TOP_RIGHT)
	p.position = Vector2(-16, 16)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	_cash = UITheme.label("$0", 30, UITheme.MONEY, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(_cash)
	_bank = UITheme.label("", 14, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(_bank)
	_rank = UITheme.label("", 15, UITheme.WARN, HORIZONTAL_ALIGNMENT_RIGHT)
	v.add_child(_rank)
	_xp = ProgressBar.new()
	_xp.custom_minimum_size = Vector2(200, 8)
	_xp.show_percentage = false
	_xp.max_value = 1.0
	v.add_child(_xp)


func _build_heat() -> void:
	_heat_box = _panel(Control.PRESET_CENTER_TOP)
	_heat_box.position = Vector2(-150, 16)
	_heat_box.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_heat_box.add_child(v)
	_heat_label = UITheme.label("", 17, UITheme.POLICE, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_heat_label)
	_heat_bar = ProgressBar.new()
	_heat_bar.custom_minimum_size = Vector2(280, 8)
	_heat_bar.show_percentage = false
	_heat_bar.max_value = 100.0
	var fill := UITheme.panel_style(UITheme.DANGER, 4, Color(0, 0, 0, 0))
	_heat_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(_heat_bar)
	_search_bar = ProgressBar.new()
	_search_bar.custom_minimum_size = Vector2(280, 8)
	_search_bar.show_percentage = false
	_search_bar.max_value = 1.0
	_search_bar.visible = false
	v.add_child(_search_bar)
	_waypoint = UITheme.shadow_label("", 16, UITheme.WARN)
	_waypoint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_waypoint.position = Vector2(-200, 110)
	_waypoint.custom_minimum_size = Vector2(400, 0)
	_waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_waypoint)


func _build_center() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		_crosshair.draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.5))
		_crosshair.draw_circle(Vector2.ZERO, 2.2, Color(1, 1, 1, 0.9)))
	add_child(_crosshair)
	_prompt = UITheme.shadow_label("", 19, Color.WHITE)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 28)
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_fps = UITheme.shadow_label("", 14, UITheme.TEXT_DIM)
	_fps.position = Vector2(16, 90)
	add_child(_fps)


func _build_hotbar() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.position = Vector2(-300, -110)
	box.custom_minimum_size = Vector2(600, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)
	_held_name = UITheme.shadow_label("", 17, Color.WHITE)
	_held_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_held_name)
	_hotbar = HBoxContainer.new()
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 6)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hotbar)
	for i in GameState.HOTBAR_SIZE:
		var s := ItemSlot.new()
		s.setup(GameState.player_inventory, i, 58, str(i + 1))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar.add_child(s)
		_slots.append(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(260, 6)
	_stamina.show_percentage = false
	_stamina.max_value = 100.0
	_stamina.add_theme_stylebox_override("fill", UITheme.panel_style(Color(0.95, 0.85, 0.3), 3, Color(0, 0, 0, 0)))
	row.add_child(_stamina)
	_weight = UITheme.shadow_label("", 13, UITheme.TEXT_DIM)
	row.add_child(_weight)


func _build_right() -> void:
	var p := _panel(Control.PRESET_CENTER_RIGHT)
	p.position = Vector2(-16, -120)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	_quest_title = UITheme.label("", 17, UITheme.WARN)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_title.custom_minimum_size = Vector2(280, 0)
	v.add_child(_quest_title)
	_quest_obj = UITheme.label("", 15, UITheme.TEXT)
	_quest_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_obj.custom_minimum_size = Vector2(280, 0)
	v.add_child(_quest_obj)
	_deals = VBoxContainer.new()
	_deals.add_theme_constant_override("separation", 2)
	v.add_child(_deals)
	_hint = UITheme.shadow_label("Tab: teléfono · I: inventario · M: mapa · Esc: menú", 13, UITheme.TEXT_DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, -30)
	add_child(_hint)


func _build_notes() -> void:
	_notes = VBoxContainer.new()
	_notes.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_notes.position = Vector2(16, -60)
	_notes.custom_minimum_size = Vector2(420, 0)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.add_theme_constant_override("separation", 6)
	add_child(_notes)


# ------------------------------------------------------------------ Actualización

func set_modal(v: bool) -> void:
	_modal = v
	_crosshair.visible = not v
	_prompt.visible = not v


func _process(delta: float) -> void:
	_clock.text = "%s  %s · Día %d" % [GameState.weekday_name(), GameState.time_string(), GameState.day]
	var p := GameState.player
	if p:
		var d := GameState.district_at(p.global_position)
		var extra := ""
		if GameState.is_curfew() and not p.is_indoors:
			extra = "  ·  TOQUE DE QUEDA"
		_district.text = GameState.DISTRICTS[d]["name"] + extra
		_district.add_theme_color_override("font_color", UITheme.DANGER if extra != "" else UITheme.TEXT_DIM)
		_prompt.text = ("[%s] %s" % [Settings.binding_label(Settings.bindings.get("interact", "key:69")), p.current_prompt]) if p.current_prompt != "" and not p.current_prompt.begins_with("[") else p.current_prompt
		_stamina.value = p.stamina
		_stamina.visible = p.stamina < 99.0
		for i in _slots.size():
			(_slots[i] as ItemSlot).set_selected(i == p.hotbar_index)
		var held = GameState.player_inventory.get_slot(p.hotbar_index)
		_held_name.text = ItemDB.display_name(held["id"], held["data"]) if held != null else ""
		_update_waypoint(p)
	var sp := Police.search_progress()
	_search_bar.visible = sp >= 0.0
	if sp >= 0.0:
		_search_bar.value = sp
		_heat_box.visible = true
	if Settings.get_value("show_fps", false):
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	else:
		_fps.text = ""
	_deal_timer -= delta
	if _deal_timer <= 0.0:
		_deal_timer = 1.0
		_refresh_deals()


func _update_waypoint(p: Node3D) -> void:
	if waypoint_pos == Vector3.ZERO:
		_waypoint.text = ""
		return
	var to := waypoint_pos - p.global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 4.0:
		Events.toast("Has llegado a: %s" % waypoint_name, "info")
		waypoint_pos = Vector3.ZERO
		_waypoint.text = ""
		return
	var fwd := -p.global_basis.z
	var ang := rad_to_deg(atan2(fwd.x * to.z - fwd.z * to.x, fwd.x * to.x + fwd.z * to.z))
	var arrow := "↑"
	if ang > 135 or ang < -135:
		arrow = "↓"
	elif ang > 45:
		arrow = "→"
	elif ang < -45:
		arrow = "←"
	elif ang > 15:
		arrow = "↗"
	elif ang < -15:
		arrow = "↖"
	_waypoint.text = "%s  %s · %d m" % [arrow, waypoint_name, int(dist)]


func set_waypoint(pos: Vector3, p_name: String) -> void:
	waypoint_pos = pos
	waypoint_name = p_name
	Events.toast("Destino marcado: %s" % p_name, "info")


func _refresh_money() -> void:
	_cash.text = UITheme.money(GameState.cash)
	_bank.text = "Banco: %s" % UITheme.money(GameState.bank)
	_rank.text = "%s · %d XP" % [GameState.rank_name(), GameState.xp]
	_xp.value = GameState.rank_progress()


func _refresh_heat() -> void:
	var w := Police.wanted
	var s := Police.suspicion
	_heat_box.visible = w > 0 or s >= 1.0
	_heat_bar.value = s
	if w > 0:
		_heat_label.text = "★ " + Police.WANTED_NAMES[w].to_upper() + (" ★" if w >= 2 else "")
		_heat_label.add_theme_color_override("font_color", UITheme.DANGER if w >= 2 else UITheme.WARN)
	else:
		_heat_label.text = "Sospecha policial"
		_heat_label.add_theme_color_override("font_color", UITheme.POLICE)


func _refresh_quest() -> void:
	var q := Quests.get_tracked()
	if q == "":
		_quest_title.text = "Sin misiones activas"
		_quest_obj.text = "Atiende a tus clientes y haz crecer el negocio."
		return
	_quest_title.text = Quests.title(q)
	_quest_obj.text = "› " + Quests.objective_text(q)


func _refresh_deals() -> void:
	UITheme.clear(_deals)
	for id in Customers.state:
		if Customers.has_deal(id):
			var dl := Customers.get_deal(id)
			var left := Customers.minutes_left(id)
			var col := UITheme.MONEY if left > 60 else UITheme.DANGER
			var l := UITheme.label("$ %s: %d %s en %s (%dh%02d)" % [Customers.name_of(id), int(dl["qty"]), ItemDB.PRODUCTS[dl["product"]]["name"], dl["location_name"], left / 60, left % 60], 14, col)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(280, 0)
			_deals.add_child(l)
	var pending := 0
	for id in Customers.state:
		if not Customers.get_order(id).is_empty():
			pending += 1
	if pending > 0:
		_deals.add_child(UITheme.label("✉ %d pedido(s) sin responder (Tab)" % pending, 14, UITheme.WARN))


func _refresh_hotbar() -> void:
	for s in _slots:
		(s as ItemSlot).refresh()
	var inv: Inventory = GameState.player_inventory
	_weight.text = "  %.1f / %.0f kg" % [inv.total_weight(), inv.max_weight]


func _on_notify(text: String, kind: String) -> void:
	var col := UITheme.TEXT
	var icon := "•"
	match kind:
		"money":
			col = UITheme.MONEY
			icon = "$"
		"quest":
			col = UITheme.WARN
			icon = "★"
		"warn":
			col = Color(1.0, 0.6, 0.45)
			icon = "!"
		"police":
			col = UITheme.POLICE
			icon = "⚑"
		"phone":
			col = Color(0.6, 0.85, 1.0)
			icon = "✉"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.05, 0.06, 0.08, 0.82), 8, col.darkened(0.4)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label("%s  %s" % [icon, text], 15, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	p.add_child(l)
	_notes.add_child(p)
	while _notes.get_child_count() > 6:
		var old := _notes.get_child(0)
		_notes.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)
