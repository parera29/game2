extends Node
## Base de datos de objetos: carga data/items.json, genera iconos procedurales
## y calcula nombres/valores de productos con datos dinámicos (calidad, efectos).

const ITEMS_PATH := "res://data/items.json"

const EFFECTS := {
	"fizzy":   {"name": "Burbujeante", "value": 0.15, "color": Color("#e04f4f")},
	"smooth":  {"name": "Suave", "value": 0.12, "color": Color("#7fe0c8")},
	"zesty":   {"name": "Picante", "value": 0.18, "color": Color("#ff8a3d")},
	"giggly":  {"name": "Risueño", "value": 0.22, "color": Color("#e78ad8")},
	"glowing": {"name": "Brillante", "value": 0.30, "color": Color("#b6ff4a")},
	"golden":  {"name": "Dorado", "value": 0.45, "color": Color("#f0b429")},
}

## Producto base -> valor por unidad y nombres
const PRODUCTS := {
	"glimmer": {"name": "Glimmer", "base_value": 32, "raw": "glimmer_bud", "bag": "glimmer_bag", "jar": "glimmer_jar"},
	"azure":   {"name": "Azure", "base_value": 75, "raw": "azure_shard", "bag": "azure_bag", "jar": "azure_jar"},
}

const CATEGORY_NAMES := {
	"tool": "Herramienta", "supply": "Suministro", "additive": "Aditivo", "packaging": "Embalaje",
	"product": "Producto", "kit": "Instalación", "consumable": "Consumible", "equipment": "Equipo",
	"quest": "Misión", "junk": "Objeto",
}

var items: Dictionary = {}
var _icon_cache: Dictionary = {}


func _ready() -> void:
	_load_items()


func _load_items() -> void:
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		push_error("ItemDB: no se pudo abrir %s" % ITEMS_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ItemDB: items.json inválido")
		return
	items = parsed


func exists(id: String) -> bool:
	return items.has(id)


func get_def(id: String) -> Dictionary:
	if not items.has(id):
		push_warning("ItemDB: objeto desconocido '%s'" % id)
		return {"name": id, "category": "junk", "weight": 0.0, "stack": 1, "price": 0, "icon": {"shape": "box", "color": "#ff00ff"}}
	return items[id]


func get_prop(id: String, key: String, default: Variant = null) -> Variant:
	return get_def(id).get(key, default)


func max_stack(id: String) -> int:
	return int(get_def(id).get("stack", 1))


func weight(id: String) -> float:
	return float(get_def(id).get("weight", 0.0))


func price(id: String) -> int:
	return int(get_def(id).get("price", 0))


func is_contraband(id: String) -> bool:
	return bool(get_def(id).get("contraband", false))


func category(id: String) -> String:
	return String(get_def(id).get("category", "junk"))


func is_product(id: String) -> bool:
	return category(id) == "product"


func is_packed_product(id: String) -> bool:
	return is_product(id) and bool(get_def(id).get("packed", false))


func product_type(id: String) -> String:
	return String(get_def(id).get("product", ""))


func units_of(id: String) -> int:
	return int(get_def(id).get("units", 1))


func display_name(id: String, data: Dictionary = {}) -> String:
	var base := String(get_def(id).get("name", id))
	if is_product(id) and data.has("effects"):
		var eff: Array = data.get("effects", [])
		if eff.size() > 0:
			var names: Array[String] = []
			for e in eff:
				if EFFECTS.has(e):
					names.append(EFFECTS[e]["name"])
			base += " " + " ".join(names)
	if id == "watering_can" and data.has("water"):
		base += " (%d/%d)" % [int(data["water"]), int(get_def(id).get("uses", 6))]
	return base


func describe(id: String, data: Dictionary = {}) -> String:
	var d := get_def(id)
	var lines: Array[String] = []
	lines.append(String(d.get("desc", "")))
	if is_product(id):
		var q := float(data.get("quality", 0.5))
		lines.append("Calidad: %d%%  (%s)" % [int(q * 100.0), quality_label(q)])
		var eff: Array = data.get("effects", [])
		if eff.size() > 0:
			var names: Array[String] = []
			for e in eff:
				names.append(EFFECTS.get(e, {"name": e})["name"])
			lines.append("Efectos: " + ", ".join(names))
		if is_packed_product(id):
			lines.append("Valor estimado: $%d" % (unit_value(product_type(id), data) * units_of(id)))
	if is_contraband(id):
		lines.append("[Ilegal: la policía lo confiscará]")
	lines.append("Peso: %.2f kg" % weight(id))
	return "\n".join(lines)


func quality_label(q: float) -> String:
	if q >= 0.9:
		return "Excelente"
	if q >= 0.7:
		return "Alta"
	if q >= 0.45:
		return "Normal"
	if q >= 0.25:
		return "Baja"
	return "Pésima"


## Valor de mercado de una unidad de producto (sin modificadores de cliente).
func unit_value(product: String, data: Dictionary) -> int:
	if not PRODUCTS.has(product):
		return 0
	var base := float(PRODUCTS[product]["base_value"])
	var q := float(data.get("quality", 0.5))
	var mult := 0.6 + 0.8 * q
	var bonus := 0.0
	for e in data.get("effects", []):
		bonus += float(EFFECTS.get(e, {"value": 0.0})["value"])
	return int(round(base * mult * (1.0 + bonus)))


func packed_id(product: String, packaging: String) -> String:
	if not PRODUCTS.has(product):
		return ""
	return String(PRODUCTS[product]["bag" if packaging == "baggie" else "jar"])


func raw_id(product: String) -> String:
	return String(PRODUCTS.get(product, {}).get("raw", ""))


func color_of(id: String) -> Color:
	return Color(String(get_def(id).get("icon", {}).get("color", "#ffffff")))


# ------------------------------------------------------------------ Iconos

func get_icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var icon_def: Dictionary = get_def(id).get("icon", {"shape": "box", "color": "#ffffff"})
	var tex := IconFactory.make(String(icon_def.get("shape", "box")), Color(String(icon_def.get("color", "#ffffff"))))
	_icon_cache[id] = tex
	return tex


func all_ids() -> Array:
	return items.keys()
