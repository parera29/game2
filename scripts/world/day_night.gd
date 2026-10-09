class_name DayNight
extends Node3D
## Ciclo de día y noche: sol/luna, cielo procedural, niebla, luz ambiental,
## farolas, ventanas iluminadas (night_factor) y ambiente sonoro.

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var _lights_on := false
var _night := 0.0

const DAY_TOP := Color(0.32, 0.52, 0.85)
const DAY_HOR := Color(0.72, 0.8, 0.88)
const DUSK_TOP := Color(0.3, 0.32, 0.55)
const DUSK_HOR := Color(0.98, 0.58, 0.35)
const NIGHT_TOP := Color(0.015, 0.02, 0.06)
const NIGHT_HOR := Color(0.06, 0.08, 0.16)


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 1.0
	add_child(sun)
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	apply_settings()
	Events.settings_changed.connect(apply_settings)
	_update(true)


func apply_settings() -> void:
	env.ssao_enabled = bool(Settings.get_value("ssao", true))
	env.glow_enabled = bool(Settings.get_value("glow", true))
	var sh := int(Settings.get_value("shadows", 2))
	sun.shadow_enabled = sh > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sh >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 140.0 if sh >= 2 else 70.0
	var vd := float(Settings.get_value("view_distance", 220.0))
	env.fog_density = clampf(0.55 / vd, 0.0015, 0.008)


func _process(_delta: float) -> void:
	_update(false)


func _update(force: bool) -> void:
	var m := GameState.minute
	var h := m / 60.0
	# Elevación solar: amanece a las 6:00 y anochece a las 20:00
	var day_t := clampf((h - 6.0) / 14.0, 0.0, 1.0)
	var elev := sin(day_t * PI)
	var is_day := h >= 6.0 and h <= 20.0
	var night := 0.0
	if h >= 19.0 and h < 21.0:
		night = (h - 19.0) / 2.0
	elif h >= 21.0 or h < 5.0:
		night = 1.0
	elif h >= 5.0 and h < 7.0:
		night = 1.0 - (h - 5.0) / 2.0
	night = smoothstep(0.0, 1.0, night)
	_night = night
	RenderingServer.global_shader_parameter_set("night_factor", night)
	var dusk := clampf(1.0 - absf(elev) * 3.0, 0.0, 1.0) * (1.0 if is_day else 0.0)
	if is_day:
		var az := lerpf(-1.9, 1.9, day_t)
		sun.rotation = Vector3(-maxf(elev, 0.05) * 1.2 - 0.05, az, 0.0)
		sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.6, 0.35), dusk)
		sun.light_energy = lerpf(0.15, 1.25, clampf(elev * 2.0, 0.0, 1.0))
	else:
		# Luna
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.light_color = Color(0.55, 0.65, 0.95)
		sun.light_energy = 0.18
	var top := DAY_TOP.lerp(DUSK_TOP, dusk).lerp(NIGHT_TOP, night)
	var hor := DAY_HOR.lerp(DUSK_HOR, dusk * (1.0 - night)).lerp(NIGHT_HOR, night)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.1)
	sky_mat.ground_bottom_color = top.darkened(0.5)
	sky_mat.sun_angle_max = 20.0 if is_day else 2.0
	env.ambient_light_energy = lerpf(1.0, 0.45, night)
	env.fog_light_color = hor
	env.tonemap_exposure = lerpf(1.0, 1.25, night)
	var want_lights := night > 0.35
	if want_lights != _lights_on or force:
		_lights_on = want_lights
		for l in get_tree().get_nodes_in_group("streetlights"):
			(l as Light3D).visible = want_lights
	if GameState.world and GameState.world.lamp_material:
		GameState.world.lamp_material.emission_energy_multiplier = night * 5.0
	var p := GameState.player
	if p:
		Audio.set_ambient("interior" if p.get("is_indoors") else ("night" if night > 0.5 else "day"))


func night_factor() -> float:
	return _night
