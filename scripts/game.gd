extends Node
## Estado da partida (autoload "Game"): sala atual, vida, habilidades,
## ponto de restauração, salas visitadas e itens já pegos.

const MAX_HP := 5
const START_ROOM := "c_drive"

var room := START_ROOM
var entry := {}                 # {"pos": Vector2, "vel": Vector2} ao entrar numa sala
var hp := MAX_HP
var abilities := {"dash": false}
var restore := {}               # {"room": String, "pos": Vector2}
var visited := {}
var taken := {}                 # itens e eventos que não voltam ("room:x:y", "arena_desktop")
var arena_return := {}          # para onde a sala de cima devolve o cão


func new_game() -> void:
	room = START_ROOM
	entry = {}
	hp = MAX_HP
	abilities = {"dash": false}
	restore = {}
	visited = {}
	taken = {}


## Troca de sala (ou de cena) no fim do quadro, para não quebrar a física.
func enter(room_id: String, pos := Vector2.ZERO, vel := Vector2.ZERO) -> void:
	room = room_id
	entry = {"pos": pos, "vel": vel} if pos != Vector2.ZERO else {}
	_change.call_deferred("res://main.tscn")


func enter_arena(back_room: String, back_pos: Vector2) -> void:
	arena_return = {"room": back_room, "pos": back_pos}
	_change.call_deferred("res://arena.tscn")


## Volta ao último ponto de restauração com a vida cheia (ou ao início).
func respawn() -> void:
	hp = MAX_HP
	if restore.is_empty():
		enter(START_ROOM)
	else:
		enter(restore.room, restore.pos)


func _change(path: String) -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(path)
