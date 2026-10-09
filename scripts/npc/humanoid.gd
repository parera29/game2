class_name Humanoid
extends Node3D
## Modelo humanoide low-poly estilizado, construido con primitivas y animado
## proceduralmente (caminar, correr, idle, hablar, gesto de pánico).

var skin := Color("#e0b48c")
var shirt := Color("#3f6fb5")
var pants := Color("#2b2f3a")
var hair := Color("#4a3020")
var female := false
var role := "pedestrian"

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _phase := 0.0
var _idle_t := 0.0
var _look_target := Vector3.ZERO
var _look_weight := 0.0
var _bubble: Label3D
var _bubble_timer := 0.0
var _marker: Label3D
var pose := "normal"     # normal, talk, panic, sit


func build(look: Dictionary, p_role: String = "pedestrian") -> void:
	role = p_role
	skin = Color(String(look.get("skin", "#e0b48c")))
	shirt = Color(String(look.get("shirt", "#3f6fb5")))
	pants = Color(String(look.get("pants", "#2b2f3a")))
	hair = Color(String(look.get("hair", "#4a3020")))
	female = bool(look.get("female", false))
	var skin_m := Mats.color(skin, 0.7)
	var shirt_m := Mats.color(shirt, 0.85)
	var pants_m := Mats.color(pants, 0.85)
	var hair_m := Mats.color(hair, 0.9)
	var shoe_m := Mats.color(Color(0.12, 0.12, 0.13), 0.6)
	var s := 0.94 if female else 1.0

	_hips = Node3D.new()
	_hips.position.y = 0.92 * s
	add_child(_hips)
	# Piernas
	_leg_l = _limb(_hips, Vector3(-0.11, 0, 0), 0.085, 0.86 * s, pants_m, shoe_m, true)
	_leg_r = _limb(_hips, Vector3(0.11, 0, 0), 0.085, 0.86 * s, pants_m, shoe_m, true)
	# Torso
	_torso = Node3D.new()
	_hips.add_child(_torso)
	var torso_w := 0.4 if female else 0.46
	var t := Geo.box(_torso, Vector3(torso_w, 0.58 * s, 0.24), Vector3(0, 0.3 * s, 0), shirt_m, false)
	t.scale = Vector3(1, 1, 1)
	Geo.box(_torso, Vector3(torso_w * 0.9, 0.12, 0.22), Vector3(0, 0.02, 0), pants_m, false)
	if role == "police":
		Geo.box(_torso, Vector3(torso_w + 0.01, 0.06, 0.25), Vector3(0, 0.05, 0), Mats.color(Color(0.1, 0.1, 0.1)), false)
		Geo.box(_torso, Vector3(0.07, 0.08, 0.02), Vector3(-0.12, 0.45 * s, -0.125), Mats.color(Color(0.95, 0.8, 0.2), 0.3, 0.8), false)
	# Brazos
	_arm_l = _limb(_torso, Vector3(-(torso_w * 0.5 + 0.06), 0.55 * s, 0), 0.06, 0.62 * s, shirt_m, skin_m, false)
	_arm_r = _limb(_torso, Vector3(torso_w * 0.5 + 0.06, 0.55 * s, 0), 0.06, 0.62 * s, shirt_m, skin_m, false)
	# Cabeza
	_head = Node3D.new()
	_head.position.y = 0.62 * s
	_torso.add_child(_head)
	Geo.cylinder(_head, 0.06, 0.1, Vector3(0, 0.03, 0), skin_m, false)
	var hm := Geo.sphere(_head, 0.15, Vector3(0, 0.2, 0), skin_m, 14)
	hm.scale = Vector3(0.95, 1.1, 1.0)
	# Ojos y cejas (mirando a -Z)
	var eye_w := Mats.color(Color(0.97, 0.97, 0.97), 0.4)
	var eye_b := Mats.color(Color(0.08, 0.08, 0.1), 0.2)
	for x in [-0.055, 0.055]:
		Geo.sphere(_head, 0.03, Vector3(x, 0.22, -0.135), eye_w, 6)
		Geo.sphere(_head, 0.016, Vector3(x, 0.22, -0.16), eye_b, 6)
		Geo.box(_head, Vector3(0.05, 0.012, 0.01), Vector3(x, 0.265, -0.15), hair_m, false)
	Geo.box(_head, Vector3(0.06, 0.012, 0.01), Vector3(0, 0.13, -0.148), Mats.color(skin.darkened(0.4)), false)
	Geo.box(_head, Vector3(0.025, 0.05, 0.03), Vector3(0, 0.18, -0.155), skin_m, false)
	# Pelo / gorra
	if role == "police":
		Geo.cylinder(_head, 0.16, 0.09, Vector3(0, 0.36, 0), Mats.color(Color(0.1, 0.14, 0.3)), false)
		Geo.box(_head, Vector3(0.24, 0.02, 0.12), Vector3(0, 0.32, -0.14), Mats.color(Color(0.08, 0.08, 0.1)), false)
	else:
		var hcap := Geo.sphere(_head, 0.158, Vector3(0, 0.25, 0.015), hair_m, 12)
		hcap.scale = Vector3(1.0, 0.8, 1.0)
		if female:
			Geo.box(_head, Vector3(0.3, 0.3, 0.1), Vector3(0, 0.12, 0.1), hair_m, false)
	_marker = Label3D.new()
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.font_size = 96
	_marker.pixel_size = 0.005
	_marker.outline_size = 16
	_marker.position = Vector3(0, 2.25 * s, 0)
	_marker.visible = false
	add_child(_marker)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 40
	_bubble.pixel_size = 0.004
	_bubble.outline_size = 10
	_bubble.position = Vector3(0, 2.05 * s, 0)
	_bubble.visible = false
	_bubble.width = 600
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_bubble)
	for c in find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).visibility_range_end = 90.0


func _limb(parent: Node3D, pos: Vector3, radius: float, length: float, mat: Material, end_mat: Material, is_leg: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var m := Geo.cylinder(pivot, radius, length - 0.06, Vector3(0, -(length - 0.06) * 0.5, 0), mat, false, radius * 0.85, 8)
	m.name = "limb"
	if is_leg:
		Geo.box(pivot, Vector3(0.13, 0.08, 0.26), Vector3(0, -length + 0.04, -0.05), end_mat, false)
	else:
		Geo.sphere(pivot, radius * 1.1, Vector3(0, -length + 0.02, 0), end_mat, 6)
	return pivot


func set_marker(text: String, color: Color = Color.WHITE) -> void:
	if _marker == null:
		return
	_marker.visible = text != ""
	_marker.text = text
	_marker.modulate = color


func say(text: String, duration: float = 3.0) -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = duration


func look_at_point(p: Vector3, weight: float) -> void:
	_look_target = p
	_look_weight = weight


func animate(delta: float, speed: float) -> void:
	if _hips == null:
		return
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
	var moving := speed > 0.15
	if moving:
		_phase += delta * speed * 2.6
		var amp := clampf(speed / 4.0, 0.3, 1.0) * (1.0 if speed < 4.5 else 1.3)
		var sw := sin(_phase) * 0.65 * amp
		_leg_l.rotation.x = sw
		_leg_r.rotation.x = -sw
		_arm_l.rotation.x = -sw * 0.8
		_arm_r.rotation.x = sw * 0.8
		_arm_l.rotation.z = 0.0
		_arm_r.rotation.z = 0.0
		_hips.position.y = 0.92 * (0.94 if female else 1.0) + abs(cos(_phase)) * 0.04 * amp
		_torso.rotation.x = -0.12 * amp if speed > 4.5 else -0.03
	else:
		_idle_t += delta
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, delta * 8.0)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, delta * 8.0)
		var breathe := sin(_idle_t * 1.8) * 0.02
		_torso.rotation.x = lerpf(_torso.rotation.x, breathe, delta * 6.0)
		match pose:
			"talk":
				_arm_r.rotation.x = -0.5 + sin(_idle_t * 3.0) * 0.25
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.0, delta * 6.0)
			"panic":
				_arm_l.rotation.x = -2.6 + sin(_idle_t * 12.0) * 0.2
				_arm_r.rotation.x = -2.6 - sin(_idle_t * 12.0) * 0.2
			"cross":
				_arm_l.rotation.x = -0.9
				_arm_r.rotation.x = -0.9
				_arm_l.rotation.z = -0.6
				_arm_r.rotation.z = 0.6
			_:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, sin(_idle_t * 1.8) * 0.04, delta * 6.0)
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -sin(_idle_t * 1.8) * 0.04, delta * 6.0)
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -0.06, delta * 6.0)
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.06, delta * 6.0)
	# Giro de cabeza hacia el objetivo
	if _look_weight > 0.01:
		var local := to_local(_look_target)
		var yaw := atan2(-local.x, -local.z)
		yaw = clampf(yaw, -1.2, 1.2)
		_head.rotation.y = lerpf(_head.rotation.y, yaw * _look_weight, delta * 6.0)
	else:
		_head.rotation.y = lerpf(_head.rotation.y, 0.0, delta * 4.0)
