class_name NPC
extends CharacterBody3D
## Personaje no jugador con máquina de estados: pasear por rutas, horarios,
## acudir a citas, esperar, huir, perseguir, registrar y reaccionar al jugador.

const WALK := 1.6
const RUN := 5.4
const POLICE_RUN := 6.4

var npc_id := ""
var display_name := "Vecino"
var role := "pedestrian"          # pedestrian, customer, shopkeeper, quest, police, employee, mugger
var district := "northtown"
var look: Dictionary = {}
var anchor := Vector3.ZERO        # posición fija (tenderos, empleados...)
var anchor_yaw := 0.0
var active_hours := Vector2i(6, 23)
var shop_id := ""

var state := "idle"
var path := PackedVector3Array()
var path_i := 0
var state_timer := 0.0
var move_speed := WALK
var threat_pos := Vector3.ZERO
var angry_until := 0
var model: Humanoid
var hidden_home := false
var talking := false
var mugger_hits := 0

var _rng := RandomNumberGenerator.new()
var _perceive_timer := 0.0
var _stuck_timer := 0.0
var _last_progress_pos := Vector3.ZERO
var _greet_cooldown := 0.0
var _anim_speed := 0.0
var _gravity := 18.0


func setup(id: String, p_name: String, p_role: String, p_district: String, p_look: Dictionary) -> void:
	npc_id = id
	display_name = p_name
	role = p_role
	district = p_district
	look = p_look
	_rng.seed = hash(id) + Time.get_ticks_usec()


func _ready() -> void:
	add_to_group("npc")
	if role == "police":
		add_to_group("police")
	collision_layer = Geo.LAYER_NPC
	collision_mask = Geo.LAYER_WORLD | Geo.LAYER_PLAYER | Geo.LAYER_VEHICLE
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = Humanoid.new()
	add_child(model)
	model.build(look, role)
	if role in ["shopkeeper", "quest", "employee"]:
		anchor = global_position
		anchor_yaw = rotation.y
		state = "static"
	_last_progress_pos = global_position
	_perceive_timer = _rng.randf() * 0.5
	refresh_marker()


# ------------------------------------------------------------------ Bucle

func _physics_process(delta: float) -> void:
	if hidden_home:
		_check_wake()
		return
	var player := GameState.player as Node3D
	var dist_player := 999.0
	if player:
		dist_player = global_position.distance_to(player.global_position)
	# Lógica por estado
	state_timer -= delta
	match state:
		"static":
			_static_behaviour(delta, player, dist_player)
		"idle":
			velocity.x = 0.0
			velocity.z = 0.0
			if state_timer <= 0.0:
				_choose_next_activity()
		"walk", "go_deal", "go_home", "return":
			_follow_path(delta)
		"wait_deal":
			velocity.x = 0.0
			velocity.z = 0.0
			if not Customers.has_deal(npc_id):
				_start_wander()
		"flee":
			var away := (global_position - threat_pos)
			away.y = 0.0
			_move_dir(away.normalized(), RUN, delta)
			model.pose = "panic" if state_timer > 3.0 else "normal"
			if state_timer <= 0.0:
				model.pose = "normal"
				_start_wander()
		"chase":
			_chase(delta, player, dist_player)
		"approach":
			_approach_search(delta, player, dist_player)
		"searching":
			velocity.x = 0.0
			velocity.z = 0.0
			if player:
				_face(player.global_position, delta)
			if Police.searching_officer != self:
				resume_patrol()
		"talk":
			velocity.x = 0.0
			velocity.z = 0.0
			if player:
				_face(player.global_position, delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	# Animación (se omite si está lejos)
	if dist_player < 60.0:
		_anim_speed = lerpf(_anim_speed, Vector2(velocity.x, velocity.z).length(), delta * 8.0)
		model.animate(delta, _anim_speed)
		_social(delta, player, dist_player)
	if role == "police":
		_perceive(delta, player, dist_player)
	if role == "mugger":
		_mugger_logic(player, dist_player)


func _choose_next_activity() -> void:
	if role == "customer" and Customers.has_deal(npc_id):
		_go_to_deal()
		return
	if not _is_active_hour() and not (role == "police" or role == "mugger"):
		_go_home()
		return
	_start_wander()


func _is_active_hour() -> bool:
	var h := GameState.hour()
	if active_hours.x <= active_hours.y:
		return h >= active_hours.x and h < active_hours.y
	return h >= active_hours.x or h < active_hours.y


func _start_wander() -> void:
	if GameState.world == null:
		return
	var target: Vector3 = GameState.world.nav.random_point(district, _rng)
	if target == Vector3.ZERO:
		state = "idle"
		state_timer = 5.0
		return
	set_path(GameState.world.nav.find_path(global_position, target))
	state = "walk"
	move_speed = WALK * _rng.randf_range(0.85, 1.2)


func set_path(p: PackedVector3Array) -> void:
	path = p
	path_i = 0
	# Saltar el primer punto si ya estamos más cerca del segundo
	if path.size() > 1 and global_position.distance_to(path[1]) < path[0].distance_to(path[1]):
		path_i = 1
	_stuck_timer = 0.0
	_last_progress_pos = global_position


func _follow_path(delta: float) -> void:
	if path_i >= path.size():
		_arrived()
		return
	var target := path[path_i]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		path_i += 1
		return
	_move_dir(to.normalized(), move_speed, delta)
	_open_doors_nearby()
	_check_stuck(delta)


func _arrived() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	match state:
		"go_deal":
			state = "wait_deal"
			model.pose = "cross"
			var mp: Dictionary = GameState.world.get_meeting_point_data(String(Customers.get_deal(npc_id).get("location", "")))
			if mp.has("yaw"):
				rotation.y = float(mp["yaw"])
		"go_home":
			_hide_home()
		"return":
			state = "idle"
			state_timer = 1.0
		_:
			state = "idle"
			state_timer = _rng.randf_range(2.0, 7.0)
			if role == "customer" and Customers.has_deal(npc_id):
				state_timer = 0.1


func _move_dir(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length_squared() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))


func _face(p: Vector3, delta: float) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 6.0, 0.0, 1.0))


func _check_stuck(delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer > 1.5:
		if global_position.distance_to(_last_progress_pos) < 0.4:
			# Atascado: saltar al siguiente punto o teletransportar al punto actual si persiste
			path_i += 1
			if path_i < path.size() and global_position.distance_to(path[path_i]) > 30.0:
				global_position = path[path_i - 1] + Vector3.UP * 0.2
		_stuck_timer = 0.0
		_last_progress_pos = global_position


func _open_doors_nearby() -> void:
	if role != "police" and role != "mugger":
		return
	if GameState.world == null:
		return
	for d in GameState.world.doors:
		if is_instance_valid(d) and not d.is_open and d.global_position.distance_to(global_position) < 1.8:
			d.open_for_npc(global_position)


# ------------------------------------------------------------------ Horarios / casa

func _go_home() -> void:
	if GameState.world == null:
		return
	var home: Vector3 = GameState.world.nav.random_point(district, _rng)
	set_path(GameState.world.nav.find_path(global_position, home))
	state = "go_home"
	move_speed = WALK


func _hide_home() -> void:
	hidden_home = true
	visible = false
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = 0
	velocity = Vector3.ZERO


func _check_wake() -> void:
	if Engine.get_physics_frames() % 60 != 0:
		return
	var wants_out := _is_active_hour() or (role == "customer" and Customers.has_deal(npc_id))
	if wants_out:
		hidden_home = false
		visible = true
		collision_layer = Geo.LAYER_NPC
		state = "idle"
		state_timer = 0.5
		refresh_marker()


# ------------------------------------------------------------------ Clientes

func _go_to_deal() -> void:
	var dl := Customers.get_deal(npc_id)
	if dl.is_empty() or GameState.world == null:
		return
	var mp: Dictionary = GameState.world.get_meeting_point_data(String(dl.get("location", "")))
	if mp.is_empty():
		state = "wait_deal"
		return
	set_path(GameState.world.nav.find_path(global_position, mp["pos"]))
	state = "go_deal"
	move_speed = WALK * 1.3


func on_deal_scheduled() -> void:
	if hidden_home:
		hidden_home = false
		visible = true
		collision_layer = Geo.LAYER_NPC
	if state in ["idle", "walk", "go_home"]:
		_go_to_deal()
	refresh_marker()


func refresh_marker() -> void:
	if model == null:
		return
	if role == "customer":
		if Customers.has_deal(npc_id):
			model.set_marker("$", Color(0.4, 1.0, 0.4))
		elif not Customers.is_unlocked(npc_id):
			model.set_marker("?", Color(1.0, 0.85, 0.3))
		else:
			model.set_marker("")
	elif role == "quest" or role == "shopkeeper":
		var has_quest := Quests.pending_talk(npc_id).size() > 0 or Quests.pending_deliveries(npc_id).size() > 0
		var offers := Quests.offers_for(npc_id).size() > 0
		if has_quest:
			model.set_marker("!", Color(1.0, 0.8, 0.2))
		elif offers:
			model.set_marker("?", Color(0.5, 0.8, 1.0))
		else:
			model.set_marker("")


# ------------------------------------------------------------------ Estático

func _static_behaviour(delta: float, player: Node3D, dist: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if global_position.distance_to(anchor) > 0.5:
		global_position = anchor
	if player and dist < 4.0 and not talking:
		model.look_at_point(player.global_position + Vector3.UP * 1.6, 1.0)
		if dist < 2.5:
			_face(player.global_position, delta * 0.5)
	else:
		model.look_at_point(Vector3.ZERO, 0.0)
		rotation.y = lerp_angle(rotation.y, anchor_yaw, clampf(delta * 2.0, 0.0, 1.0))


# ------------------------------------------------------------------ Social

func _social(delta: float, player: Node3D, dist: float) -> void:
	_greet_cooldown -= delta
	if player == null or state in ["flee", "chase"]:
		return
	if dist < 3.5:
		model.look_at_point(player.global_position + Vector3.UP * 1.6, 0.8)
		if _greet_cooldown <= 0.0 and role in ["pedestrian", "customer"] and _rng.randf() < 0.3:
			var lines := ["Hola.", "Buenas.", "¿Qué tal?", "Hace buen día.", "..."]
			if GameState.is_night():
				lines = ["Buenas noches.", "Es tarde...", "..."]
			if Police.wanted >= Police.Wanted.PURSUIT:
				lines = ["¡Aléjate de mí!", "¡Llamaré a la policía!"]
			model.say(lines[_rng.randi() % lines.size()], 2.5)
			_greet_cooldown = 25.0
	elif state != "static":
		model.look_at_point(Vector3.ZERO, 0.0)
	# Huir de persecuciones cercanas
	if role == "pedestrian" and Police.wanted >= Police.Wanted.PURSUIT and dist < 10.0 and state != "flee":
		_flee_from(player.global_position, 5.0)


func _flee_from(pos: Vector3, duration: float) -> void:
	threat_pos = pos
	state = "flee"
	state_timer = duration


## El jugador empuja / golpea a este NPC.
func on_shoved(player: Node3D) -> void:
	var push := (global_position - player.global_position)
	push.y = 0.0
	velocity += push.normalized() * 5.0 + Vector3.UP * 2.5
	match role:
		"police":
			model.say("¡Agresión a un agente!", 3.0)
			Police.player_attacked_officer(self)
		"mugger":
			mugger_hits += 1
			model.say("¡Ay!" if mugger_hits < 2 else "¡Vale, vale, me largo!", 2.0)
			if mugger_hits >= 2:
				_flee_from(player.global_position, 8.0)
				get_tree().create_timer(8.0, false).timeout.connect(queue_free)
		"shopkeeper", "quest", "employee":
			model.say("¡Eh! ¿Qué haces?", 2.5)
			angry_until = GameState.absolute_minute() + 60
			Police.report_illegal_activity(global_position, 14.0, "agresión")
		_:
			model.say("¡Socorro!", 2.5)
			angry_until = GameState.absolute_minute() + 180
			if role == "customer" and Customers.is_unlocked(npc_id):
				Customers._change_rel(npc_id, -10)
			Police.report_illegal_activity(global_position, 16.0, "agresión")
			_flee_from(player.global_position, 6.0)


func react_witness(pos: Vector3) -> void:
	if state in ["static", "talk", "wait_deal"] or role == "police":
		return
	model.say("!", 1.5)
	model.look_at_point(pos + Vector3.UP, 1.0)


func is_angry() -> bool:
	return angry_until > GameState.absolute_minute()


func begin_talk() -> void:
	talking = true
	if state != "static":
		set_meta("prev_state", state)
		state = "talk"
	model.pose = "talk"


func end_talk() -> void:
	talking = false
	model.pose = "normal"
	if state == "talk":
		var prev := String(get_meta("prev_state", "idle"))
		state = prev if prev in ["wait_deal", "walk"] else "idle"
		state_timer = 1.0
		if prev == "walk" and path_i >= path.size():
			state = "idle"
	refresh_marker()


func leave_after_deal() -> void:
	model.pose = "normal"
	model.say("¡Nos vemos!", 2.5)
	state = "idle"
	state_timer = 2.0
	refresh_marker()


# ------------------------------------------------------------------ Interacción

func get_prompt(_player: Node) -> String:
	if role == "mugger":
		return ""
	match role:
		"customer":
			if Customers.has_deal(npc_id):
				return "Hablar con %s (entrega pendiente)" % display_name
			if not Customers.is_unlocked(npc_id):
				return "Hablar con %s (cliente potencial)" % display_name
		"police":
			return "Hablar con el agente"
		"employee":
			return "Hablar con %s (empleado)" % display_name
	return "Hablar con %s" % display_name


func interact(_player: Node) -> void:
	Events.request_ui.emit("dialogue", {"npc": self})


# ------------------------------------------------------------------ Policía

func _perceive(delta: float, player: Node3D, dist: float) -> void:
	_perceive_timer -= delta
	if _perceive_timer > 0.0 or player == null:
		return
	_perceive_timer = 0.4
	var vis: float = player.call("visibility") if player.has_method("visibility") else 1.0
	var view_range := (24.0 if not GameState.is_night() else 15.0) * vis
	if dist > view_range:
		return
	var to := (player.global_position - global_position)
	to.y = 0.0
	var fwd := -global_basis.z
	if dist > 4.0 and fwd.dot(to.normalized()) < 0.25:
		return
	if not GameState.world.has_line_of_sight(global_position + Vector3.UP * 1.6, player.global_position + Vector3.UP * 1.2):
		return
	Police.officer_sees_player(self)


func alert_to_player() -> void:
	if Police.wanted >= Police.Wanted.PURSUIT:
		chase_player()
	else:
		approach_for_search()


func chase_player() -> void:
	if state == "chase":
		return
	state = "chase"
	model.say("¡Alto, policía!", 2.5)
	_repath_timer = 0.0


var _repath_timer := 0.0


func _chase(delta: float, player: Node3D, dist: float) -> void:
	if player == null:
		return
	if Police.wanted < Police.Wanted.PURSUIT:
		resume_patrol()
		return
	_repath_timer -= delta
	var direct: bool = dist < 14.0 and GameState.world.has_line_of_sight(global_position + Vector3.UP * 1.4, player.global_position + Vector3.UP * 1.2)
	if direct:
		var to := player.global_position - global_position
		to.y = 0.0
		_move_dir(to.normalized(), POLICE_RUN, delta)
		_open_doors_nearby()
		if dist < 1.6:
			Police.arrest()
			resume_patrol()
	else:
		if _repath_timer <= 0.0:
			_repath_timer = 1.5
			set_path(GameState.world.nav.find_path(global_position, player.global_position))
		move_speed = POLICE_RUN
		if path_i < path.size():
			var target := path[path_i]
			var to2 := target - global_position
			to2.y = 0.0
			if to2.length() < 0.8:
				path_i += 1
			else:
				_move_dir(to2.normalized(), POLICE_RUN, delta)
				_open_doors_nearby()
				_check_stuck(delta)


func approach_for_search() -> void:
	if state in ["approach", "searching", "chase"]:
		return
	state = "approach"
	model.say("¡Eh, usted! Un momento.", 2.5)


func _approach_search(delta: float, player: Node3D, dist: float) -> void:
	if player == null:
		return
	if Police.wanted >= Police.Wanted.PURSUIT:
		chase_player()
		return
	if Police.wanted == Police.Wanted.NONE:
		resume_patrol()
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if dist > 30.0:
		resume_patrol()
		return
	if dist < 2.0:
		state = "searching"
		model.pose = "talk"
		Police.begin_search(self)
		return
	_move_dir(to.normalized(), WALK * 2.0, delta)
	_open_doors_nearby()


func resume_patrol() -> void:
	model.pose = "normal"
	if state in ["chase", "approach", "searching"]:
		state = "idle"
		state_timer = 2.0


func dispatch_to(pos: Vector3) -> void:
	if state in ["chase", "approach", "searching"]:
		return
	set_path(GameState.world.nav.find_path(global_position, pos))
	state = "walk"
	move_speed = WALK * 2.2


# ------------------------------------------------------------------ Atracador

func _mugger_logic(player: Node3D, dist: float) -> void:
	if player == null or state == "flee":
		return
	if state != "chase_mug":
		state = "chase_mug"
	var to := player.global_position - global_position
	to.y = 0.0
	_move_dir(to.normalized(), RUN * 0.95, get_physics_process_delta_time())
	_open_doors_nearby()
	if dist < 1.4:
		var stolen := int(GameState.cash * 0.25)
		if stolen > 0:
			GameState.cash -= stolen
			Events.money_changed.emit(GameState.cash, GameState.bank)
			Events.toast("¡Te han atracado! Te han robado $%d." % stolen, "warn")
		else:
			Events.toast("El atracador se va: no llevabas efectivo.", "info")
		model.say("¡Gracias por la donación!", 2.0)
		_flee_from(player.global_position, 10.0)
		get_tree().create_timer(10.0, false).timeout.connect(queue_free)
	elif dist > 60.0:
		queue_free()
