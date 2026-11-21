extends Stage
## Corredor lateral montado a partir de um mapa ASCII.
## Legenda: # parede · F parede falsa (só o faro revela) · P cão · w bug que anda
##          t torreta · H patch de vida · D porta para a sala de cima

const MAP := [
	"########################################################################",
	"#...................................................................#..#",
	"#...................................................................#..#",
	"#...................................................................#..#",
	"#...........................................###.....................#..#",
	"#...................................................................#..#",
	"#...................................t.....................####......#..#",
	"#.................................#####.............................#..#",
	"#.......#####.......................................####............#..#",
	"#.........................####......................................F..#",
	"#..P............w.........####............w.............w.......t...FHD#",
	"########################################################################",
	"########################################################################",
]
const WALL := Color(0.36, 0.36, 0.4)
const WALL_TOP := Color(0.62, 0.62, 0.66)

var player: Player
var door_pos: Vector2
var patches: Array[Vector2] = []
var fake_walls: Array[Vector2] = []
var _leaving := false


func help_text() -> String:
	return "mover A/D · pular Espaço · atirar J (W p/ cima) · dash K · farejar Shift · R reinicia"


# ------------------------------------------------------------------ nível

func is_solid(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size():
		return true
	var row: String = MAP[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return true
	return row[cell.x] == "#"


func is_solid_at(pos: Vector2) -> bool:
	return is_solid(Vector2i(floori(pos.x / TILE), floori(pos.y / TILE)))


func _build_level() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		var x := 0
		while x < row.length():
			if row[x] == "#":
				# junta paredes vizinhas da mesma linha num único corpo
				var start := x
				while x < row.length() and row[x] == "#":
					x += 1
				_add_wall(start, y, x - start)
				continue
			var at := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match row[x]:
				"P":
					player = Player.new()
					player.position = at
					add_child(player)
				"w":
					var w := Walker.new()
					w.position = at
					add_child(w)
				"t":
					var t := Turret.new()
					t.position = at
					add_child(t)
				"F":
					fake_walls.append(at)
				"H":
					patches.append(at)
				"D":
					door_pos = at
			x += 1

	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP[0].length() * TILE
	camera.limit_bottom = MAP.size() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.global_position = player.global_position
	camera.reset_smoothing()


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(r, WALL)
			if not is_solid(Vector2i(x, y - 1)):
				draw_rect(Rect2(r.position, Vector2(TILE, 2)), WALL_TOP)

	# parede falsa: igual às outras, até o faro revelar
	for c in fake_walls:
		var r := Rect2(c - Vector2(TILE, TILE) / 2.0, Vector2(TILE, TILE))
		if sniffing:
			_dashed_rect(r.grow(-1), ACCENT)
		else:
			draw_rect(r, WALL)

	for p in patches:
		draw_rect(Rect2(p - Vector2(1, 4), Vector2(2, 8)), Color.WHITE)
		draw_rect(Rect2(p - Vector2(4, 1), Vector2(8, 2)), Color.WHITE)

	if door_pos != Vector2.ZERO:
		draw_rect(Rect2(door_pos - Vector2(6, 8), Vector2(12, 16)), Color.WHITE, false, 1.0)
		draw_rect(Rect2(door_pos - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)

	# rastro do faro: pontos do cão até o segredo mais próximo
	if sniffing and is_instance_valid(player) and not fake_walls.is_empty():
		var target: Vector2 = fake_walls[fake_walls.size() - 1]
		var from := player.global_position
		var steps := int(from.distance_to(target) / 10.0)
		var phase := int(Time.get_ticks_msec() / 90) % 3
		for i in range(1, steps):
			if (i + phase) % 3 != 0:
				draw_rect(Rect2(from.lerp(target, float(i) / steps) + Vector2(-1, 4), Vector2(2, 2)), ACCENT)


func _dashed_rect(r: Rect2, c: Color) -> void:
	for i in range(0, int(r.size.x), 4):
		draw_rect(Rect2(r.position + Vector2(i, 0), Vector2(2, 1)), c)
		draw_rect(Rect2(r.position + Vector2(i, r.size.y - 1), Vector2(2, 1)), c)
	for i in range(0, int(r.size.y), 4):
		draw_rect(Rect2(r.position + Vector2(0, i), Vector2(1, 2)), c)
		draw_rect(Rect2(r.position + Vector2(r.size.x - 1, i), Vector2(1, 2)), c)


# ------------------------------------------------------------------ jogo

func stage_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	camera.global_position = player.global_position + Vector2(player.facing * 32, -16)
	if sniffing:
		queue_redraw()

	for p in patches.duplicate():
		if player.global_position.distance_to(p) < 10.0:
			patches.erase(p)
			player.heal(1)
			add_shake(1.5)
			queue_redraw()

	if not _leaving and player.hp > 0 and player.global_position.distance_to(door_pos) < 12.0:
		_leaving = true
		Arena.carry_hp = player.hp
		set_sniffing(false)
		get_tree().change_scene_to_file("res://arena.tscn")
		return

	var enemies := get_tree().get_nodes_in_group("enemy").size()
	hud.text = "VIDA %d/%d   BUGS %d   FARO %d%%" % [maxi(player.hp, 0), player.MAX_HP, enemies, int(player.sniff_energy)]
