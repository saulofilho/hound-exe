extends Stage
## Sala lateral da região: monta a sala atual (Game.room) a partir de Rooms.DATA
## e cuida de saídas, pastas, itens, pistas, perigos, quarentena, porta, chefe
## e Explorer. A legenda dos mapas está em rooms.gd.

const SPRITE := Vector2(16, 16)
# quadros de items.png
const RESTORE_OFF := 0
const RESTORE_ON := 1
const CHIP := 2
const PATCH := 3
const DOOR := 4
const DOOR_CLEAR := 5
const DOOR_LOCKED := 6
const FOLDER := 7
const FOLDER_SHUT := 8
const CLUE := 9
const BACKUP := 10
const DIG_RANGE := 72.0        # farejar a esta distância desenterra a pista
const FOLDER_RANGE := 11.0
const REVEAL_RANGE := 96.0     # farejar a esta distância abre a parede falsa
const NUDGE_RANGE := 26.0      # encostado nela sem farejar: o jogo dá a dica

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
var _map_view: ExplorerView
var revealed := false          # a parede falsa desta sala já foi farejada
var _fake_bodies: Array[StaticBody2D] = []
var _nudged := false
var _patch_told := false
var boss: GhostFile
var exit_pos := Vector2.ZERO   # saída da sala do chefe, trancada até ele cair
var _room_art: RoomArt
var _items: Texture2D
var _laser_sheet: Texture2D
var folders: Array[Dictionary] = []   # {"at", "to", "land", "shortcut"}
var blocks: Array[SpecialBlock] = []
var hazards: Array[Vector2] = []
var quarantine: Quarantine
var clue_pos := Vector2.ZERO
var backup_pos := Vector2.ZERO
var safe_pos := Vector2.ZERO          # último chão firme: para onde o setor ruim devolve
var _gate_cells: Array[Vector2] = []
var _clue_nudged := false
var _shut_told := false


func help_text() -> String:
	# só a primeira sala ensina; nas outras a tela fica livre
	if Game.room != Game.START_ROOM:
		return ""
	return Options.t("hint_side")


func _key(pos: Vector2) -> String:
	return "%s:%d:%d" % [Game.room, int(pos.x), int(pos.y)]


# ------------------------------------------------------------------ montagem

func _build_level() -> void:
	data = Rooms.DATA[Game.room]
	MAP = data.map
	revealed = Game.taken.has(_secret_key())
	_items = Art.texture("items")
	_laser_sheet = Art.texture("laser")
	_room_art = RoomArt.new()
	_room_art.map = MAP
	_room_art.theme = Game.room
	_room_art.exits = data.links
	add_child(_room_art)
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
			if row[x] == "o" or row[x] == "T":
				var s := x
				while x < row.length() and row[x] == row[s]:
					x += 1
				_add_block(s, y, x - s, row[s] == "o")
				continue
			var at := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match row[x]:
				"P": start = at
				"w": _spawn(Walker.new(), at)
				"t": _spawn(Turret.new(), at)
				"s": _spawn(Spam.new(), at)
				"^": hazards.append(at)
				"Q": _gate_cells.append(at)
				"V": clue_pos = at
				"S":
					if not Game.taken.has("backup:" + Game.room):
						backup_pos = at
				"F": _add_fake_wall(at)
				"R": restore_pos = at
				"D": door_pos = at
				"B": boss_at = at
				"E": exit_pos = at
				"L": _add_laser(at)
				"H":
					if not Game.taken.has(_key(at)):
						patches.append(at)
				"A":
					if not Game.abilities.dash:
						chips.append(at)
				_:
					if row[x].is_valid_int():
						_add_folder(at, row[x])
			x += 1
	if Game.taken.has("clue:" + Game.room):
		clue_pos = Vector2.ZERO
	if data.has("fight"):
		quarantine = Quarantine.new()
		quarantine.setup(data.fight, _gate_cells, Game.taken.has("quarantine:" + Game.room))
		quarantine.cleared.connect(_on_quarantine_cleared)
		add_child(quarantine)

	player = Player.new()
	player.hp = Game.hp
	if Game.entry.has("pos"):
		player.position = Game.entry.pos
		player.velocity = Game.entry.vel
		player.facing = _facing_inward(Game.entry.pos.x, Game.entry.vel.x)
	else:
		player.position = start if start != Vector2.ZERO else restore_pos
	add_child(player)
	safe_pos = player.position
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
	_map_view.stage = self
	_map_view.visible = false
	_room_art.reveal = revealed


func _ready() -> void:
	super()
	refresh_text()
	hud.hp = player.hp
	hud.energy = player.sniff_energy
	hud.max_energy = Game.max_sniff()
	hud.clues = Game.clue_count()
	if boss != null:
		hud.boss_life = 1.0
	hud.get_parent().add_child(_map_view)
	if boss != null:
		show_toast(Options.t("boss_intro"), 3.0)
	else:
		show_toast(Options.t("room_" + Game.room))
	Sound.music("boss" if boss != null else "desktop")
	if Options.show_ending and Game.room != "ghost" and Game.taken.has("boss_desktop") and not Game.taken.has("ending_seen"):
		# depende do que está salvo, não de por onde o cão saiu do chefe
		Game.taken["ending_seen"] = true
		pause_menu.open_ending()
	Game.save_game()  # depois dos avisos, para uma falha de gravação aparecer


func refresh_text() -> void:
	super()
	hud.place = Options.t("boss_file" if Game.room == "ghost" else "room_" + Game.room)


func hero_dead() -> bool:
	return is_instance_valid(player) and player.hp <= 0


func _secret_key() -> String:
	return Game.room + ":secret"


func hidden_walls() -> Array[Vector2]:
	var none: Array[Vector2] = []
	return none if revealed else fake_walls


## Sólida até ser farejada de perto; depois fica aberta para sempre.
func _add_fake_wall(at: Vector2) -> void:
	fake_walls.append(at)
	if revealed:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	body.position = at
	body.add_child(shape)
	add_child(body)
	_fake_bodies.append(body)


func _update_secret(pp: Vector2) -> void:
	if revealed or fake_walls.is_empty():
		return
	var nearest := INF
	for c in fake_walls:
		nearest = minf(nearest, pp.distance_to(c))
	if sniffing and nearest < REVEAL_RANGE:
		revealed = true
		for body in _fake_bodies:
			body.queue_free()
		_fake_bodies.clear()
		Game.taken[_secret_key()] = true
		Sound.play("restore", 1.3)
		show_toast(Options.t("wall_found"))
		Game.save_game()
	elif nearest < NUDGE_RANGE and not _nudged:
		_nudged = true  # sem isto, quem nunca farejou ficaria preso
		show_toast(Options.t("wall_smells"), 3.5)
	elif nearest > NUDGE_RANGE * 3.0:
		_nudged = false


## Quem entra por uma borda olha para dentro da sala.
func _facing_inward(x: float, speed: float) -> int:
	if x < 24.0:
		return 1
	if x > MAP[0].length() * TILE - 24.0:
		return -1
	return -1 if speed < 0.0 else 1


## Quem passa pela porta renasce na Lixeira: pelo caminho normal o último
## ponto de restauração seria o pé de Drivers, uma ala inteira atrás.
func _checkpoint_at_door() -> void:
	Game.restore = {"room": Game.room, "pos": restore_pos}
	Game.save_game()


## As três pistas, ou um save de antes de elas existirem, que já passou daqui.
func door_unlocked() -> bool:
	return Game.clue_count() >= Rooms.CLUES or Game.taken.has("arena_desktop")


func overlay_open() -> bool:
	return _map_view != null and _map_view.visible


func _add_block(cx: int, cy: int, width: int, secret: bool) -> void:
	var block := SpecialBlock.new()
	block.width = width
	block.secret = secret
	block.phase = (cx * 0.37 + cy * 0.21) if not secret else 0.0  # vizinhas não somem juntas
	block.position = Vector2((cx + width / 2.0) * TILE, cy * TILE + TILE / 2.0)
	add_child(block)
	blocks.append(block)


func _add_folder(at: Vector2, mark: String) -> void:
	var doors: Dictionary = data.get("doors", {})
	if doors.has(mark):
		var door: Dictionary = doors[mark]
		var land := Vector2(door.at[0] * TILE + TILE / 2.0, door.at[1] * TILE + TILE / 2.0)
		folders.append({"at": at, "to": door.to, "land": land, "shortcut": door.shortcut})


## O atalho cai depois do portão: se abrisse na visita, pularia a quarentena.
func folder_open(folder: Dictionary) -> bool:
	return not folder.shortcut or Game.taken.has("quarantine:" + folder.to)


func _update_folders(pp: Vector2) -> bool:
	if player.hp <= 0:
		return false
	for folder in folders:
		if pp.distance_to(folder.at) >= FOLDER_RANGE or not player.is_on_floor():
			continue
		if quarantine != null and quarantine.locked():
			continue
		if not Input.is_action_just_pressed("down"):
			continue
		if folder_open(folder):
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			Sound.play("folder")
			Game.enter(folder.to, folder.land)
			return true
		if not _shut_told:
			_shut_told = true
			show_toast(Options.t("folder_shut"), 2.5)
	return false


func _clue_dug() -> bool:
	return Game.taken.has("dug:" + Game.room)


## A pista está enterrada: não se vê nem se pega sem farejar de perto.
func _update_clue(pp: Vector2) -> void:
	if clue_pos == Vector2.ZERO or player.hp <= 0:
		return
	if quarantine != null and quarantine.state != Quarantine.State.DONE:
		return  # a pista é o prêmio da quarentena
	var d := pp.distance_to(clue_pos)
	if not _clue_dug():
		if sniffing and d < DIG_RANGE:
			Game.taken["dug:" + Game.room] = true
			Sound.play("materialize", 1.3)
			show_toast(Options.t("clue_dug"))
		elif d < NUDGE_RANGE and not _clue_nudged:
			_clue_nudged = true
			show_toast(Options.t("clue_smells"), 3.0)
	elif d < 12.0:
		clue_pos = Vector2.ZERO
		Game.taken["clue:" + Game.room] = true
		Sound.play("clue")
		add_shake(3.0)
		var found := Game.clue_count()
		if found >= Rooms.CLUES:
			show_toast(Options.t("clue_all"), 4.0)
		else:
			show_toast(Options.t("clue_got") % [found, Rooms.CLUES], 3.0)
		Game.save_game()


func _update_backup(pp: Vector2) -> void:
	if backup_pos != Vector2.ZERO and pp.distance_to(backup_pos) < 11.0:
		backup_pos = Vector2.ZERO
		Game.taken["backup:" + Game.room] = true
		player.sniff_energy = Game.max_sniff()
		Game.sniff = player.sniff_energy
		Sound.play("secret")
		show_toast(Options.t("secret_got") % [Game.secret_count(), Rooms.secret_total()], 3.0)
		Game.save_game()


func _update_hazards(pp: Vector2) -> void:
	if hazards.is_empty() or player.hp <= 0:
		return
	for h in hazards:
		if absf(pp.x - h.x) < 12.0 and absf(pp.y + 2.0 - h.y) < 13.0:
			player.sink(safe_pos)
			return
	# chão firme = parede de verdade sob os dois pés (plataforma que some não conta)
	if player.is_on_floor() and _firm(pp + Vector2(-6, 10)) and _firm(pp + Vector2(6, 10)):
		safe_pos = pp


func _firm(at: Vector2) -> bool:
	var cell := Vector2i(floori(at.x / TILE), floori(at.y / TILE))
	return cell.y >= 0 and cell.y < MAP.size() and cell.x >= 0 and cell.x < MAP[0].length() and MAP[cell.y][cell.x] == "#"


func _reveal_blocks(pp: Vector2) -> void:
	if not sniffing:
		return
	for block in blocks:
		if block.secret and block.distance_to_point(pp) < SpecialBlock.REVEAL_RANGE:
			block.reveal()


func _on_quarantine_cleared() -> void:
	Game.taken["quarantine:" + Game.room] = true
	show_toast(Options.t("quarantine_clear"), 2.5)
	Game.save_game()


## O que o faro sente: [tipo, posição].
func scents() -> Array:
	var out := []
	if clue_pos != Vector2.ZERO:
		out.append(["clue", clue_pos])
	for at in hidden_walls() + chips:
		out.append(["secret", at])
	if backup_pos != Vector2.ZERO:
		out.append(["secret", backup_pos])
	return out


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
	var c := row[cell.x]
	if c == "Q":
		return quarantine != null and quarantine.locked()
	return c == "#" or c == "T" or (c == "F" and not revealed)


func is_solid_at(pos: Vector2) -> bool:
	return is_solid(Vector2i(floori(pos.x / TILE), floori(pos.y / TILE)))


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	var t := Time.get_ticks_msec()
	var corner := SPRITE / 2.0

	if sniffing or revealed:
		for c in fake_walls:
			_dashed_rect(Rect2(c - corner, SPRITE).grow(-1), ACCENT)

	for h in hazards:
		var flick := int(t / 120 + h.x) % 3
		for i in 4:
			var tall := 5 + (i * 3 + flick) % 5
			var x := h.x - 8.0 + i * 4.0
			draw_rect(Rect2(x, h.y + 8 - tall, 3, tall), ACCENT)
			draw_rect(Rect2(x + 1, h.y + 8 - tall, 1, 2), Art.WHITE)
	for folder in folders:
		Art.frame(self, _items, FOLDER if folder_open(folder) else FOLDER_SHUT, folder.at - corner, SPRITE)
		if is_instance_valid(player) and player.global_position.distance_to(folder.at) < FOLDER_RANGE + 8.0:
			var label: String = Options.t("folder_enter") % Options.t("room_" + folder.to) if folder_open(folder) else Options.t("folder_locked")
			var wide := Art.text_width(label) + 8.0
			var left := clampf(folder.at.x - wide / 2.0, 2.0, MAP[0].length() * TILE - wide - 2.0)
			var tag := Rect2(left, folder.at.y - 32.0, wide, 14)
			draw_rect(tag, Art.BLACK)
			Art.border(self, tag)
			Art.text(self, tag.position + Vector2(4, 1), label)
	if clue_pos != Vector2.ZERO and _clue_dug():
		Art.frame(self, _items, CLUE, clue_pos - corner + Vector2(0, -2 if t / 250 % 2 == 0 else 0), SPRITE)
	if backup_pos != Vector2.ZERO:
		Art.frame(self, _items, BACKUP, backup_pos - corner, SPRITE)

	for l in lasers:
		Art.frame(self, _laser_sheet, t / 60 % 3, l - corner, SPRITE)
	for p in patches:
		Art.frame(self, _items, PATCH, p - corner, SPRITE)
	for c in chips:
		Art.frame(self, _items, CHIP, c - corner + Vector2(0, -2 if t / 300 % 2 == 0 else 0), SPRITE)
	if restore_pos != Vector2.ZERO:
		var lit: bool = Game.restore.get("room", "") == Game.room
		Art.frame(self, _items, RESTORE_ON if lit else RESTORE_OFF, restore_pos - corner, SPRITE)

	var cleared: bool = Game.taken.has("boss_desktop")
	if door_pos != Vector2.ZERO:
		var look := DOOR_CLEAR if cleared else (DOOR if door_unlocked() else DOOR_LOCKED)
		Art.frame(self, _items, look, door_pos - corner, SPRITE)
	if exit_pos != Vector2.ZERO:
		Art.frame(self, _items, DOOR if cleared else DOOR_LOCKED, exit_pos - corner, SPRITE)

	if sniffing and is_instance_valid(player):
		var targets := scents()
		if not targets.is_empty():
			var from := player.global_position
			# pista primeiro; senão, o segredo mais perto
			var target: Vector2 = targets[0][1]
			if targets[0][0] != "clue":
				for scent in targets:
					if from.distance_to(scent[1]) < from.distance_to(target):
						target = scent[1]
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

	if _update_folders(pp):
		return
	_update_hazards(pp)
	_reveal_blocks(pp)
	_update_clue(pp)
	_update_backup(pp)
	if quarantine != null and player.hp > 0:
		quarantine.watch(pp)

	for p in patches.duplicate():
		if pp.distance_to(p) < 10.0:
			if player.hp >= player.MAX_HP:
				if not _patch_told:
					_patch_told = true
					show_toast(Options.t("health_full"))
				continue
			patches.erase(p)
			Game.taken[_key(p)] = true
			player.heal(1)
			show_toast(Options.t("got_health"))
			Sound.play("pickup")
			Game.save_game()

	for c in chips.duplicate():
		if pp.distance_to(c) < 12.0:
			chips.erase(c)
			Game.taken[_key(c)] = true
			Game.abilities.dash = true
			add_shake(4.0)
			Sound.play("chip")
			show_toast(Options.t("got_dash"), 3.5)
			Game.save_game()

	if restore_pos != Vector2.ZERO and pp.distance_to(restore_pos) < 12.0 and player.hp > 0:
		var fresh: bool = Game.restore.get("room", "") != Game.room
		player.hp = player.MAX_HP
		Game.restore = {"room": Game.room, "pos": restore_pos}
		if fresh:
			show_toast(Options.t("got_restore"))
			Sound.play("restore")
			Game.save_game()

	if door_pos != Vector2.ZERO and pp.distance_to(door_pos) < 12.0 and player.hp > 0:
		if Game.taken.has("boss_desktop"):
			if not _door_told:
				_door_told = true
				show_toast(Options.t("region_clean"), 3.0)
		elif not door_unlocked():
			if not _door_told:
				_door_told = true
				show_toast(Options.t("door_needs") % [Rooms.CLUES, Game.clue_count()], 3.5)
		elif Game.taken.has("arena_desktop"):
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			_checkpoint_at_door()
			Game.boss_return = {"room": Game.room, "pos": door_pos - Vector2(24, 0)}
			Sound.play("door")
			Game.enter("ghost")
			return
		else:
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			_checkpoint_at_door()
			Sound.play("door")
			Game.enter_arena(Game.room, door_pos - Vector2(24, 0))
			return
	elif door_pos != Vector2.ZERO and pp.distance_to(door_pos) > 40.0:
		_door_told = false

	_update_secret(pp)
	_room_art.reveal = sniffing or revealed
	if is_instance_valid(boss):
		hud.boss_life = float(boss.hp) / GhostFile.MAX_HP_BOSS
	else:
		hud.boss_life = -1.0

	if exit_pos != Vector2.ZERO and Game.taken.has("boss_desktop") and player.hp > 0 and pp.distance_to(exit_pos) < 10.0:
		_leaving = true
		Sound.play("door")
		Game.hp = player.hp
		set_sniffing(false)
		if Game.boss_return.is_empty():
			Game.respawn()
		else:
			Game.enter(Game.boss_return.room, Game.boss_return.pos)
		return

	_update_tension(pp)
	_check_exit(pp)
	hud.clues = Game.clue_count()
	hud.max_energy = Game.max_sniff()
	hud.hp = maxi(player.hp, 0)
	hud.energy = player.sniff_energy
	hud.sniffing = sniffing


## A camada extra da música: bug por perto ou, no chefe, a segunda fase.
func _update_tension(pp: Vector2) -> void:
	if is_instance_valid(boss):
		Sound.tension = 1.0 if boss.second_phase() else 0.0
		return
	if quarantine != null and quarantine.locked():
		Sound.tension = 1.0
		return
	var nearest := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		nearest = minf(nearest, pp.distance_to(e.global_position))
	Sound.tension = clampf((200.0 - nearest) / 120.0, 0.0, 1.0)


func _on_boss_defeated() -> void:
	Sound.music("")
	Sound.play("victory")
	Game.taken["boss_desktop"] = true
	for c in get_children():
		if c is Bullet and not c.friendly:
			c.queue_free()
	player.hp = player.MAX_HP
	show_toast(Options.t("boss_down"), 4.0)
	Game.save_game()
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
			# as aberturas ficam em linhas diferentes em cada sala
			var y := pp.y
			for back in target.links:
				if back.to == Game.room:
					y += (back.rows[1] - link.rows[1]) * TILE
					y = clampf(y, back.rows[0] * TILE + 5.0, (back.rows[1] + 1) * TILE - 8.0)
			_leaving = true
			Game.hp = player.hp
			set_sniffing(false)
			Game.enter(link.to, Vector2(x, y), player.velocity)
			return


# ------------------------------------------------------------------ Explorer

## Mapa das salas visitadas (Tab). Cada sala é um retângulo na grade da região.
class ExplorerView extends Control:
	const CELL := Vector2(32, 22)
	var stage: Stage
	var _closing := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		size = Vector2(384, 216)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _input(event: InputEvent) -> void:
		if visible:
			if event.is_action_pressed("map") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
				get_viewport().set_input_as_handled()
				close()
		elif event.is_action_pressed("map") and not get_tree().paused and not stage.hero_dead():
			get_viewport().set_input_as_handled()
			open()

	func open() -> void:
		visible = true
		_closing = false
		get_tree().paused = true
		queue_redraw()

	func close() -> void:
		if _closing:
			return
		_closing = true
		# como na pausa: senão o B que fecha vira dash
		await get_tree().physics_frame
		await get_tree().physics_frame
		visible = false
		_closing = false
		get_tree().paused = false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
		var box := Rect2(60, 32, 264, 140)
		Art.window(self, box, Options.t("explorer_title") + Options.t("room_" + Game.room))
		var origin := box.position + Vector2(22, 60)
		var blink := Time.get_ticks_msec() / 300 % 2 == 0
		var monitor := Art.texture("items")
		for id in Rooms.DATA:
			if not Game.visited.has(id):
				continue
			var r: Dictionary = Rooms.DATA[id]
			var screens: int = maxi(1, r.map[0].length() / 24)
			var floors: int = 2 if r.map.size() > 13 else 1
			var rect := Rect2(origin + Vector2(r.grid) * CELL, Vector2(screens * CELL.x - 3, floors * CELL.y - 3))
			var here: bool = id == Game.room
			draw_rect(rect, Art.ACCENT if here and blink else Art.SHADE)
			Art.border(self, rect)
			if Game.restore.get("room", "") == id:
				Art.frame(self, monitor, 1, rect.position + Vector2(2, 2), Vector2(16, 16))
			if Game.taken.has("clue:" + id):
				Art.frame(self, monitor, 9, rect.end - Vector2(16, 16), Vector2(16, 16))
		Art.frame(self, monitor, 1, box.position + Vector2(8, box.size.y - 21), Vector2(16, 16))
		Art.text(self, box.position + Vector2(28, box.size.y - 18), Options.t("explorer_legend"), Art.MID)
