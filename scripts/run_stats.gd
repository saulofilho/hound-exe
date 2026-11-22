class_name RunStats
extends RefCounted
## Números de uma partida, guardados no save: tempo, mortes e desistências por
## sala, quando cada progresso aconteceu e se a máquina deu conta.
##
## Fica só no arquivo do jogador: nada sai pela rede e nada identifica a pessoa.
## tools/playtest_report.py lê esses números.

const MAX_STEP := 1.0      # segundos: um engasgo maior (janela parada) não é jogo
const SLOW_FRAME := 0.0345 # abaixo de ~29 quadros por segundo

var seconds := 0.0
var deaths := 0
var restarts := 0          # reiniciou vivo: sinal de que travou
var sessions := 1
var partial := false       # save de antes da contagem: o total não vale
var frames := 0
var slow := 0
var pad := false           # jogou alguma parte no controle
var rooms := {}            # sala: {"seconds", "deaths", "restarts"}
var marks := {}            # chave de Game.taken: segundo em que aconteceu


func tick(place: String, step: float, on_pad: bool) -> void:
	var spent := minf(step, MAX_STEP)
	seconds += spent
	_room(place).seconds += spent
	frames += 1
	if step > SLOW_FRAME:
		slow += 1
	pad = pad or on_pad


func died(place: String) -> void:
	deaths += 1
	_room(place).deaths += 1


func restarted(place: String) -> void:
	restarts += 1
	_room(place).restarts += 1


func mark(taken: Dictionary) -> void:
	for key in taken:
		if not marks.has(key):
			marks[key] = int(seconds)


func _room(place: String) -> Dictionary:
	if not rooms.has(place):
		rooms[place] = {"seconds": 0.0, "deaths": 0, "restarts": 0}
	return rooms[place]


## Segundos até derrubar o chefe; -1 se não derrubou ou o total não vale.
func finish_time() -> int:
	return -1 if partial else int(marks.get("boss_desktop", -1))


static func clock(total: int) -> String:
	if total < 0:
		return "--:--"
	if total >= 3600:
		return "%d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60]
	return "%d:%02d" % [total / 60, total % 60]


func to_data() -> Dictionary:
	var by_room := {}
	for place in rooms:
		var r: Dictionary = rooms[place]
		by_room[place] = {"seconds": int(r.seconds), "deaths": r.deaths, "restarts": r.restarts}
	return {
		"seconds": int(seconds), "deaths": deaths, "restarts": restarts, "sessions": sessions,
		"partial": partial, "frames": frames, "slow": slow, "pad": pad, "rooms": by_room, "marks": marks,
		"version": str(ProjectSettings.get_setting("application/config/version", "")), "os": OS.get_name(),
	}


## Números estragados nunca derrubam um save bom: viram contagem parcial.
static func from_data(data: Variant) -> RunStats:
	var out := RunStats.new()
	if not data is Dictionary:
		out.partial = true
		return out
	var bad := false
	for key in ["seconds", "deaths", "restarts", "sessions", "frames", "slow"]:
		var value: Variant = data.get(key)
		if (value is float or value is int) and value >= 0 and value < 1e9:
			out.set(key, float(value) if key == "seconds" else int(value))
		else:
			bad = true
	out.partial = bad or not data.get("partial") is bool or data.get("partial") == true
	out.pad = data.get("pad") is bool and data.get("pad") == true
	var by_room: Variant = data.get("rooms")
	if by_room is Dictionary:
		for place in by_room:
			var r: Variant = by_room[place]
			if not place is String or not r is Dictionary:
				continue
			var row := out._room(place)
			for key in row:
				var value: Variant = r.get(key)
				if (value is float or value is int) and value >= 0 and value < 1e9:
					row[key] = float(value) if key == "seconds" else int(value)
	var when: Variant = data.get("marks")
	if when is Dictionary:
		for key in when:
			var value: Variant = when[key]
			if (value is float or value is int) and value >= 0 and value < 1e9:
				out.marks[key] = int(value)
	return out
