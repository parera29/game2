class_name Inventory
extends RefCounted
## Inventario por casillas con límite de peso opcional.
## Cada casilla es null o un Dictionary {"id": String, "qty": int, "data": Dictionary}.
## Dos pilas solo se combinan si tienen el mismo id y los mismos datos (calidad, efectos...).

signal changed

var slots: Array = []
var max_weight: float = -1.0   # -1 = sin límite
var title: String = ""


func _init(size: int = 8, p_max_weight: float = -1.0, p_title: String = "") -> void:
	slots.resize(size)
	max_weight = p_max_weight
	title = p_title


func size() -> int:
	return slots.size()


func resize(new_size: int) -> void:
	# Nunca destruimos objetos al encoger: solo se permite crecer.
	if new_size > slots.size():
		slots.resize(new_size)
		changed.emit()


static func normalize_data(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	if d.has("quality"):
		d["quality"] = snappedf(float(d["quality"]), 0.01)
	if d.has("effects"):
		var e: Array = d["effects"].duplicate()
		e.sort()
		d["effects"] = e
	return d


func get_slot(i: int) -> Variant:
	if i < 0 or i >= slots.size():
		return null
	return slots[i]


func is_empty_slot(i: int) -> bool:
	return get_slot(i) == null


func total_weight() -> float:
	var w := 0.0
	for s in slots:
		if s != null:
			w += ItemDB.weight(s["id"]) * int(s["qty"])
	return w


func free_weight() -> float:
	if max_weight < 0.0:
		return INF
	return max_weight - total_weight()


## Cantidad que cabe realmente (por casillas y por peso).
func can_add(id: String, qty: int, data: Dictionary = {}) -> int:
	if qty <= 0:
		return 0
	var nd := normalize_data(data)
	var max_s := ItemDB.max_stack(id)
	var room := 0
	for s in slots:
		if s == null:
			room += max_s
		elif s["id"] == id and s["data"] == nd:
			room += max_s - int(s["qty"])
	var fit := mini(room, qty)
	var w := ItemDB.weight(id)
	if max_weight >= 0.0 and w > 0.0:
		fit = mini(fit, int(floor((free_weight() + 0.0001) / w)))
	return maxi(fit, 0)


## Añade objetos. Devuelve la cantidad que NO se pudo añadir.
func add(id: String, qty: int, data: Dictionary = {}) -> int:
	if not ItemDB.exists(id):
		push_warning("Inventory.add: objeto desconocido %s" % id)
		return qty
	var nd := normalize_data(data)
	var to_add := can_add(id, qty, nd)
	var remaining := to_add
	var max_s := ItemDB.max_stack(id)
	# Primero completar pilas existentes
	for i in slots.size():
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == id and s["data"] == nd and int(s["qty"]) < max_s:
			var n := mini(max_s - int(s["qty"]), remaining)
			s["qty"] = int(s["qty"]) + n
			remaining -= n
	# Luego casillas vacías
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i] == null:
			var n := mini(max_s, remaining)
			slots[i] = {"id": id, "qty": n, "data": nd.duplicate(true)}
			remaining -= n
	if to_add > 0:
		changed.emit()
	return qty - to_add + remaining


## Cuenta objetos por id. Si data no es null solo cuenta pilas con esos datos exactos.
func count(id: String, data: Variant = null) -> int:
	var n := 0
	var nd: Variant = null if data == null else normalize_data(data)
	for s in slots:
		if s != null and s["id"] == id and (nd == null or s["data"] == nd):
			n += int(s["qty"])
	return n


func has(id: String, qty: int = 1) -> bool:
	return count(id) >= qty


## Elimina qty objetos (de cualquier pila si data es null). Devuelve true si se eliminó todo.
func remove(id: String, qty: int, data: Variant = null) -> bool:
	if count(id, data) < qty:
		return false
	var nd: Variant = null if data == null else normalize_data(data)
	var remaining := qty
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == id and (nd == null or s["data"] == nd):
			var n := mini(int(s["qty"]), remaining)
			s["qty"] = int(s["qty"]) - n
			remaining -= n
			if int(s["qty"]) <= 0:
				slots[i] = null
	changed.emit()
	return true


## Quita qty de una casilla concreta. Devuelve el diccionario extraído (o null).
func take_from_slot(i: int, qty: int) -> Variant:
	var s = get_slot(i)
	if s == null or qty <= 0:
		return null
	var n := mini(qty, int(s["qty"]))
	var out := {"id": s["id"], "qty": n, "data": s["data"].duplicate(true)}
	s["qty"] = int(s["qty"]) - n
	if int(s["qty"]) <= 0:
		slots[i] = null
	changed.emit()
	return out


func set_slot(i: int, value: Variant) -> void:
	if i < 0 or i >= slots.size():
		return
	slots[i] = value
	changed.emit()


## Mueve/combina/intercambia una casilla hacia otra (posiblemente de otro inventario).
## Respeta el límite de peso del destino. Devuelve true si algo cambió.
func move_slot(from_i: int, to_inv: Inventory, to_i: int, qty: int = -1) -> bool:
	var src = get_slot(from_i)
	if src == null:
		return false
	if to_inv == self and from_i == to_i:
		return false
	var amount: int = int(src["qty"]) if qty < 0 else mini(qty, int(src["qty"]))
	var dst = to_inv.get_slot(to_i)
	var w := ItemDB.weight(src["id"])
	var same_inv := to_inv == self
	if dst == null:
		var fit := amount
		if not same_inv and to_inv.max_weight >= 0.0 and w > 0.0:
			fit = mini(fit, int(floor((to_inv.free_weight() + 0.0001) / w)))
		if fit <= 0:
			return false
		var moved = take_from_slot(from_i, fit)
		to_inv.slots[to_i] = moved
		to_inv.changed.emit()
		return true
	if dst["id"] == src["id"] and dst["data"] == src["data"]:
		var space := ItemDB.max_stack(src["id"]) - int(dst["qty"])
		var fit2 := mini(space, amount)
		if not same_inv and to_inv.max_weight >= 0.0 and w > 0.0:
			fit2 = mini(fit2, int(floor((to_inv.free_weight() + 0.0001) / w)))
		if fit2 <= 0:
			return false
		take_from_slot(from_i, fit2)
		dst["qty"] = int(dst["qty"]) + fit2
		to_inv.changed.emit()
		return true
	# Intercambio completo (solo si se mueve la pila entera)
	if amount != int(src["qty"]):
		return false
	if not same_inv:
		var src_w := w * int(src["qty"])
		var dst_w := ItemDB.weight(dst["id"]) * int(dst["qty"])
		if to_inv.max_weight >= 0.0 and to_inv.total_weight() - dst_w + src_w > to_inv.max_weight + 0.0001:
			return false
		if max_weight >= 0.0 and total_weight() - src_w + dst_w > max_weight + 0.0001:
			return false
	slots[from_i] = dst
	to_inv.slots[to_i] = src
	changed.emit()
	if not same_inv:
		to_inv.changed.emit()
	return true


## Transfiere una casilla completa a otro inventario (shift+clic). Devuelve cantidad movida.
func quick_transfer(from_i: int, to_inv: Inventory) -> int:
	var s = get_slot(from_i)
	if s == null:
		return 0
	var left := to_inv.add(s["id"], int(s["qty"]), s["data"])
	var moved := int(s["qty"]) - left
	if moved > 0:
		take_from_slot(from_i, moved)
	return moved


func find_first(predicate: Callable) -> int:
	for i in slots.size():
		if slots[i] != null and predicate.call(slots[i]):
			return i
	return -1


func clear() -> void:
	for i in slots.size():
		slots[i] = null
	changed.emit()


func to_dict() -> Dictionary:
	var arr: Array = []
	for s in slots:
		arr.append(s.duplicate(true) if s != null else null)
	return {"slots": arr, "max_weight": max_weight, "title": title}


func from_dict(d: Dictionary) -> void:
	var arr: Array = d.get("slots", [])
	slots.resize(maxi(slots.size(), arr.size()))
	for i in slots.size():
		slots[i] = null
	for i in arr.size():
		var s = arr[i]
		if s is Dictionary and ItemDB.exists(String(s.get("id", ""))):
			slots[i] = {"id": String(s["id"]), "qty": int(s.get("qty", 1)), "data": normalize_data(s.get("data", {}))}
	max_weight = float(d.get("max_weight", max_weight))
	changed.emit()
