class_name Arena
extends Stage
## Sala de cima: sobreviva 45 segundos às ondas de bugs, com tiro em dois analógicos.
## Legenda: # parede · P cão · s ponto de surgimento dos bugs

const DURATION := 45.0
const MAX_BUGS := 14
const MAP := [
	"########################",
	"#s.........s..........s#",
	"#......................#",
	"#....##..........##....#",
	"#......................#",
	"#......................#",
	"#..P.......##..........#",
	"#......................#",
	"#......................#",
	"#....##..........##....#",
	"#......................#",
	"#s..........s.........s#",
	"########################",
]

var hound: TopHound
var spawns: Array[Vector2] = []
var time_left := DURATION
var _wave := 0
var _wave_t := 1.2
var _over := false


func _ready() -> void:
	super()
	hud.hp = hound.hp
	hud.seconds_left = int(DURATION)
	# um aviso que some: linha fixa embaixo taparia bugs e o cão
	show_toast("WASD anda · mouse mira · clique ou J atira · K dash", 3.5)


func _build_level() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		var x := 0
		while x < row.length():
			if row[x] == "#":
				var start := x
				while x < row.length() and row[x] == "#":
					x += 1
				_add_wall(start, y, x - start)
				continue
			var at := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			if row[x] == "P":
				hound = TopHound.new()
				hound.position = at
				add_child(hound)
			elif row[x] == "s":
				spawns.append(at)
			x += 1
	var room_art := RoomArt.new()
	room_art.map = MAP
	room_art.theme = "arena"
	add_child(room_art)
	Sound.music("arena")
	# a sala inteira cabe na tela: câmera fixa no centro
	camera.position = Vector2(MAP[0].length(), MAP.size()) * TILE / 2.0


func _draw() -> void:
	# onde os bugs surgem
	for s in spawns:
		for corner in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
			var at: Vector2 = s + corner
			draw_line(at, at - Vector2(corner.sign().x * 3, 0), ACCENT, 1.0)
			draw_line(at, at - Vector2(0, corner.sign().y * 3), ACCENT, 1.0)


func hero_dead() -> bool:
	return is_instance_valid(hound) and hound.hp <= 0


func stage_process(delta: float) -> void:
	if _over or not is_instance_valid(hound):
		return
	if hound.hp <= 0:
		hud.hp = 0
		_over = true
		return

	time_left = maxf(time_left - delta, 0.0)
	_wave_t -= delta
	if _wave_t <= 0.0:
		_spawn_wave()

	var bugs := get_tree().get_nodes_in_group("enemy")
	hud.hp = maxi(hound.hp, 0)
	hud.seconds_left = ceili(time_left)
	hud.bugs = bugs.size()

	if time_left <= 0.0:
		_over = true
		for b in bugs:
			b._burst()
			b.queue_free()
		add_shake(6.0)
		show_banner("PROCESSO CONCLUÍDO\n\nVoltando para a região...", ACCENT)
		Sound.music("")
		Sound.play("victory")
		Game.taken["arena_desktop"] = true
		Game.hp = hound.hp
		Game.save_game()
		# process_always = false: a volta à região espera se o jogo estiver pausado
		await get_tree().create_timer(2.0, false, false, true).timeout
		if Game.arena_return.is_empty():
			Game.enter(Game.START_ROOM)
		else:
			Game.enter(Game.arena_return.room, Game.arena_return.pos)


func _spawn_wave() -> void:
	_wave += 1
	Sound.play("wave")
	_wave_t = 4.0
	var alive := get_tree().get_nodes_in_group("enemy").size()
	var count := mini(1 + _wave, MAX_BUGS - alive)
	for i in count:
		var c := Chaser.new()
		c.position = spawns[randi() % spawns.size()] + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		c.speed += _wave * 2.0
		add_child(c)
