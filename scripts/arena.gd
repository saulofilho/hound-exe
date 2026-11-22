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
const WALL := Color(0.36, 0.36, 0.4)
const WALL_TOP := Color(0.62, 0.62, 0.66)

var hound: TopHound
var spawns: Array[Vector2] = []
var time_left := DURATION
var _wave := 0
var _wave_t := 1.2
var _over := false


func help_text() -> String:
	return "mover WASD · mirar mouse ou analógico direito · atirar J/clique · dash K · Esc pausa"


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
	Sound.music("arena")
	# a sala inteira cabe na tela: câmera fixa no centro
	camera.position = Vector2(MAP[0].length(), MAP.size()) * TILE / 2.0


func _draw() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if row[x] == "#":
				draw_rect(r, WALL)
				draw_rect(Rect2(r.position, Vector2(TILE, 2)), WALL_TOP)
			elif (x + y) % 2 == 0:
				draw_rect(Rect2(r.get_center(), Vector2(1, 1)), Color(1, 1, 1, 0.18))  # piso
	for s in spawns:
		draw_rect(Rect2(s - Vector2(4, 4), Vector2(8, 8)), Enemy.BUG_COLOR, false, 1.0)


func hero_dead() -> bool:
	return is_instance_valid(hound) and hound.hp <= 0


func stage_process(delta: float) -> void:
	if _over or not is_instance_valid(hound):
		return
	if hound.hp <= 0:
		_over = true
		return

	time_left = maxf(time_left - delta, 0.0)
	_wave_t -= delta
	if _wave_t <= 0.0:
		_spawn_wave()

	var bugs := get_tree().get_nodes_in_group("enemy")
	hud.text = "PROCESSO %02ds   VIDA %d/%d   BUGS %d" % [ceili(time_left), maxi(hound.hp, 0), hound.MAX_HP, bugs.size()]

	if time_left <= 0.0:
		_over = true
		for b in bugs:
			b._burst()
			b.queue_free()
		add_shake(6.0)
		show_banner("PROCESSO CONCLUÍDO", ACCENT)
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
