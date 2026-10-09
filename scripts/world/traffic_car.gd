class_name TrafficCar
extends Node3D
## Coche de tráfico que recorre un circuito cerrado por el carril derecho.
## Frena ante el jugador, peatones y otros coches. Solo circula si su distrito es accesible.

const MAX_SPEED := 9.0
const LOOK_AHEAD := 8.0

var points := PackedVector3Array()
var seg := 0
var speed := 0.0
var district := "northtown"
var _body: AnimatableBody3D
var _blocked_time := 0.0
var _ghost_time := 0.0
var _check_timer := 0.0
var _blocked := false


func setup(pts: PackedVector3Array, start: int, color: Color, p_district: String) -> void:
	points = pts
	seg = start % pts.size()
	district = p_district
	var model := CarModel.make(self, color)
	model.name = "Model"
	_body = AnimatableBody3D.new()
	_body.collision_layer = Geo.LAYER_VEHICLE
	_body.collision_mask = 0
	_body.sync_to_physics = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.85, 1.4, 4.3)
	cs.shape = sh
	cs.position.y = 0.75
	_body.add_child(cs)
	add_child(_body)
	global_position = points[seg]
	var nxt := points[(seg + 1) % points.size()]
	var d := nxt - global_position
	rotation.y = atan2(-d.x, -d.z)
	add_to_group("traffic")


func _physics_process(delta: float) -> void:
	var active := GameState.is_district_accessible(district)
	if visible != active:
		visible = active
		_body.collision_layer = Geo.LAYER_VEHICLE if active else 0
	if not active or points.size() < 2:
		return
	var target := points[(seg + 1) % points.size()]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 1.2:
		seg = (seg + 1) % points.size()
		return
	var dir := to.normalized()
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.15
		_blocked = _is_blocked(-global_basis.z)
	if _ghost_time > 0.0:
		_ghost_time -= delta
		_blocked = false
	if _blocked:
		_blocked_time += delta
		if _blocked_time > 6.0 and not _player_ahead(-global_basis.z):
			_ghost_time = 2.5
			_blocked_time = 0.0
	else:
		_blocked_time = 0.0
	var target_speed := 0.0 if _blocked else MAX_SPEED
	# Reducir en las curvas
	if to.length() < 6.0:
		target_speed = minf(target_speed, 5.0)
	speed = move_toward(speed, target_speed, delta * (14.0 if _blocked else 4.0))
	global_position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 3.5, 0.0, 1.0))


func _player_ahead(fwd: Vector3) -> bool:
	var p := GameState.player as Node3D
	if p == null:
		return false
	return _in_front(p.global_position, fwd, LOOK_AHEAD)


func _in_front(pos: Vector3, fwd: Vector3, dist: float) -> bool:
	var to := pos - global_position
	to.y = 0.0
	var d := to.length()
	if d > dist or d < 0.1:
		return false
	var lateral := absf(to.dot(Vector3(-fwd.z, 0, fwd.x)))
	return to.dot(fwd) > 0.0 and lateral < 1.8


func _is_blocked(fwd: Vector3) -> bool:
	if _player_ahead(fwd):
		return true
	for c in get_tree().get_nodes_in_group("traffic"):
		if c != self and (c as Node3D).visible and _in_front((c as Node3D).global_position, fwd, LOOK_AHEAD):
			return true
	if GameState.world:
		for n in GameState.world.npc_root.get_children():
			if (n as Node3D).visible and _in_front((n as Node3D).global_position, fwd, 6.0):
				return true
	return false
