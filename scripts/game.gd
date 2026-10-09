extends Node3D
## Escena principal de juego: prepara los sistemas (partida nueva o cargada),
## construye el mundo, el jugador, el ciclo día/noche y la interfaz.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const UI_SCENE := preload("res://scenes/ui/ui.tscn")

var world: World
var player: Player
var day_night: DayNight
var ui: Node


func _ready() -> void:
	var loading: Dictionary = SaveSystem.pending_load
	if loading.is_empty():
		SaveSystem.reset_all_for_new_game()
	else:
		SaveSystem.apply_systems(loading)
	world = WORLD_SCENE.instantiate()
	add_child(world)
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.teleport(world.player_spawn, world.player_spawn_yaw)
	world.populate()
	if not loading.is_empty():
		world.apply_save(loading.get("world", {}))
		SaveSystem.pending_load = {}
	Quests.respawn_quest_items()
	ui = UI_SCENE.instantiate()
	add_child(ui)
	GameState.time_running = true
	Audio.play_music(true)
	Events.world_ready.emit()
	if loading.is_empty():
		Events.toast("Bienvenido a Redmont. Abre el teléfono con Tab y sigue tu misión.", "quest")


func _exit_tree() -> void:
	GameState.time_running = false
