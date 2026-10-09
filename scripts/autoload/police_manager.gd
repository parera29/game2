extends Node
## Sistema policial ficticio: sospecha, testigos, registros, persecuciones,
## multas, confiscación y cierres temporales de distritos.

enum Wanted { NONE, INVESTIGATING, PURSUIT, MANHUNT }

const WANTED_NAMES := ["", "Bajo sospecha", "Persecución", "Busca y captura"]
const SEARCH_DURATION := 3.0
const ESCAPE_MINUTES := 25

var suspicion: float = 0.0
var wanted: int = Wanted.NONE
var last_seen_abs: int = -9999
var searching_officer: Node = null
var search_timer := 0.0
var crackdown_until: int = 0
var _pending_reports: Array = []      # [{"at": abs_minute, "pos": Vector3, "severity": float}]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Events.minute_passed.connect(_on_minute)
	Events.day_started.connect(_on_day_started)


func reset() -> void:
	suspicion = 0.0
	wanted = Wanted.NONE
	last_seen_abs = -9999
	searching_officer = null
	search_timer = 0.0
	crackdown_until = 0
	_pending_reports.clear()
	_emit()


func _emit() -> void:
	Events.heat_changed.emit(suspicion, wanted)
	Audio.set_siren(wanted >= Wanted.PURSUIT)


func is_crackdown() -> bool:
	return crackdown_until > GameState.absolute_minute()


func add_suspicion(amount: float) -> void:
	if is_crackdown():
		amount *= 1.6
	suspicion = clampf(suspicion + amount, 0.0, 100.0)
	_emit()


func set_wanted(level: int) -> void:
	level = clampi(level, 0, 3)
	if level == wanted:
		return
	var prev := wanted
	wanted = level
	if level > prev:
		match level:
			Wanted.INVESTIGATING:
				Events.toast("La policía sospecha de ti.", "police")
			Wanted.PURSUIT:
				Events.toast("¡La policía te persigue! Rompe la línea de visión para escapar.", "police")
			Wanted.MANHUNT:
				Events.toast("¡Busca y captura! Llegan refuerzos.", "police")
				if GameState.world:
					GameState.world.spawn_reinforcements(GameState.player.global_position if GameState.player else Vector3.ZERO)
	elif level == Wanted.NONE:
		Events.toast("Has despistado a la policía.", "info")
	_emit()


# ------------------------------------------------------------------ Percepción

## Llamado por el mundo cuando hay actividad ilegal (ventas, muestras, peleas).
func report_illegal_activity(pos: Vector3, radius: float, kind: String) -> void:
	if GameState.world == null:
		return
	var vis := 1.0
	if GameState.player and GameState.player.has_method("visibility"):
		vis = GameState.player.visibility()
	# Policías que lo ven directamente
	for cop in GameState.world.get_police():
		if not is_instance_valid(cop) or not cop.visible:
			continue
		var d: float = cop.global_position.distance_to(pos)
		if d < radius * 1.6 * vis and GameState.world.has_line_of_sight(cop.global_position + Vector3.UP * 1.6, pos + Vector3.UP * 1.0):
			add_suspicion(35.0)
			Events.toast("¡Un policía te ha visto (%s)!" % kind, "police")
			set_wanted(maxi(wanted, Wanted.PURSUIT if kind == "agresión" else Wanted.INVESTIGATING))
			cop.call("alert_to_player")
			return
	# Testigos civiles
	var witnesses := 0
	for npc in GameState.world.get_civilians():
		if not is_instance_valid(npc) or not npc.visible:
			continue
		var d2: float = npc.global_position.distance_to(pos)
		if d2 < radius * vis and GameState.world.has_line_of_sight(npc.global_position + Vector3.UP * 1.6, pos + Vector3.UP * 1.0):
			witnesses += 1
			if npc.has_method("react_witness"):
				npc.react_witness(pos)
	if witnesses > 0:
		var report_chance := clampf(0.25 * witnesses * (1.4 if kind == "agresión" else 1.0), 0.0, 0.9)
		if _rng.randf() < report_chance:
			_pending_reports.append({"at": GameState.absolute_minute() + _rng.randi_range(5, 15), "pos": pos, "severity": 15.0 + 5.0 * witnesses})
			Events.toast("Un testigo parece estar llamando a alguien...", "warn")
		else:
			add_suspicion(3.0 * witnesses)


## Un agente informa de que ve al jugador.
func officer_sees_player(cop: Node) -> void:
	last_seen_abs = GameState.absolute_minute()
	if wanted >= Wanted.PURSUIT:
		cop.call("chase_player")
		return
	if searching_officer != null and is_instance_valid(searching_officer):
		return
	var outside: bool = GameState.player != null and not GameState.player.get("is_indoors")
	var curfew_violation: bool = GameState.is_curfew() and outside
	if suspicion >= 50.0 or wanted == Wanted.INVESTIGATING or curfew_violation:
		if curfew_violation and wanted == Wanted.NONE:
			Events.toast("Toque de queda (22:00-05:00): un agente quiere hablar contigo.", "police")
		set_wanted(maxi(wanted, Wanted.INVESTIGATING))
		cop.call("approach_for_search")


## El jugador se ha resistido o ha huido de un registro.
func player_resisted() -> void:
	searching_officer = null
	search_timer = 0.0
	add_suspicion(30.0)
	set_wanted(maxi(wanted, Wanted.PURSUIT))


func player_attacked_officer(cop: Node) -> void:
	add_suspicion(50.0)
	set_wanted(Wanted.MANHUNT)
	if is_instance_valid(cop):
		cop.call("chase_player")


func begin_search(cop: Node) -> void:
	if searching_officer != null:
		return
	searching_officer = cop
	search_timer = SEARCH_DURATION
	Events.search_requested.emit(cop)
	Events.toast("Registro policial: no te muevas.", "police")


func _process(delta: float) -> void:
	if searching_officer == null:
		return
	if not is_instance_valid(searching_officer) or GameState.player == null:
		searching_officer = null
		return
	var dist: float = searching_officer.global_position.distance_to(GameState.player.global_position)
	if dist > 5.0:
		Events.toast("¡Has huido de un registro!", "police")
		player_resisted()
		return
	search_timer -= delta
	if search_timer <= 0.0:
		_finish_search()


func search_progress() -> float:
	if searching_officer == null:
		return -1.0
	return 1.0 - search_timer / SEARCH_DURATION


func _finish_search() -> void:
	var cop := searching_officer
	searching_officer = null
	var units := contraband_count(GameState.player_inventory)
	var detect := clampf(0.45 + units * 0.04, 0.0, 0.98)
	if units > 0 and _rng.randf() < detect:
		Events.toast("El agente ha encontrado material ilegal.", "police")
		arrest()
	else:
		Events.toast("Registro limpio. \"Circule.\"", "info")
		suspicion = maxf(0.0, suspicion - 30.0)
		set_wanted(Wanted.NONE)
		if is_instance_valid(cop):
			cop.call("resume_patrol")


static func contraband_count(inv: Inventory) -> int:
	var n := 0
	for s in inv.slots:
		if s != null and ItemDB.is_contraband(s["id"]):
			n += int(s["qty"])
	return n


## Detención: multa, confiscación, traslado a comisaría y cierre del distrito.
func arrest() -> void:
	var inv: Inventory = GameState.player_inventory
	var confiscated := 0
	for i in inv.size():
		var s = inv.get_slot(i)
		if s != null and ItemDB.is_contraband(s["id"]):
			confiscated += int(s["qty"])
			inv.slots[i] = null
	inv.changed.emit()
	var fine := 100 + int(GameState.cash * 0.2)
	var paid := GameState.charge(fine)
	GameState.stat_add("arrests", 1)
	GameState.stat_add("fines_paid", paid)
	var district := "northtown"
	if GameState.player:
		district = GameState.district_at(GameState.player.global_position)
	suspicion = 20.0
	wanted = Wanted.NONE
	searching_officer = null
	_emit()
	Audio.play("error")
	Events.player_arrested.emit(paid, confiscated)
	if GameState.world:
		GameState.world.on_player_arrested()
	GameState.skip_minutes(180)
	if district != "northtown":
		GameState.lockdown(district, 12)
	else:
		crackdown_until = GameState.absolute_minute() + 12 * 60
		Events.toast("Patrullas reforzadas en Northtown durante 12 horas.", "police")
	Events.toast("Detenido: multa de $%d y %d objetos confiscados." % [paid, confiscated], "police")


# ------------------------------------------------------------------ Tiempo

func _on_minute(_m: int, _d: int) -> void:
	var now := GameState.absolute_minute()
	# Denuncias de testigos que llegan con retraso
	for r in _pending_reports.duplicate():
		if now >= int(r["at"]):
			_pending_reports.erase(r)
			add_suspicion(float(r["severity"]))
			Events.toast("La policía ha recibido una denuncia.", "police")
			if GameState.world:
				GameState.world.dispatch_police(r["pos"])
	if wanted >= Wanted.PURSUIT:
		if now - last_seen_abs > ESCAPE_MINUTES:
			suspicion = minf(suspicion, 45.0)
			set_wanted(Wanted.NONE)
			if GameState.world:
				GameState.world.police_stand_down()
	elif wanted == Wanted.INVESTIGATING:
		if now - last_seen_abs > ESCAPE_MINUTES and searching_officer == null:
			set_wanted(Wanted.NONE)
	else:
		if suspicion > 0.0:
			suspicion = maxf(0.0, suspicion - 0.25)
			if int(suspicion * 4.0) % 20 == 0:
				_emit()


func _on_day_started(_day: int) -> void:
	# Redada: si la sospecha es alta al empezar el día, registran una propiedad.
	if suspicion >= 60.0:
		Business.police_raid()
		suspicion = maxf(0.0, suspicion - 25.0)
		_emit()


# ------------------------------------------------------------------ Persistencia

func to_dict() -> Dictionary:
	return {"suspicion": suspicion, "crackdown_until": crackdown_until}


func from_dict(d: Dictionary) -> void:
	reset()
	suspicion = float(d.get("suspicion", 0.0))
	crackdown_until = int(d.get("crackdown_until", 0))
	_emit()
