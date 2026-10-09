class_name MapView
extends Control
## Mapa 2D de Redmont dibujado a partir de los datos del mundo: calles, edificios,
## distritos bloqueados, puntos de interés, entregas, policía y jugador.
## Interactivo: rueda para zoom, arrastrar para mover, clic en un punto para marcar destino.

signal waypoint_selected(pos: Vector3, name: String)

const WORLD_RECT := Rect2(-25, -25, 250, 250)

var interactive := true
var zoom := 1.0
var pan := Vector2.ZERO
var _dragging := false
var _hover_poi := {}
var _font: Font


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _center_on(p: Vector3) -> void:
	var base := _base_scale()
	pan = Vector2(p.x, p.z) - WORLD_RECT.get_center()
	pan *= base * zoom
	pan = -pan


func _base_scale() -> float:
	return minf(size.x, size.y) / WORLD_RECT.size.x if size.x > 0 else 1.0


func w2m(p: Vector2) -> Vector2:
	var s := _base_scale() * zoom
	return size * 0.5 + (p - WORLD_RECT.get_center()) * s + pan


func m2w(p: Vector2) -> Vector2:
	var s := _base_scale() * zoom
	return (p - size * 0.5 - pan) / s + WORLD_RECT.get_center()


func _process(_d: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.15)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				set_meta("press_pos", event.position)
			else:
				_dragging = false
				var pp: Vector2 = get_meta("press_pos", event.position)
				if pp.distance_to(event.position) < 5.0 and not _hover_poi.is_empty():
					waypoint_selected.emit(_hover_poi["pos"], String(_hover_poi["name"]))
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			pan += event.relative
		_hover_poi = _poi_at(event.position)
		accept_event()


func _zoom_at(at: Vector2, f: float) -> void:
	var before := m2w(at)
	zoom = clampf(zoom * f, 0.8, 6.0)
	var after := m2w(at)
	pan += (after - before) * _base_scale() * zoom


func _all_points() -> Array:
	var out: Array = []
	if GameState.world == null:
		return out
	for p in GameState.world.pois:
		out.append(p)
	for id in Customers.state:
		if Customers.has_deal(id):
			var dl := Customers.get_deal(id)
			var mp: Dictionary = GameState.world.get_meeting_point_data(String(dl.get("location", "")))
			var pos: Vector3 = mp.get("pos", Vector3.ZERO)
			if mp.is_empty() and GameState.world.customers_npcs.has(id):
				pos = GameState.world.customers_npcs[id].global_position
			out.append({"name": "Entrega: %s (%s)" % [Customers.name_of(id), dl["location_name"]], "pos": pos, "kind": "deal"})
	return out


func _poi_at(m: Vector2) -> Dictionary:
	for p in _all_points():
		var pos: Vector3 = p["pos"]
		if w2m(Vector2(pos.x, pos.z)).distance_to(m) < 10.0:
			return p
	return {}


var _centered := false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.3, 0.18))
	# Agua
	_rect_world(Rect2(-200, 214, 305, 200), Color(0.12, 0.25, 0.35))
	# Manzanas
	for bx in 4:
		for bz in 4:
			_rect_world(Rect2(bx * 50 + 5, bz * 50 + 5, 40, 40), Color(0.55, 0.55, 0.53))
	# Calles
	for k in 5:
		_rect_world(Rect2(-5, k * 50 - 5, 210, 10), Color(0.16, 0.16, 0.18))
		_rect_world(Rect2(k * 50 - 5, -5, 10, 210), Color(0.16, 0.16, 0.18))
	# Edificios
	if GameState.world:
		for r in GameState.world.map_rects:
			_rect_world(r["rect"], r["color"])
	# Distritos bloqueados
	for d in GameState.DISTRICTS:
		var rr: Rect2 = GameState.DISTRICTS[d]["rect"]
		var tl := w2m(rr.position)
		var br := w2m(rr.end)
		var mr := Rect2(tl, br - tl)
		if not GameState.is_district_accessible(d):
			draw_rect(mr, Color(0.05, 0.05, 0.08, 0.6))
			var why := "Rango: %s" % GameState.rank_name(int(GameState.DISTRICTS[d]["rank"]))
			if GameState.is_locked_down(d):
				why = "Cerrado por la policía"
			_text(mr.get_center() + Vector2(0, -8), String(GameState.DISTRICTS[d]["name"]) + " (CERRADO)", 16, Color(1, 0.8, 0.4))
			_text(mr.get_center() + Vector2(0, 12), why, 13, Color(0.9, 0.9, 0.9))
		else:
			_text(mr.position + Vector2(mr.size.x * 0.5, 14), String(GameState.DISTRICTS[d]["name"]).to_upper(), 13, Color(1, 1, 1, 0.55))
	# Puntos de interés
	for p in _all_points():
		var pos: Vector3 = p["pos"]
		var mp := w2m(Vector2(pos.x, pos.z))
		var col := _kind_color(String(p["kind"]))
		draw_circle(mp, 6.5, Color(0, 0, 0, 0.7))
		draw_circle(mp, 5.0, col)
		if zoom > 1.6 or p == _hover_poi or p["kind"] == "deal":
			_text(mp + Vector2(0, -12), String(p["name"]), 13, Color.WHITE)
	# Policía (solo si te buscan o está cerca)
	if GameState.world and GameState.player:
		for c in GameState.world.get_police():
			var cp: Vector3 = (c as Node3D).global_position
			if Police.wanted > 0 or cp.distance_to(GameState.player.global_position) < 30.0:
				var m := w2m(Vector2(cp.x, cp.z))
				draw_circle(m, 4.0, Color(0.3, 0.5, 1.0))
	# Destino
	var hud = _hud()
	if hud and hud.waypoint_pos != Vector3.ZERO:
		var wp := w2m(Vector2(hud.waypoint_pos.x, hud.waypoint_pos.z))
		draw_circle(wp, 9.0, Color(1, 0.85, 0.2, 0.4))
		draw_circle(wp, 4.0, Color(1, 0.85, 0.2))
	# Jugador
	if GameState.player:
		var pp: Vector3 = GameState.player.global_position
		var m2 := w2m(Vector2(pp.x, pp.z))
		var fwd: Vector3 = -GameState.player.global_basis.z
		var dir := Vector2(fwd.x, fwd.z).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([m2 + dir * 11.0, m2 - dir * 6.0 + perp * 6.0, m2 - dir * 3.0, m2 - dir * 6.0 - perp * 6.0])
		draw_colored_polygon(pts, Color(1, 1, 1))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0), 1.5)
	if interactive:
		_text(Vector2(size.x * 0.5, size.y - 12), "Rueda: zoom · Arrastrar: mover · Clic en un punto: marcar destino", 13, Color(1, 1, 1, 0.7))


func _hud() -> Variant:
	var ui := get_tree().get_first_node_in_group("ui_manager")
	if ui and ui.get("hud"):
		return ui.hud
	return null


func _kind_color(kind: String) -> Color:
	match kind:
		"shop":
			return Color(0.95, 0.75, 0.25)
		"home":
			return Color(0.4, 0.95, 0.5)
		"property":
			return Color(0.6, 0.85, 0.6)
		"police":
			return Color(0.35, 0.55, 1.0)
		"bank":
			return Color(0.4, 0.9, 0.9)
		"quest":
			return Color(1.0, 0.55, 0.3)
		"deal":
			return Color(0.3, 1.0, 0.3)
	return Color.WHITE


func _rect_world(r: Rect2, col: Color) -> void:
	var tl := w2m(r.position)
	var br := w2m(r.end)
	draw_rect(Rect2(tl, br - tl), col)


func _text(center: Vector2, t: String, sz: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	draw_string_outline(_font, center - Vector2(w * 0.5, -sz * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 4, Color(0, 0, 0, 0.8))
	draw_string(_font, center - Vector2(w * 0.5, -sz * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
