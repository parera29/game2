extends Control
## Menú principal: continuar, nueva partida, cargar, opciones, ayuda y salir.
## Actúa como "gestor de UI" mínimo para reutilizar las ventanas de opciones y carga.

const WINDOWS := {
	"settings": "res://scripts/ui/settings_ui.gd",
	"saveload": "res://scripts/ui/saveload_ui.gd",
	"help": "res://scripts/ui/help_ui.gd",
	"confirm": "res://scripts/ui/confirm_ui.gd",
}

var hud = null
var current: Control = null
var _menu: VBoxContainer
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _buildings: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.time_running = false
	Audio.set_ambient("")
	Audio.set_siren(false)
	Audio.play_music(true)
	_rng.seed = 7
	var x := 0.0
	while x < 2400.0:
		var w := _rng.randf_range(60, 160)
		_buildings.append({"x": x, "w": w, "h": _rng.randf_range(120, 420), "seed": _rng.randi()})
		x += w + _rng.randf_range(4, 20)
	_build_menu()


func _build_menu() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_box = box
	var title := UITheme.shadow_label("REDMONT", 86, Color(1, 1, 1))
	box.add_child(title)
	var sub := UITheme.shadow_label("H U S T L E", 34, UITheme.ACCENT)
	box.add_child(sub)
	box.add_child(UITheme.label("Empieza desde cero. Construye un imperio. No te dejes atrapar.", 16, UITheme.TEXT_DIM))
	box.add_child(Control.new())
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	box.add_child(_menu)
	var latest := SaveSystem.latest_slot()
	if latest != "":
		var meta := SaveSystem.read_meta(latest)
		_add_button("Continuar  (día %s, %s)" % [str(meta.get("day", "?")), UITheme.money(int(meta.get("cash", 0)))], func() -> void: SaveSystem.load_game(latest))
	_add_button("Nueva partida", _new_game)
	var lb := _add_button("Cargar partida", func() -> void: open("saveload", {"mode": "load"}))
	lb.disabled = not SaveSystem.any_save()
	_add_button("Opciones", func() -> void: open("settings", {}))
	_add_button("Cómo se juega", func() -> void: open("help", {}))
	_add_button("Salir", func() -> void: get_tree().quit())
	var ver := UITheme.label("v1.0 · Godot %s · Juego de ficción: todos los productos y actividades son inventados." % Engine.get_version_info()["string"], 13, UITheme.TEXT_DIM)
	add_child(ver)
	_ver = ver


func _add_button(text: String, cb: Callable) -> Button:
	var b := UITheme.button(text, cb, 360)
	b.custom_minimum_size.y = 48
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu.add_child(b)
	return b


func _new_game() -> void:
	if SaveSystem.has_save("auto"):
		open("confirm", {"title": "Nueva partida", "text": "Empezarás de cero. Las partidas guardadas no se borran (el autoguardado se sobrescribirá al dormir).", "on_yes": SaveSystem.new_game})
	else:
		SaveSystem.new_game()


func open(ui_name: String, payload: Variant = null) -> void:
	close()
	var w: UIWindow = load(WINDOWS[ui_name]).new()
	w.ui = self
	w.payload = payload if payload != null else {}
	current = w
	add_child(w)


func close() -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and current:
		close()


var _box: VBoxContainer
var _ver: Label


func _process(delta: float) -> void:
	_t += delta
	_box.position = Vector2(110.0, maxf(20.0, (size.y - _box.size.y) * 0.5))
	_ver.position = Vector2(20.0, size.y - 34.0)
	queue_redraw()


func _draw() -> void:
	var sz := size
	# Cielo de atardecer
	var top := Color(0.06, 0.07, 0.16)
	var mid := Color(0.42, 0.2, 0.32)
	var hor := Color(0.95, 0.5, 0.3)
	var steps := 40
	for i in steps:
		var t := float(i) / steps
		var c := top.lerp(mid, t * 1.4) if t < 0.7 else mid.lerp(hor, (t - 0.7) / 0.3)
		draw_rect(Rect2(0, sz.y * t, sz.x, sz.y / steps + 1), c)
	draw_circle(Vector2(sz.x * 0.72, sz.y * 0.78), 90, Color(1.0, 0.65, 0.35, 0.9))
	# Silueta de la ciudad con ventanas encendidas
	var scroll := fmod(_t * 12.0, 1200.0)
	for b in _buildings:
		var bx: float = fmod(float(b["x"]) - scroll + 2400.0, 2400.0) - 200.0
		var bw: float = b["w"]
		var bh: float = b["h"]
		var r := Rect2(bx, sz.y - bh, bw, bh)
		draw_rect(r, Color(0.05, 0.05, 0.08))
		var rr := RandomNumberGenerator.new()
		rr.seed = int(b["seed"])
		var wy := sz.y - bh + 14.0
		while wy < sz.y - 20.0:
			var wx := bx + 10.0
			while wx < bx + bw - 16.0:
				if rr.randf() < 0.35:
					var flick := 0.75 + 0.25 * sin(_t * 0.5 + rr.randf() * 6.0)
					draw_rect(Rect2(wx, wy, 8, 11), Color(1.0, 0.8, 0.45, flick))
				wx += 16.0
			wy += 20.0
	draw_rect(Rect2(0, sz.y - 6, sz.x, 6), Color(0.02, 0.02, 0.03))
	# Viñeta para legibilidad del menú
	draw_rect(Rect2(0, 0, 620, sz.y), Color(0, 0, 0, 0.35))
