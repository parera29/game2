class_name UIWindow
extends Control
## Base de las ventanas modales. El UIManager las crea, les pasa el payload
## y gestiona el ratón, la pausa y el cierre.

var ui: Node
var payload: Variant
var dim := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dim:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.45)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
	build()


func build() -> void:
	pass


func close() -> void:
	if ui:
		ui.close()


## Crea una ventana centrada con título y botón de cierre. Devuelve el contenedor del cuerpo.
func make_window(size: Vector2, title: String) -> VBoxContainer:
	var w := UITheme.window(size, title, close)
	var root: Control = w["root"]
	add_child(root)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	return w["body"]
