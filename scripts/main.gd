extends Stage
## Sala lateral da região: monta a sala atual (Game.room) a partir de Rooms.DATA
## e cuida de saídas, itens, laser, ponto de restauração, porta, chefe e Explorer.

const WALL := Color(0.36, 0.36, 0.4)
const WALL_TOP := Color(0.62, 0.62, 0.66)
const LASER := Color(1.0, 0.2, 0.33)

var MAP: Array = []
var data: Dictionary
var player: Player
var door_pos := Vector2.ZERO
var restore_pos := Vector2.ZERO
var patches: Array[Vector2] = []
var chips: Array[Vector2] = []
var fake_walls: Array[Vector2] = []
var lasers: Array[Vector2] = []
var _leaving := false
var _door_told := false
var _map_view: Control
var boss: GhostFile
var exit_pos := Vector2.ZERO   # saída da sala do chefe, escondida até ele cair
var _boss_bar: ColorRect


func help_text() -> String:
	return "A/D mover · Espaço pular · J atirar · K dash · Shift farejar · Tab Explorer · R restaurar"


func _key(pos: Vector2) -> String:
	return "%s:%d:%d" % [Game.room, int(pos.x), int(pos.y)]


# ------------------------------------------------------------------ montagem

func _build_level() -> void:
	data = Rooms.DATA[Game.room]
	MAP = data.map
	Game.visited[Game.room] = true
	var start := Vector2.ZERO
	var boss_at := Vector2.ZERO
	for y in MAP.size():
		var row: String = MAP[y]
		var x := 0
		while x < row.length():
			if row[x] == "#":
				var s := x
				while x < row.length() and row[x] == "#":
					x += 1
				_add_wall(s, y, x - s)
				continue
			var at := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match row[x]:
				"P": start = at
				"w": _spawn(Walker.new(), at)
				"t": _spawn(Turret.new(), at)
				"F": fake_walls.append(at)
				"R": restore_pos = at
				"D": door_pos = at
				"B": boss_at = at
				"E": exit_pos = at
				"L": _add_laser(at)
				"H":
					if not Game.taken.has(_key(at)):
						patches.append(at)
				"A":
					if not Game.taken.has(_key(at)):
						chips.append(at)
			x += 1

	player = Player.new()
	player.hp = Game.hp
	if Game.entry.has("pos"):
		player.position = Game.entry.pos
		player.velocity = Game.entry.vel
	else:
		player.position = start if start != Vector2.ZERO else restore_pos
	add_child(player)
	# o chefe procura o cão ao nascer, então entra depois dele
	if boss_at != Vector2.ZERO and not Game.taken.has("boss_desktop"):
		boss = GhostFile.new()
		boss.defeated.connect(_on_boss_defeated)
		_spawn(boss, boss_at)

	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP[0].length() * TILE
	camera.limit_bottom = MAP.size() * TILE
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.global_position = player.global_position
	camera.reset_smoothing()

	_map_view = ExplorerView.new()
	_map_view.visible = false


func _ready() -> void:
	super()
	if boss != null:
		var back := ColorRect.new()
		back.color = WALL
		back.position = Vector2(252, 9)
		back.size = Vector2(124, 7)
		hud.get_parent().add_child(back)
		_boss_bar = ColorRect.new()
		_boss_bar.color = Enemy.BUG_COLOR
		_boss_bar.position = Vector2(2, 2)
		_boss_bar.size = Vector2(120, 3)
		back.add_child(_boss_bar)
	hud.get_parent().add_child(_map_view)
	if boss != null:
		show_toast("ARQUIVO FANTASMA\nFareje para torná-lo sólido, ou espere ele bater.", 3.0)
	else:
		show_toast(data.name)


func _spawn(e: Node2D, at: Vector2) -> void:
	e.position = at
	add_child(e)


func _add_laser(at: Vector2) -> void:
	# barreira física (camada 5): o cão só atravessa durante o dash
	lasers.append(at)
	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	body.position = at
	body.add_child(shape)
	add_child(body)


func is_solid(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= MAP.size():
		return true
	var row: String = MAP[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return false  # aberturas de saída
	return row[cell.x] == "#"


func is_solid_at(pos: Vector2) -> bool:
	return is_solid(Vector2i(floori(pos.x / TILE), floori(pos.y / TILE)))


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(r, WALL)
			if y > 0 and not is_solid(Vector2i(x, y - 1)):
				draw_rect(Rect2(r.position, Vector2(TILE, 2)), WALL_TOP)

	for c in fake_walls:
		var r := Rect2(c - Vector2(TILE, TILE) / 2.0, Vector2(TILE, TILE))
		if sniffing:
			_dashed_rect(r.grow(-1), ACCENT)
		else:
			draw_rect(r, WALL)

	var t := Time.get_ticks_msec()
	for l in lasers:
		var w := 2.0 + float(t / 50 % 3)
		draw_rect(Rect2(l.x - w / 2.0, l.y - TILE / 2.0, w, TILE), LASER)
		draw_rect(Rect2(l.x - 4, l.y - TILE / 2.0, 8, 1), LASER)

	for p in patches:
		draw_rect(Rect2(p - Vector2(1, 4), Vector2(2, 8)), Color.WHITE)
		draw_rect(Rect2(p - Vector2(4, 1), Vector2(8, 2)), Color.WHITE)

	for c in chips:
		var bob := Vector2(0, -2 if t / 300 % 2 == 0 else 0)
		draw_rect(Rect2(c - Vector2(5, 4) + bob, Vector2(10, 8)), ACCENT)
		draw_rect(Rect2(c - Vector2(3, 2) + bob, Vector2(6, 4)), Color.BLACK)
		for i in 3:
			draw_rect(Rect2(c + Vector2(-4 + i * 3, 4) + bob, Vector2(1, 2)), ACCENT)

	if restore_pos != Vector2.ZERO:
		# monitor antigo: o ponto de restauração
		var lit: bool = Game.restore.get("room", "") == Game.room
		draw_rect(Rect2(restore_pos - Vector2(6, 6), Vector2(12, 9)), Color.WHITE, false, 1.0)
		draw_rect(Rect2(restore_pos - Vector2(4, 4), Vector2(8, 5)), ACCENT if lit else Color(1, 1, 1, 0.25))
		draw_rect(Rect2(restore_pos + Vector2(-3, 4), Vector2(6, 4)), Color.WHITE)

	if door_pos != Vector2.ZERO:
		var open: bool = not Game.taken.has("boss_desktop")
		draw_rect(Rect2(door_pos - Vector2(6, 8), Vector2(12, 16)), Color.WHITE, false, 1.0)
		draw_rect(Rect2(door_pos - Vector2(2, 2), Vector2(4, 4)), Color.WHITE if open else ACCENT)

	if exit_pos != Vector2.ZERO and Game.taken.has("boss_desktop"):
		draw_rect(Rect2(exit_pos - Vector2(6, 8), Vector2(12, 16)), Color.WHITE, false, 1.0)
		draw_rect(Rect2(exit_pos - Vector2(2, 2), Vector2(4, 4)), ACCENT)

	if sniffing and is_instance_valid(player):
		var targets := fake_walls + chips
		if not targets.is_empty():
			var target: Vector2 = targets[targets.size() - 1]
			var from := player.global_position
			var steps := int(from.distance_to(target) / 10.0)
			var phase := t / 90 % 3
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
	if not is_instance_valid(player) or _leaving:
		return
	var pp := player.global_position
	camera.global_position = pp + Vector2(player.facing * 32, -16)
	queue_redraw()

	if Input.is_action_just_pressed("map"):
		_map_view.visible = not _map_view.visible

	for p in patches.duplicate():
		if pp.distance_to(p) < 10.0:
			patches.erase(p)
			Game.taken[_key(p)] = true
			player.heal(1)
			show_toast("+1 VIDA")

	for c in chips.duplicate():
		if pp.distance_to(c) < 12.0:
			chips.erase(c)
			Game.taken[_key(c)] = true
			Game.abilities.dash = true
			add_shake(4.0)
			show_toast("DASH INSTALADO · K / C / B\natravessa lasers e tiros", 3.5)

	if restore_pos != Vector2.ZERO and pp.distance_to(restore_pos) < 12.0 and player.hp > 0:
		var fresh: bool = Game.restore.get("room", "") != Game.room
		player.hp = player.MAX_HP
		Game.restore = {"room": Game.room, "pos": restore_pos}
		if fresh:
			show_toast("PONTO DE RESTAURAÇÃO CRIADO")

	if door_pos != Vector2.ZERO and pp.distance_to(door_pos) < 12.0 and player.hp > 0:
		if Game.taken.has("boss_desktop"):
			if not _door_told:
				_door_told = true
				show_toast("Região limpa.", 3.0)
		elif Game.taken.has("arena_desktop"):
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			Game.boss_return = {"room": Game.room, "pos": door_pos - Vector2(24, 0)}
			Game.enter("ghost")
			return
		else:
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			Game.enter_arena(Game.room, door_pos - Vector2(24, 0))
			return
	elif door_pos != Vector2.ZERO and pp.distance_to(door_pos) > 40.0:
		_door_told = false

	if _boss_bar != null:
		var left := float(boss.hp) / GhostFile.MAX_HP_BOSS if is_instance_valid(boss) else 0.0
		_boss_bar.size.x = 120.0 * left

	if exit_pos != Vector2.ZERO and Game.taken.has("boss_desktop") and player.hp > 0 and pp.distance_to(exit_pos) < 10.0:
		_leaving = true
		Game.hp = player.hp
		set_sniffing(false)
		if Game.boss_return.is_empty():
			Game.respawn()
		else:
			Game.enter(Game.boss_return.room, Game.boss_return.pos)
		return

	_check_exit(pp)
	hud.text = "VIDA %d/%d   FARO %d%%" % [maxi(player.hp, 0), player.MAX_HP, int(player.sniff_energy)]


func _on_boss_defeated() -> void:
	Game.taken["boss_desktop"] = true
	for c in get_children():
		if c is Bullet and not c.friendly:
			c.queue_free()
	player.hp = player.MAX_HP
	show_toast("ARQUIVO FANTASMA EXCLUÍDO\nregião limpa, saída aberta", 4.0)
	queue_redraw()


func _check_exit(pp: Vector2) -> void:
	var width: float = MAP[0].length() * TILE
	var side := ""
	if pp.x < 2.0:
		side = "left"
	elif pp.x > width - 2.0:
		side = "right"
	if side == "":
		return
	var row := floori(pp.y / TILE)
	for link in data.links:
		if link.side == side and row >= link.rows[0] - 1 and row <= link.rows[1]:
			var target: Dictionary = Rooms.DATA[link.to]
			var tw: float = target.map[0].length() * TILE
			var x := tw - 10.0 if side == "left" else 10.0
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			Game.enter(link.to, Vector2(x, pp.y), player.velocity)
			return


# ------------------------------------------------------------------ Explorer

## Mapa das salas visitadas (Tab). Cada sala é um retângulo na grade da região.
class ExplorerView extends Control:
	const CELL := Vector2(36, 22)

	func _ready() -> void:
		size = Vector2(384, 216)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
		var box := Rect2(Vector2(72, 40), Vector2(240, 136))
		draw_rect(box, Color.WHITE, false, 1.0)
		draw_rect(Rect2(box.position, Vector2(box.size.x, 10)), Color.WHITE)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(4, 8), "EXPLORER · " + Rooms.DATA[Game.room].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.BLACK)
		var origin := box.position + Vector2(14, 66)
		var blink := Time.get_ticks_msec() / 300 % 2 == 0
		for id in Rooms.DATA:
			if not Game.visited.has(id):
				continue
			var r: Dictionary = Rooms.DATA[id]
			var screens: int = maxi(1, r.map[0].length() / 24)
			var rect := Rect2(origin + Vector2(r.grid) * CELL, Vector2(screens * CELL.x - 3, CELL.y - 3))
			var cur: bool = id == Game.room
			draw_rect(rect, Stage.ACCENT if cur and blink else Color(0.36, 0.36, 0.4))
			draw_rect(rect, Color.WHITE, false, 1.0)
			if Game.restore.get("room", "") == id:
				draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(4, 4)), Color.WHITE)
		draw_string(ThemeDB.fallback_font, box.position + Vector2(6, box.size.y - 6), "[] ponto de restauração · Tab fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.6))
