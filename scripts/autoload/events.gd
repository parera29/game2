extends Node
## Bus global de eventos. Los sistemas se comunican a través de estas señales
## para mantenerse desacoplados (misiones, HUD, estadísticas, audio...).

# --- Notificaciones / UI ---
signal notify(text: String, kind: String)            # kind: info, money, quest, warn, police, phone
signal request_ui(ui_name: String, payload: Variant)   # abre una interfaz concreta
signal ui_closed(ui_name: String)

# --- Economía / progreso ---
signal money_changed(cash: int, bank: int)
signal xp_changed(xp: int, rank: int)
signal rank_changed(rank: int)
signal district_unlocked(district_id: String)

# --- Tiempo ---
signal minute_passed(minute_of_day: int, day: int)
signal hour_passed(hour: int, day: int)
signal day_started(day: int)

# --- Acciones del jugador (usadas por las misiones) ---
signal item_bought(item_id: String, qty: int)
signal item_sold(item_id: String, qty: int, total: int)
signal npc_talked(npc_id: String)
signal item_delivered(npc_id: String, item_id: String, qty: int)
signal location_reached(location_id: String)
signal deal_completed(customer_id: String, units: int, total: int)
signal customer_unlocked(customer_id: String)
signal station_installed(station_type: String, property_id: String)
signal harvested(item_id: String, qty: int)
signal packaged(item_id: String, qty: int)
signal mixed(item_id: String, qty: int)
signal produced(item_id: String, qty: int)
signal property_acquired(property_id: String)
signal employee_hired(employee_id: String)
signal employees_changed()

# --- Clientes / teléfono ---
signal messages_changed(customer_id: String)
signal deal_scheduled(customer_id: String)
signal deal_cancelled(customer_id: String)

# --- Policía ---
signal heat_changed(suspicion: float, wanted: int)
signal player_arrested(fine: int, confiscated: int)
signal search_requested(officer: Node)
signal witness_report(position: Vector3, severity: float)

# --- Misiones ---
signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)

# --- Mundo ---
signal world_ready()
signal property_state_changed(property_id: String)
signal settings_changed()


func toast(text: String, kind: String = "info") -> void:
	notify.emit(text, kind)
