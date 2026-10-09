extends Node
## Estado global de la partida: dinero, tiempo, rango, estadísticas, distritos,
## inventario del jugador y ventajas. Se serializa con to_dict()/from_dict().

const START_CASH := 300
const MINUTES_PER_SECOND := 1.0       # 1 s real = 1 minuto de juego
const START_MINUTE := 7 * 60
const HOTBAR_SIZE := 8
const PLAYER_SLOTS := 20
const BASE_CARRY := 35.0
const BACKPACK_CARRY := 60.0
const DAILY_DEPOSIT_LIMIT := 10000
const PASS_OUT_MINUTE := 4 * 60       # a las 4:00 el jugador se desmaya si no ha dormido

const WEEKDAYS := ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

const RANKS := [
	{"name": "Novato", "xp": 0},
	{"name": "Buscavidas", "xp": 150},
	{"name": "Emprendedor", "xp": 500},
	{"name": "Proveedor", "xp": 1200},
	{"name": "Distribuidor", "xp": 2500},
	{"name": "Magnate", "xp": 5000},
	{"name": "Rey de Redmont", "xp": 9000},
]

## Distritos: rango requerido y rectángulo (x, z) en metros.
const DISTRICTS := {
	"northtown": {"name": "Northtown", "rank": 0, "rect": Rect2(-30, -30, 135.5, 135.5), "desc": "Barrio obrero. Aquí empieza todo."},
	"downtown": {"name": "Downtown", "rank": 1, "rect": Rect2(105.5, -30, 130, 135.5), "desc": "Centro comercial y de oficinas."},
	"docks": {"name": "Los Muelles", "rank": 2, "rect": Rect2(-30, 105.5, 135.5, 130), "desc": "Zona industrial portuaria."},
	"uptown": {"name": "Uptown", "rank": 3, "rect": Rect2(105.5, 105.5, 130, 130), "desc": "Barrio rico con mansiones."},
}

var cash: int = START_CASH
var bank: int = 0
var deposited_today: int = 0
var day: int = 1
var minute: float = START_MINUTE
var xp: int = 0
var rank: int = 0
var unlocked_districts: Array = ["northtown"]
var lockdowns: Dictionary = {}          # district -> minuto absoluto en que termina
var perks: Dictionary = {}
var flags: Dictionary = {}
var stats: Dictionary = {}
var player_inventory: Inventory
var listing_prices: Dictionary = {"glimmer": 40, "azure": 95}
var slept_today := true

var world: Node = null          # referencia al mundo cargado (World)
var player: Node = null
var time_running := false
var _minute_accum := 0.0
var _last_minute_int := -1


func _ready() -> void:
	reset()


func reset() -> void:
	cash = START_CASH
	bank = 0
	deposited_today = 0
	day = 1
	minute = START_MINUTE
	xp = 0
	rank = 0
	unlocked_districts = ["northtown"]
	lockdowns = {}
	perks = {}
	flags = {}
	slept_today = true
	listing_prices = {"glimmer": 40, "azure": 95}
	stats = {
		"deals": 0, "units_sold": 0, "revenue": 0, "expenses": 0, "arrests": 0,
		"harvests": 0, "packaged": 0, "mixed": 0, "samples_given": 0, "fines_paid": 0,
		"distance": 0.0, "max_cash": START_CASH, "quests_done": 0, "items_bought": 0,
	}
	player_inventory = Inventory.new(PLAYER_SLOTS, BASE_CARRY, "Mochila")
	_last_minute_int = int(minute)


func new_game_setup() -> void:
	reset()
	player_inventory.add("watering_can", 1, {"water": 0})
	player_inventory.add("snack", 2)


# ------------------------------------------------------------------ Tiempo

func _process(delta: float) -> void:
	if not time_running:
		return
	_minute_accum += delta * MINUTES_PER_SECOND
	while _minute_accum >= 1.0:
		_minute_accum -= 1.0
		_advance_minute()


func _advance_minute() -> void:
	minute += 1.0
	if minute >= 1440.0:
		minute -= 1440.0
		day += 1
		slept_today = false
		deposited_today = 0
	var m := int(minute)
	Events.minute_passed.emit(m, day)
	if m % 60 == 0:
		Events.hour_passed.emit(m / 60, day)
	_check_lockdowns()
	if m == PASS_OUT_MINUTE and not slept_today:
		_pass_out()


## Avanza el tiempo varios minutos de golpe (dormir, cárcel). Simula cada minuto
## para que cultivos, pedidos y empleados progresen correctamente.
func skip_minutes(count: int) -> void:
	for i in count:
		_advance_minute()


func absolute_minute() -> int:
	return (day - 1) * 1440 + int(minute)


func hour() -> int:
	return int(minute) / 60


func time_string() -> String:
	var m := int(minute)
	return "%02d:%02d" % [m / 60, m % 60]


func weekday_name() -> String:
	return WEEKDAYS[(day - 1) % 7]


func is_night() -> bool:
	var h := hour()
	return h >= 21 or h < 6


func is_curfew() -> bool:
	var h := hour()
	return h >= 22 or h < 5


## Duerme hasta las 7:00. Solo se llama desde una cama de una propiedad propia.
func sleep() -> void:
	var target := 7 * 60
	var cur := int(minute)
	var mins := target - cur
	if mins <= 0:
		mins += 1440
	skip_minutes(mins)
	slept_today = true
	Events.day_started.emit(day)
	Events.toast("Has dormido. %s, día %d - %s" % [weekday_name(), day, time_string()], "info")


func _pass_out() -> void:
	Events.toast("Te has desmayado de cansancio...", "warn")
	if world and world.has_method("on_player_passed_out"):
		world.on_player_passed_out()
	var lost := int(cash * 0.1)
	if lost > 0:
		cash -= lost
		Events.money_changed.emit(cash, bank)
		Events.toast("Al despertar te faltan $%d." % lost, "warn")
	sleep()


# ------------------------------------------------------------------ Dinero

func add_cash(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	cash += amount
	if reason == "sale":
		stats["revenue"] = int(stats["revenue"]) + amount
	stats["max_cash"] = maxi(int(stats["max_cash"]), cash + bank)
	Events.money_changed.emit(cash, bank)


func can_afford(amount: int) -> bool:
	return cash >= amount


func spend(amount: int, _reason: String = "") -> bool:
	if amount < 0:
		return false
	if cash < amount:
		Audio.play("error")
		Events.toast("No tienes suficiente efectivo ($%d)." % amount, "warn")
		return false
	cash -= amount
	stats["expenses"] = int(stats["expenses"]) + amount
	Events.money_changed.emit(cash, bank)
	return true


## Cobro forzoso (alquiler, multas). Si no llega el efectivo se toma del banco.
func charge(amount: int) -> int:
	var from_cash := mini(cash, amount)
	cash -= from_cash
	var rest := amount - from_cash
	var from_bank := mini(bank, rest)
	bank -= from_bank
	var paid := from_cash + from_bank
	stats["expenses"] = int(stats["expenses"]) + paid
	Events.money_changed.emit(cash, bank)
	return paid


func deposit(amount: int) -> bool:
	if amount <= 0 or amount > cash:
		return false
	if deposited_today + amount > DAILY_DEPOSIT_LIMIT:
		Events.toast("Límite diario de ingreso: $%d" % DAILY_DEPOSIT_LIMIT, "warn")
		return false
	cash -= amount
	bank += amount
	deposited_today += amount
	Events.money_changed.emit(cash, bank)
	return true


func withdraw(amount: int) -> bool:
	if amount <= 0 or amount > bank:
		return false
	bank -= amount
	cash += amount
	Events.money_changed.emit(cash, bank)
	return true


# ------------------------------------------------------------------ Progresión

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var new_rank := rank
	while new_rank + 1 < RANKS.size() and xp >= int(RANKS[new_rank + 1]["xp"]):
		new_rank += 1
	Events.xp_changed.emit(xp, new_rank)
	if new_rank != rank:
		rank = new_rank
		Audio.play("quest")
		Events.toast("¡Nuevo rango: %s!" % rank_name(), "quest")
		Events.rank_changed.emit(rank)
		_check_district_unlocks()


func rank_name(r: int = -1) -> String:
	if r < 0:
		r = rank
	return String(RANKS[clampi(r, 0, RANKS.size() - 1)]["name"])


func rank_progress() -> float:
	if rank + 1 >= RANKS.size():
		return 1.0
	var a := int(RANKS[rank]["xp"])
	var b := int(RANKS[rank + 1]["xp"])
	return clampf(float(xp - a) / float(b - a), 0.0, 1.0)


func _check_district_unlocks() -> void:
	for d in DISTRICTS:
		if not unlocked_districts.has(d) and rank >= int(DISTRICTS[d]["rank"]):
			unlocked_districts.append(d)
			Events.toast("Distrito desbloqueado: %s" % DISTRICTS[d]["name"], "quest")
			Events.district_unlocked.emit(d)


func is_district_unlocked(d: String) -> bool:
	return unlocked_districts.has(d)


func is_district_accessible(d: String) -> bool:
	return is_district_unlocked(d) and not is_locked_down(d)


func is_locked_down(d: String) -> bool:
	return lockdowns.has(d) and int(lockdowns[d]) > absolute_minute()


func lockdown(d: String, hours: int) -> void:
	if d == "northtown":
		return
	lockdowns[d] = absolute_minute() + hours * 60
	Events.toast("La policía ha cerrado %s durante %d horas." % [DISTRICTS[d]["name"], hours], "police")
	Events.district_unlocked.emit(d)   # fuerza a refrescar barreras


func _check_lockdowns() -> void:
	for d in lockdowns.keys():
		if int(lockdowns[d]) <= absolute_minute():
			lockdowns.erase(d)
			Events.toast("%s vuelve a ser accesible." % DISTRICTS[d]["name"], "info")
			Events.district_unlocked.emit(d)


func district_at(pos: Vector3) -> String:
	var p := Vector2(pos.x, pos.z)
	for d in ["downtown", "docks", "uptown"]:
		if (DISTRICTS[d]["rect"] as Rect2).has_point(p):
			return d
	return "northtown"


func max_carry() -> float:
	return BACKPACK_CARRY if perks.get("backpack", false) else BASE_CARRY


func apply_perk(perk: String) -> void:
	perks[perk] = true
	if perk == "backpack":
		player_inventory.max_weight = max_carry()
		player_inventory.changed.emit()


func stat_add(key: String, amount: Variant) -> void:
	stats[key] = stats.get(key, 0) + amount


# ------------------------------------------------------------------ Persistencia

func to_dict() -> Dictionary:
	return {
		"cash": cash, "bank": bank, "deposited_today": deposited_today,
		"day": day, "minute": minute, "xp": xp, "rank": rank,
		"unlocked_districts": unlocked_districts, "lockdowns": lockdowns,
		"perks": perks, "flags": flags, "stats": stats, "slept_today": slept_today,
		"listing_prices": listing_prices,
		"inventory": player_inventory.to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	cash = int(d.get("cash", START_CASH))
	bank = int(d.get("bank", 0))
	deposited_today = int(d.get("deposited_today", 0))
	day = int(d.get("day", 1))
	minute = float(d.get("minute", START_MINUTE))
	xp = int(d.get("xp", 0))
	rank = int(d.get("rank", 0))
	unlocked_districts = d.get("unlocked_districts", ["northtown"]).duplicate()
	lockdowns = d.get("lockdowns", {}).duplicate()
	perks = d.get("perks", {}).duplicate()
	flags = d.get("flags", {}).duplicate(true)
	slept_today = bool(d.get("slept_today", true))
	var saved_prices: Dictionary = d.get("listing_prices", {})
	for k in saved_prices:
		listing_prices[k] = int(saved_prices[k])
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	player_inventory.max_weight = max_carry()
	if d.has("inventory"):
		player_inventory.from_dict(d["inventory"])
	player_inventory.max_weight = max_carry()
	_last_minute_int = int(minute)
	Events.money_changed.emit(cash, bank)
	Events.xp_changed.emit(xp, rank)
