class_name WorldItem
extends RigidBody3D
## Objeto de inventario tirado en el mundo. Se puede recoger con E y empujar.

var item_id := ""
var qty := 1
var data: Dictionary = {}
var quest_item := false


static func spawn(parent: Node, id: String, amount: int, item_data: Dictionary, pos: Vector3, impulse: Vector3 = Vector3.ZERO) -> WorldItem:
	var w := WorldItem.new()
	w.item_id = id
	w.qty = amount
	w.data = item_data.duplicate(true)
	parent.add_child(w)
	w.global_position = pos
	if impulse != Vector3.ZERO:
		w.apply_central_impulse(impulse)
	return w


func _ready() -> void:
	add_to_group("world_items")
	collision_layer = Geo.LAYER_PROPS
	collision_mask = Geo.LAYER_WORLD | Geo.LAYER_PROPS | Geo.LAYER_VEHICLE
	mass = clampf(ItemDB.weight(item_id) * qty, 0.2, 20.0)
	continuous_cd = true
	var size := _visual_size()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	var col := ItemDB.color_of(item_id)
	Geo.box(self, size, Vector3.ZERO, Mats.color(col.darkened(0.15), 0.7), false)
	Geo.box(self, Vector3(size.x * 1.02, size.y * 0.25, size.z * 1.02), Vector3(0, size.y * 0.2, 0), Mats.color(col.lightened(0.3), 0.6), false)
	var spr := Sprite3D.new()
	spr.texture = ItemDB.get_icon(item_id)
	spr.pixel_size = 0.006
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spr.position = Vector3(0, size.y * 0.5 + 0.25, 0)
	spr.no_depth_test = false
	spr.shaded = false
	add_child(spr)


func _visual_size() -> Vector3:
	match ItemDB.category(item_id):
		"kit":
			return Vector3(0.6, 0.4, 0.5)
		"supply":
			return Vector3(0.35, 0.3, 0.25)
		"tool", "equipment":
			return Vector3(0.35, 0.2, 0.2)
		_:
			return Vector3(0.22, 0.16, 0.18)


func get_prompt(_player: Node) -> String:
	var n := ItemDB.display_name(item_id, data)
	return "Recoger %s%s" % [n, " x%d" % qty if qty > 1 else ""]


func interact(_player: Node) -> void:
	var inv: Inventory = GameState.player_inventory
	var left := inv.add(item_id, qty, data)
	var taken := qty - left
	if taken <= 0:
		Audio.play("error", -6.0)
		Events.toast("No tienes espacio o vas demasiado cargado.", "warn")
		return
	Audio.play("pickup")
	Events.toast("Recogido: %s x%d" % [ItemDB.display_name(item_id, data), taken], "info")
	if left > 0:
		qty = left
	else:
		queue_free()


func to_save() -> Dictionary:
	return {"id": item_id, "qty": qty, "data": data, "pos": [global_position.x, global_position.y, global_position.z]}
