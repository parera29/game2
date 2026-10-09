class_name Mats
extends RefCounted
## Biblioteca de materiales con caché. Todos los materiales son procedurales
## (shaders propios), así que no hay texturas externas que puedan romperse.

const BUILDING_SHADER := preload("res://shaders/building.gdshader")
const ROAD_SHADER := preload("res://shaders/road.gdshader")
const SURFACE_SHADER := preload("res://shaders/surface.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")

enum Surf { SIDEWALK, GRASS, TILES, WOOD, CONCRETE, PLASTER, DIRT, CARPET }

static var _cache: Dictionary = {}


static func building(wall: Color, pattern: int = 1, trim: Color = Color(0.86, 0.83, 0.78), shop_front: bool = false,
		seed: float = 0.0, cell: Vector2 = Vector2(3.0, 3.2), lit: float = 0.4, windows: bool = true,
		roof: Color = Color(0.3, 0.3, 0.32)) -> ShaderMaterial:
	var key := "b|%s|%d|%s|%s|%.2f|%s|%.2f|%s|%s" % [wall.to_html(), pattern, trim.to_html(), shop_front, seed, cell, lit, windows, roof.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = BUILDING_SHADER
	m.set_shader_parameter("wall_color", wall)
	m.set_shader_parameter("trim_color", trim)
	m.set_shader_parameter("roof_color", roof)
	m.set_shader_parameter("pattern", float(pattern))
	m.set_shader_parameter("shop_front", 1.0 if shop_front else 0.0)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("cell", cell)
	m.set_shader_parameter("lit_ratio", lit)
	m.set_shader_parameter("windows", 1.0 if windows else 0.0)
	_cache[key] = m
	return m


static func road(axis: int) -> ShaderMaterial:
	var key := "road%d" % axis
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = ROAD_SHADER
	m.set_shader_parameter("axis", float(axis))
	_cache[key] = m
	return m


static func surface(mode: int, a: Color, b: Color = Color(0.5, 0.5, 0.5), scale: float = 1.0) -> ShaderMaterial:
	var key := "s|%d|%s|%s|%.2f" % [mode, a.to_html(), b.to_html(), scale]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("mode", float(mode))
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("scale", scale)
	_cache[key] = m
	return m


static func water() -> ShaderMaterial:
	if _cache.has("water"):
		return _cache["water"]
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	_cache["water"] = m
	return m


static func color(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key := "c|%s|%.2f|%.2f" % [c.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func emissive(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "e|%s|%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.7, 0.8, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.3
	_cache["glass"] = m
	return m


## Material con textura de texto para carteles (se genera una vez por texto).
static func sign_label(text: String, bg: Color, fg: Color) -> StandardMaterial3D:
	var key := "sign|%s|%s|%s" % [text, bg.to_html(), fg.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = bg
	m.emission_enabled = true
	m.emission = bg * 0.6
	_cache[key] = m
	return m
