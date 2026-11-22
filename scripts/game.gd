extends Node
## Estado da partida (autoload "Game"): sala atual, vida, habilidades,
## ponto de restauração, salas visitadas, itens já pegos e o save.
##
## O save guarda o progresso, não a posição: ao continuar, o cão volta ao
## último ponto de restauração com a vida cheia, como depois de morrer.

signal save_failed

const MAX_HP := 5
const START_ROOM := "c_drive"

var save_path := ""             # vazio = disco desligado (testes e ferramentas)
var room := START_ROOM
var entry := {}                 # {"pos": Vector2, "vel": Vector2} ao entrar numa sala
var hp := MAX_HP
var sniff := 100.0              # o faro atravessa as salas
var abilities := {"dash": false}
var restore := {}               # {"room": String, "pos": Vector2}
var visited := {}
var taken := {}                 # itens e eventos que não voltam ("room:x:y", "arena_desktop")
var arena_return := {}          # para onde a sala de cima devolve o cão
var _quitting := false
var boss_return := {}           # para onde a saída do chefe devolve o cão


func _ready() -> void:
	_install_font()
	process_mode = Node.PROCESS_MODE_ALWAYS  # fechar a janela vale também na pausa


## A fonte pixel (tools/make_art.py) vale para o jogo inteiro.
func _install_font() -> void:
	var font: FontFile = load("res://art/hound_font.fnt")
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 11
	ThemeDB.get_default_theme().default_font = font
	ThemeDB.get_default_theme().default_font_size = 11


func _exit_tree() -> void:
	Art.release()


func new_game() -> void:
	room = START_ROOM
	entry = {}
	hp = MAX_HP
	sniff = 100.0
	abilities = {"dash": false}
	restore = {}
	visited = {}
	taken = {}
	arena_return = {}
	boss_return = {}


func save_game() -> void:
	if save_path == "":
		return
	var data := {
		"restore": restore.get("room", ""),
		"dash": abilities.dash,
		"visited": visited.keys(),
		"taken": taken.keys(),
	}
	if not SaveFile.write(save_path, data):
		save_failed.emit()


func load_game() -> bool:
	if save_path == "":
		return false
	var data := SaveFile.read(save_path)
	if data.is_empty():
		return false
	new_game()
	abilities.dash = data.dash
	for id in data.visited:
		visited[id] = true
	for key in data.taken:
		taken[key] = true
	if data.restore != "":
		# a posição sai do mapa: se a sala mudar numa versão nova, o save continua valendo
		restore = {"room": data.restore, "pos": Rooms.restore_point(data.restore)}
	return true


func to_title() -> void:
	_change.call_deferred("res://title.tscn")


func quit() -> void:
	if _quitting:
		return
	_quitting = true
	await Sound.shutdown()
	get_tree().quit()


func _notification(what: int) -> void:
	# o título desliga o fechamento automático para passar por quit()
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not get_tree().auto_accept_quit:
		quit()


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
	sniff = 100.0
	if restore.is_empty():
		enter(START_ROOM)
	else:
		enter(restore.room, restore.pos)


func _change(path: String) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
