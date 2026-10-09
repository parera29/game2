class_name IconFactory
extends RefCounted
## Genera iconos de inventario de 64x64 a partir de una forma y un color.
## Evita depender de imágenes externas y garantiza que no haya referencias rotas.

const S := 64


static func make(shape: String, color: Color) -> ImageTexture:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := color.darkened(0.35)
	var light := color.lightened(0.35)
	match shape:
		"bag":
			_poly(img, [Vector2(18, 20), Vector2(46, 20), Vector2(50, 54), Vector2(14, 54)], color)
			_rect(img, Rect2i(18, 14, 28, 6), dark)
			_rect(img, Rect2i(20, 26, 6, 20), light)
		"jar":
			_rect(img, Rect2i(18, 18, 28, 38), color)
			_rect(img, Rect2i(16, 10, 32, 9), Color("#d0d4d8"))
			_rect(img, Rect2i(21, 24, 5, 26), light)
		"pot":
			_poly(img, [Vector2(12, 28), Vector2(52, 28), Vector2(46, 56), Vector2(18, 56)], color)
			_rect(img, Rect2i(10, 24, 44, 7), dark)
			_circle(img, Vector2(32, 16), 9, Color("#5fbf4a"))
		"sack":
			_poly(img, [Vector2(16, 18), Vector2(48, 18), Vector2(54, 56), Vector2(10, 56)], color)
			_rect(img, Rect2i(22, 10, 20, 9), dark)
			_rect(img, Rect2i(20, 32, 24, 10), light)
		"seed":
			for p in [Vector2(22, 24), Vector2(40, 22), Vector2(30, 38), Vector2(44, 42), Vector2(20, 46)]:
				_circle(img, p, 7, color)
				_circle(img, p - Vector2(2, 2), 2.5, light)
		"box":
			_rect(img, Rect2i(12, 20, 40, 34), color)
			_rect(img, Rect2i(12, 14, 40, 8), light)
			_rect(img, Rect2i(29, 14, 6, 40), dark)
		"bottle":
			_rect(img, Rect2i(22, 24, 20, 32), color)
			_rect(img, Rect2i(27, 10, 10, 15), dark)
			_rect(img, Rect2i(25, 32, 4, 18), light)
		"can":
			_rect(img, Rect2i(19, 14, 26, 42), color)
			_rect(img, Rect2i(19, 12, 26, 4), Color("#c0c4c8"))
			_rect(img, Rect2i(19, 54, 26, 4), Color("#c0c4c8"))
			_rect(img, Rect2i(23, 20, 5, 30), light)
		"leaf":
			_poly(img, [Vector2(32, 6), Vector2(44, 24), Vector2(40, 44), Vector2(32, 56), Vector2(24, 44), Vector2(20, 24)], color)
			_poly(img, [Vector2(14, 26), Vector2(28, 36), Vector2(22, 46)], dark)
			_poly(img, [Vector2(50, 26), Vector2(36, 36), Vector2(42, 46)], dark)
			_rect(img, Rect2i(31, 14, 2, 40), light)
		"crystal":
			_poly(img, [Vector2(32, 6), Vector2(46, 26), Vector2(32, 58), Vector2(18, 26)], color)
			_poly(img, [Vector2(32, 6), Vector2(38, 26), Vector2(32, 58)], light)
			_poly(img, [Vector2(14, 40), Vector2(22, 32), Vector2(24, 52)], dark)
		"light":
			_rect(img, Rect2i(26, 30, 12, 26), Color("#3a3f45"))
			_poly(img, [Vector2(16, 10), Vector2(48, 10), Vector2(40, 30), Vector2(24, 30)], color)
			_rect(img, Rect2i(22, 12, 20, 4), light)
		"gum":
			_rect(img, Rect2i(10, 22, 44, 20), color)
			_rect(img, Rect2i(10, 22, 12, 20), dark)
			_rect(img, Rect2i(26, 26, 22, 4), light)
		"chili":
			_poly(img, [Vector2(14, 18), Vector2(26, 14), Vector2(48, 40), Vector2(52, 56), Vector2(38, 46)], color)
			_rect(img, Rect2i(10, 10, 10, 8), Color("#3e8e3a"))
		"pack":
			_rect(img, Rect2i(14, 16, 36, 40), color)
			_rect(img, Rect2i(18, 36, 28, 14), dark)
			_rect(img, Rect2i(22, 8, 20, 10), dark)
		"shoe":
			_poly(img, [Vector2(8, 34), Vector2(30, 30), Vector2(56, 42), Vector2(56, 50), Vector2(8, 50)], color)
			_rect(img, Rect2i(8, 48, 48, 6), Color("#f2f2f2"))
			_rect(img, Rect2i(10, 24, 18, 12), dark)
		"doc":
			_rect(img, Rect2i(10, 16, 44, 32), color)
			_poly(img, [Vector2(10, 16), Vector2(54, 16), Vector2(32, 34)], color.darkened(0.15))
			_rect(img, Rect2i(26, 36, 12, 6), Color("#b03030"))
		"watch":
			_circle(img, Vector2(32, 36), 18, color)
			_circle(img, Vector2(32, 36), 13, Color("#f5f0e1"))
			_rect(img, Rect2i(31, 26, 2, 11), Color("#222"))
			_rect(img, Rect2i(31, 35, 9, 2), Color("#222"))
			_rect(img, Rect2i(28, 10, 8, 8), dark)
		_:
			_rect(img, Rect2i(14, 14, 36, 36), color)
	_outline(img)
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, r: Rect2i, c: Color) -> void:
	img.fill_rect(r.intersection(Rect2i(0, 0, S, S)), c)


static func _circle(img: Image, center: Vector2, radius: float, c: Color) -> void:
	var r2 := radius * radius
	for y in range(maxi(0, int(center.y - radius)), mini(S, int(center.y + radius) + 1)):
		for x in range(maxi(0, int(center.x - radius)), mini(S, int(center.x + radius) + 1)):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(center) <= r2:
				img.set_pixel(x, y, c)


static func _poly(img: Image, pts: Array, c: Color) -> void:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(p)
	var minp := Vector2(S, S)
	var maxp := Vector2.ZERO
	for p in poly:
		minp = minp.min(p)
		maxp = maxp.max(p)
	for y in range(maxi(0, int(minp.y)), mini(S, int(maxp.y) + 1)):
		for x in range(maxi(0, int(minp.x)), mini(S, int(maxp.x) + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, c)


## Contorno oscuro de 1 px para dar un aspecto de icono "cartoon".
static func _outline(img: Image) -> void:
	var src := img.duplicate() as Image
	var oc := Color(0.05, 0.05, 0.07, 0.95)
	for y in S:
		for x in S:
			if src.get_pixel(x, y).a > 0.1:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < S and ny < S and src.get_pixel(nx, ny).a > 0.1:
					near = true
					break
			if near:
				img.set_pixel(x, y, oc)
