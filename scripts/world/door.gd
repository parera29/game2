class_name Door
extends Node3D
## Puerta con bisagra animada. Puede estar bloqueada por horario o propiedad
## mediante lock_check (Callable que devuelve "" si se puede abrir o el motivo).

var width := 1.3
var height := 2.3
var panel_color := Color(0.42, 0.28, 0.18)
var lock_check: Callable
var door_name := "puerta"
var is_open := false
var _pivot: Node3D
var _body: AnimatableBody3D
var _tween: Tween
var _auto_close_timer := 0.0


func setup(w: float, h: float, color: Color, glass: bool = false) -> void:
	width = w
	height = h
	panel_color = color
	_pivot = Node3D.new()
	_pivot.position = Vector3(-w * 0.5, 0, 0)
	add_child(_pivot)
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	_body.collision_layer = Geo.LAYER_WORLD
	_body.collision_mask = 0
	_body.position = Vector3(w * 0.5, h * 0.5, 0)
	_pivot.add_child(_body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w - 0.04, h, 0.08)
	cs.shape = sh
	_body.add_child(cs)
	Geo.box(_body, Vector3(w - 0.04, h, 0.07), Vector3.ZERO, Mats.color(color, 0.6), false)
	if glass:
		Geo.box(_body, Vector3(w - 0.4, h * 0.5, 0.08), Vector3(0, h * 0.12, 0), Mats.glass(), false)
	# Pomo
	Geo.sphere(_body, 0.045, Vector3(w * 0.5 - 0.15, -0.05, 0.07), Mats.color(Color(0.8, 0.75, 0.5), 0.3, 0.8), 6)
	Geo.sphere(_body, 0.045, Vector3(w * 0.5 - 0.15, -0.05, -0.07), Mats.color(Color(0.8, 0.75, 0.5), 0.3, 0.8), 6)
	# El script de interacción vive en este nodo; el cuerpo lo referencia.
	_body.set_meta("interact_target", self)


func get_prompt(_player: Node) -> String:
	if not is_open:
		var reason := _lock_reason()
		if reason != "":
			return reason
		return "Abrir %s" % door_name
	return "Cerrar %s" % door_name


func _lock_reason() -> String:
	if lock_check.is_valid():
		return String(lock_check.call())
	return ""


func interact(player: Node) -> void:
	if is_open:
		close()
		return
	var reason := _lock_reason()
	if reason != "":
		Audio.play("error", -6.0)
		Events.toast(reason, "warn")
		return
	open_away_from(player.global_position if player is Node3D else global_position + global_basis.z)


func open_away_from(pos: Vector3) -> void:
	if is_open:
		return
	var local := to_local(pos)
	var angle := -1.6 if local.z > 0.0 else 1.6
	_animate(angle)
	is_open = true
	_auto_close_timer = 10.0
	Audio.play_3d("door", global_position + Vector3.UP, -4.0)


func close() -> void:
	if not is_open:
		return
	_animate(0.0)
	is_open = false
	Audio.play_3d("door", global_position + Vector3.UP, -6.0, 0.9)


## Las NPC (policía) pueden atravesar puertas aunque estén bloqueadas para el jugador.
func open_for_npc(pos: Vector3) -> void:
	open_away_from(pos)


func _animate(target: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation:y", target, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not is_open:
		return
	_auto_close_timer -= delta
	if _auto_close_timer <= 0.0:
		# Cierra sola si no hay nadie en el umbral
		var p := GameState.player as Node3D
		if p == null or p.global_position.distance_to(global_position) > 2.5:
			close()
		else:
			_auto_close_timer = 3.0
