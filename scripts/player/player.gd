class_name Player
extends CharacterBody3D
## Controlador en primera persona: andar, correr (resistencia), saltar, agacharse,
## mirar con el ratón, interactuar (E), barra rápida, usar/soltar objetos,
## agarrar y lanzar objetos físicos, empujar NPC y linterna.

const WALK_SPEED := 4.3
const SPRINT_SPEED := 7.2
const CROUCH_SPEED := 2.2
const JUMP_VELOCITY := 6.6
const ACCEL := 12.0
const AIR_ACCEL := 3.0
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const EYE_OFFSET := 0.15
const INTERACT_DISTANCE := 3.0

var input_enabled := true
var stamina := 100.0
var speed_boost := 0.0
var crouching := false
var hotbar_index := 0
var current_prompt := ""
var current_target: Object = null
var indoor_zones: Array = []
var is_indoors := false
var flashlight_on := false

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var flashlight: SpotLight3D
var hand: Node3D
var _hand_item_id := "__none__"
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _bob_t := 0.0
var _step_accum := 0.0
var _grabbed: RigidBody3D = null
var _shove_cooldown := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	collision_layer = Geo.LAYER_PLAYER
	collision_mask = Geo.LAYER_WORLD | Geo.LAYER_NPC | Geo.LAYER_PROPS | Geo.LAYER_VEHICLE
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(60)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.35
	_capsule.height = STAND_HEIGHT
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = STAND_HEIGHT * 0.5
	add_child(_collision)
	head = Node3D.new()
	head.position.y = STAND_HEIGHT - EYE_OFFSET
	add_child(head)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.05
	head.add_child(camera)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -INTERACT_DISTANCE)
	ray.collision_mask = Geo.LAYER_WORLD | Geo.LAYER_NPC | Geo.LAYER_PROPS | Geo.LAYER_INTERACT
	ray.add_exception(self)
	ray.collide_with_areas = false
	camera.add_child(ray)
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 28.0
	flashlight.light_energy = 2.5
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	flashlight.visible = false
	flashlight.position = Vector3(0.2, -0.15, 0)
	camera.add_child(flashlight)
	hand = Node3D.new()
	hand.position = Vector3(0.42, -0.36, -0.75)
	hand.scale = Vector3.ONE * 0.6
	camera.add_child(hand)
	apply_settings()
	Events.settings_changed.connect(apply_settings)
	GameState.player = self
	_last_pos = global_position


func _exit_tree() -> void:
	if GameState.player == self:
		GameState.player = null


func apply_settings() -> void:
	camera.fov = float(Settings.get_value("fov", 75.0))
	camera.far = float(Settings.get_value("view_distance", 220.0)) + 40.0


# ------------------------------------------------------------------ Entrada

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := float(Settings.get_value("mouse_sensitivity", 0.25)) * 0.01
		var inv_y := -1.0 if Settings.get_value("invert_y", false) else 1.0
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens * inv_y, deg_to_rad(-88), deg_to_rad(88))
		return
	if event.is_action_pressed("interact"):
		_do_interact()
	elif event.is_action_pressed("drop"):
		drop_held(Input.is_key_pressed(KEY_SHIFT))
	elif event.is_action_pressed("use"):
		_use_pressed()
	elif event.is_action_released("use"):
		_release_grab(Vector3.ZERO)
	elif event.is_action_pressed("throw"):
		if _grabbed:
			_release_grab(-camera.global_basis.z * 9.0)
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("scroll_up"):
		select_slot(wrapi(hotbar_index - 1, 0, GameState.HOTBAR_SIZE))
	elif event.is_action_pressed("scroll_down"):
		select_slot(wrapi(hotbar_index + 1, 0, GameState.HOTBAR_SIZE))
	else:
		for i in GameState.HOTBAR_SIZE:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				select_slot(i)
				break


func select_slot(i: int) -> void:
	hotbar_index = clampi(i, 0, GameState.HOTBAR_SIZE - 1)
	Audio.play("hover", -8.0)
	_refresh_hand()


func held_slot() -> Variant:
	return GameState.player_inventory.get_slot(hotbar_index)


func held_item_id() -> String:
	var s = held_slot()
	return String(s["id"]) if s != null else ""


# ------------------------------------------------------------------ Física

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity += get_gravity() * delta
	var dir := Vector3.ZERO
	var want_sprint := false
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
		want_sprint = Input.is_action_pressed("sprint") and iv.y < 0.0
		if Input.is_action_just_pressed("jump") and on_floor and not crouching:
			velocity.y = JUMP_VELOCITY
		_set_crouch(Input.is_action_pressed("crouch"))
	var speed := WALK_SPEED
	var sprinting := want_sprint and stamina > 1.0 and not crouching and dir != Vector3.ZERO
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	if GameState.perks.get("shoes", false):
		speed *= 1.2
	if speed_boost > 0.0:
		speed *= 1.25
		speed_boost -= delta
	if sprinting and speed_boost <= 0.0:
		stamina = maxf(0.0, stamina - 16.0 * delta)
	else:
		stamina = minf(100.0, stamina + (22.0 if not sprinting else 0.0) * delta)
	var accel := ACCEL if on_floor else AIR_ACCEL
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))
	move_and_slide()
	# Empujar objetos físicos al chocar
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if body is RigidBody3D and body != _grabbed:
			(body as RigidBody3D).apply_central_impulse(-c.get_normal() * 0.6)
	_update_bob(delta, on_floor, Vector2(velocity.x, velocity.z).length())
	_update_grab(delta)
	_shove_cooldown = maxf(0.0, _shove_cooldown - delta)
	var moved := global_position.distance_to(_last_pos)
	if moved < 5.0:
		GameState.stats["distance"] = float(GameState.stats.get("distance", 0.0)) + moved
	_last_pos = global_position
	if global_position.y < -30.0:
		Events.toast("Has caído fuera del mapa. Volviendo...", "warn")
		if GameState.world:
			GameState.world.respawn_player()


func _set_crouch(want: bool) -> void:
	if want == crouching:
		return
	if not want:
		# Comprobar que hay sitio para levantarse
		var space := get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := CapsuleShape3D.new()
		sh.radius = 0.3
		sh.height = STAND_HEIGHT
		q.shape = sh
		q.transform = Transform3D(Basis(), global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.05, 0))
		q.collision_mask = Geo.LAYER_WORLD
		q.exclude = [get_rid()]
		if space.intersect_shape(q, 1).size() > 0:
			return
	crouching = want
	var h := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_capsule.height = h
	_collision.position.y = h * 0.5
	var tw := create_tween()
	tw.tween_property(head, "position:y", h - EYE_OFFSET, 0.15)


func _update_bob(delta: float, on_floor: bool, hspeed: float) -> void:
	if on_floor and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.9
		_step_accum += hspeed * delta
		var stride := 1.6 if hspeed > 5.0 else 1.25
		if _step_accum >= stride:
			_step_accum = 0.0
			Audio.play("step", -14.0 if crouching else -8.0, randf_range(0.85, 1.15))
	else:
		_bob_t = lerpf(_bob_t, 0.0, delta * 4.0)
	if Settings.get_value("head_bob", true):
		camera.position.y = sin(_bob_t * 2.0) * 0.035 * clampf(hspeed / 4.0, 0.0, 1.5)
		camera.position.x = cos(_bob_t) * 0.025 * clampf(hspeed / 4.0, 0.0, 1.5)
	else:
		camera.position = Vector3.ZERO
	hand.position.y = -0.36 + sin(_bob_t * 2.0) * 0.01


func _process(_delta: float) -> void:
	_update_target()
	is_indoors = indoor_zones.size() > 0
	if _hand_item_id != held_item_id():
		_refresh_hand()


# ------------------------------------------------------------------ Interacción

func _resolve_interactable(obj: Object) -> Object:
	var n := obj as Node
	var depth := 0
	while n != null and depth < 4:
		if n.has_meta("interact_target"):
			return n.get_meta("interact_target")
		if n.has_method("get_prompt") and n.has_method("interact"):
			return n
		n = n.get_parent()
		depth += 1
	return null


func _update_target() -> void:
	current_target = null
	current_prompt = ""
	if not input_enabled:
		return
	if _grabbed:
		current_prompt = "[Soltar clic izq.] Soltar   [Clic der.] Lanzar"
		return
	ray.force_raycast_update()
	if ray.is_colliding():
		var t := _resolve_interactable(ray.get_collider())
		if t != null:
			var p := String(t.call("get_prompt", self))
			if p != "":
				current_target = t
				current_prompt = p


func _do_interact() -> void:
	if current_target != null and is_instance_valid(current_target):
		current_target.call("interact", self)


func _use_pressed() -> void:
	# 1) Agarrar objeto físico
	ray.force_raycast_update()
	if ray.is_colliding():
		var col := ray.get_collider()
		if col is RigidBody3D and (col as Node).is_in_group("grabbable"):
			_grabbed = col
			_grabbed.gravity_scale = 0.0
			_grabbed.linear_damp = 6.0
			_grabbed.angular_damp = 6.0
			Audio.play("pickup", -10.0)
			return
		# 2) Empujar a un NPC con la mano vacía
		var npc := _resolve_npc(col)
		if npc != null and held_item_id() == "" and _shove_cooldown <= 0.0:
			_shove_cooldown = 0.6
			npc.call("on_shoved", self)
			Audio.play("punch", -4.0)
			return
	# 3) Usar el objeto en la mano
	use_held()


func _resolve_npc(obj: Object) -> Node:
	var n := obj as Node
	while n != null:
		if n.is_in_group("npc"):
			return n
		n = n.get_parent()
	return null


func _update_grab(delta: float) -> void:
	if _grabbed == null:
		return
	if not is_instance_valid(_grabbed):
		_grabbed = null
		return
	var target := camera.global_position - camera.global_basis.z * 1.8
	var diff := target - _grabbed.global_position
	if diff.length() > 3.5:
		_release_grab(Vector3.ZERO)
		return
	_grabbed.linear_velocity = diff * 12.0
	_grabbed.angular_velocity = _grabbed.angular_velocity.lerp(Vector3.ZERO, delta * 5.0)


func _release_grab(impulse: Vector3) -> void:
	if _grabbed == null or not is_instance_valid(_grabbed):
		_grabbed = null
		return
	_grabbed.gravity_scale = 1.0
	_grabbed.linear_damp = 0.0
	_grabbed.angular_damp = 0.0
	if impulse != Vector3.ZERO:
		_grabbed.linear_velocity = Vector3.ZERO
		_grabbed.apply_central_impulse(impulse * _grabbed.mass)
		Audio.play("drop", -6.0)
	_grabbed = null


func use_held() -> void:
	var s = held_slot()
	if s == null:
		return
	var id := String(s["id"])
	match ItemDB.category(id):
		"consumable":
			stamina = minf(100.0, stamina + float(ItemDB.get_prop(id, "stamina", 0)))
			speed_boost = maxf(speed_boost, float(ItemDB.get_prop(id, "speed_boost", 0)))
			GameState.player_inventory.take_from_slot(hotbar_index, 1)
			Audio.play("eat")
			Events.toast("Has consumido: %s" % ItemDB.display_name(id), "info")
		"equipment":
			var perk := String(ItemDB.get_prop(id, "perk", ""))
			if GameState.perks.get(perk, false):
				Events.toast("Ya tienes esa mejora.", "info")
				return
			GameState.player_inventory.take_from_slot(hotbar_index, 1)
			GameState.apply_perk(perk)
			Audio.play("quest")
			Events.toast("Mejora equipada: %s" % ItemDB.display_name(id), "quest")
		"tool":
			if id == "flashlight":
				toggle_flashlight()
			elif id == "watering_can":
				Events.toast("Regadera: %d/%d usos. Apunta a una maceta y pulsa E." % [int(s["data"].get("water", 0)), int(ItemDB.get_prop(id, "uses", 6))], "info")
		_:
			pass


func toggle_flashlight() -> void:
	if not GameState.player_inventory.has("flashlight"):
		Events.toast("No tienes linterna (se vende en el Gas-Mart).", "info")
		flashlight_on = false
	else:
		flashlight_on = not flashlight_on
		Audio.play("click", -6.0)
	flashlight.visible = flashlight_on


## Suelta el objeto de la mano (una unidad, o toda la pila con Mayús).
func drop_held(whole_stack: bool = false) -> void:
	var s = held_slot()
	if s == null or GameState.world == null:
		return
	var n: int = int(s["qty"]) if whole_stack else 1
	var taken = GameState.player_inventory.take_from_slot(hotbar_index, n)
	if taken == null:
		return
	var pos := camera.global_position - camera.global_basis.z * 0.8
	WorldItem.spawn(GameState.world.items_root, taken["id"], int(taken["qty"]), taken["data"], pos, -camera.global_basis.z * 1.5)
	Audio.play("drop")


func _refresh_hand() -> void:
	_hand_item_id = held_item_id()
	for c in hand.get_children():
		c.queue_free()
	if _hand_item_id == "":
		return
	var col := ItemDB.color_of(_hand_item_id)
	var mat := Mats.color(col, 0.6)
	match ItemDB.category(_hand_item_id):
		"tool":
			if _hand_item_id == "flashlight":
				var m := Geo.cylinder(hand, 0.035, 0.28, Vector3.ZERO, Mats.color(Color(0.2, 0.2, 0.22), 0.4, 0.6), false)
				m.rotation.x = PI * 0.5
				Geo.cylinder(hand, 0.05, 0.06, Vector3(0, 0, -0.16), mat, false).rotation.x = PI * 0.5
			else:
				Geo.cylinder(hand, 0.09, 0.2, Vector3.ZERO, mat, false)
				var spout := Geo.cylinder(hand, 0.015, 0.25, Vector3(0.0, 0.05, -0.15), mat, false)
				spout.rotation.x = -1.0
		"kit":
			Geo.box(hand, Vector3(0.3, 0.2, 0.25), Vector3(0, -0.02, 0), Mats.color(Color(0.65, 0.5, 0.32), 0.9), false)
		_:
			Geo.box(hand, Vector3(0.12, 0.12, 0.08), Vector3.ZERO, mat, false)
	var spr := Sprite3D.new()
	spr.texture = ItemDB.get_icon(_hand_item_id)
	spr.pixel_size = 0.0018
	spr.position = Vector3(0, 0.13, 0)
	spr.no_depth_test = true
	spr.render_priority = 10
	spr.shaded = false
	hand.add_child(spr)
	for c in hand.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ------------------------------------------------------------------ Varios

## Factor de visibilidad para la policía y testigos (0.4 - 1.0).
func visibility() -> float:
	var v := 1.0
	if crouching:
		v *= 0.6
	if GameState.is_night() and not flashlight_on:
		v *= 0.7
	return clampf(v, 0.4, 1.0)


func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	_release_grab(Vector3.ZERO)
	global_position = pos
	rotation.y = yaw
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	_last_pos = pos


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		_release_grab(Vector3.ZERO)
		velocity.x = 0.0
		velocity.z = 0.0


func enter_zone(zone: Node) -> void:
	if not indoor_zones.has(zone):
		indoor_zones.append(zone)


func exit_zone(zone: Node) -> void:
	indoor_zones.erase(zone)


func current_property() -> String:
	for z in indoor_zones:
		if is_instance_valid(z) and z.has_meta("property"):
			return String(z.get_meta("property"))
	return ""
