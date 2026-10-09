class_name Interactable
extends StaticBody3D
## Objeto genérico con el que el jugador puede interactuar (E).
## El texto y la acción se definen con Callables al crearlo.

var prompt: String = "Interactuar"
var prompt_func: Callable
var action: Callable


func get_prompt(player: Node) -> String:
	if prompt_func.is_valid():
		return String(prompt_func.call(player))
	return prompt


func interact(player: Node) -> void:
	if action.is_valid():
		action.call(player)


static func create(parent: Node, size: Vector3, pos: Vector3, p_prompt: String, p_action: Callable, p_prompt_func: Callable = Callable()) -> Interactable:
	var it := Interactable.new()
	it.collision_layer = Geo.LAYER_INTERACT
	it.collision_mask = 0
	it.prompt = p_prompt
	it.action = p_action
	it.prompt_func = p_prompt_func
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	it.position = pos
	parent.add_child(it)
	return it
