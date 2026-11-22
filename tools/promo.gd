extends SceneTree
## Vídeo de divulgação, em inglês: gancho, gameplay com frases curtas e o nome.
## Todo plano de jogo é o jogo rodando, controlado por este roteiro. Só promete
## o que existe no build. Chamado por tools/make_promo.sh.
##
## Imprime "PROMO ok/FALHOU <plano>" para a gravação não passar com plano vazio.

const T := 16
const ACTIONS := ["left", "right", "up", "down", "jump", "shoot", "dash", "sniff", "aim_left", "aim_right", "aim_up", "aim_down"]
const CHARGE := 4
const STUNNED := 5
const GAIN_DB := 4.0   # rede social toca mais alto que jogo; o limitador segura o pico

const WHITE := Color("f3f3ee")
const ACCENT := Color("2fb5a8")
const GREY := Color("7c7c78")

var G: Node
var S: Node
var over: Overlay


## Cartelas, legendas e glitch por cima de tudo, na fonte do jogo.
class Overlay extends Control:
	var card: Array = []          # [[texto, cor, escala], ...] em tela cheia
	var terminal: Array = []      # linhas digitadas
	var caption := ""
	var glitch := 0
	var ending := false
	var age := 0
	var hound: Texture2D
	var ghost: Texture2D

	func _ready() -> void:
		size = Vector2(384, 216)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		hound = load("res://art/hound.png")
		ghost = load("res://art/ghost.png")

	func _process(_delta: float) -> void:
		age += 1
		glitch = maxi(glitch - 1, 0)
		var scene := get_tree().current_scene
		if scene != null and scene.get("toast") != null:
			scene.toast.modulate.a = 0.0   # as frases do vídeo ocupam esse lugar
		queue_redraw()

	func _width(text: String, times: int) -> float:
		return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11 * times).x

	func _text(x: float, top: float, text: String, color: Color, times: int) -> void:
		draw_string(ThemeDB.fallback_font, Vector2(x, top + 10 * times).floor(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11 * times, color)

	func _center(top: float, text: String, color: Color, times: int) -> void:
		_text(192.0 - _width(text, times) / 2.0, top, text, color, times)

	func _draw() -> void:
		if not terminal.is_empty():
			draw_rect(Rect2(0, 0, 384, 216), Color.BLACK)
			for i in terminal.size():
				var line: Array = terminal[i]
				_text(36, 46 + i * 28, line[0], line[1], 2)
			if age / 14 % 2 == 0:
				var last: Array = terminal[-1]
				draw_rect(Rect2(38 + _width(last[0], 2), 52 + (terminal.size() - 1) * 28, 8, 14), WHITE)
		elif not card.is_empty():
			draw_rect(Rect2(0, 0, 384, 216), Color.BLACK)
			var total := 0
			for row in card:
				total += 12 * row[2] + 4
			var y := (216 - total) / 2.0
			for row in card:
				_center(y, row[0], row[1], row[2])
				y += 12 * row[2] + 4
		elif ending:
			draw_rect(Rect2(0, 0, 384, 216), Color.BLACK)
			var name_w := _width("HOUND.EXE", 5)
			var x := 192.0 - name_w / 2.0
			_text(x, 28, "HOUND", WHITE, 5)
			_text(x + _width("HOUND", 5), 28, ".EXE", ACCENT, 5)
			_center(94, "A 1-bit action metroidvania", WHITE, 2)
			draw_rect(Rect2(0, 182, 384, 2), WHITE)
			var step := age / 9 % 2
			draw_set_transform(Vector2(106, 150), 0.0, Vector2(2, 2))
			draw_texture_rect_region(hound, Rect2(0, 0, 24, 16), Rect2((9 + step) * 24, 0, 24, 16))
			draw_set_transform(Vector2(236, 120 + step * 2), 0.0, Vector2(2, 2))
			draw_texture_rect_region(ghost, Rect2(0, 0, 32, 36), Rect2(32, 0, 32, 36))
			draw_set_transform(Vector2.ZERO)
			for i in 8:
				if (i - age / 6) % 3 != 0:
					draw_rect(Rect2(160 + i * 9, 176, 3, 3), ACCENT)
			_center(192, "Good dog. Bad files.", GREY, 1)

		if caption != "":
			var w := _width(caption, 2) + 18.0
			var box := Rect2(floorf(192.0 - w / 2.0), 21, ceilf(w), 27)
			draw_rect(box, WHITE)
			draw_rect(Rect2(box.position + Vector2(0, box.size.y), Vector2(box.size.x, 2)), ACCENT)
			_center(23, caption, Color.BLACK, 2)

		# corte em glitch: faixas que encolhem
		for i in glitch * 3:
			var band := hash(Vector2i(i, age))
			draw_rect(Rect2(band % 300, (band / 7) % 216, 30 + (band / 3) % 160, 1 + band % 6), [WHITE, ACCENT, Color.BLACK][band % 3])


func _initialize() -> void:
	G = root.get_node("Game")
	S = root.get_node("Sound")
	process_frame.connect(_draw_if_covered)
	_run()


func _draw_if_covered() -> void:
	# com a janela coberta o macOS não desenha, e o Movie Maker repete o quadro
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)


func _report(shot: String, ok: bool) -> void:
	print("PROMO %s %s" % ["ok" if ok else "FALHOU", shot])


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _release() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)


func _hold(action: String, on := true) -> void:
	if on != Input.is_action_pressed(action):
		if on:
			Input.action_press(action)
		else:
			Input.action_release(action)


func _show_card(rows: Array, frames: int, sound: String) -> void:
	over.caption = ""
	over.terminal = []
	over.card = rows
	over.glitch = 4
	S.play(sound)
	await _frames(frames)


func _cut(room: String, pos: Vector2, caption: String) -> Node:
	_release()
	paused = false
	over.terminal = []
	G.enter(room, pos)
	await _frames(3)
	over.card = []
	over.caption = caption
	over.glitch = 5
	return current_scene


func _type(text: String, color: Color, speed: int) -> void:
	over.terminal.append(["", color])
	for i in text.length():
		over.terminal[-1][0] = text.substr(0, i + 1)
		if i % 2 == 0:
			S.play("ui_move")
		await _frames(speed)


func _run() -> void:
	await process_frame
	root.get_node("Options").language = "en"
	RenderingServer.set_default_clear_color(Color.BLACK)
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	over = Overlay.new()
	layer.add_child(over)
	for bus in ["Music", "Effects"]:
		var i := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(i, GAIN_DB)
	G.new_game()

	await _hook()
	await _shooting()
	await _hidden()
	await _quarantine()
	await _chip()
	await _laser()
	await _sniffing()
	await _arena()
	await _boss()
	await _ending()

	await S.shutdown()
	quit()


# ---------------------------------------------------------------- planos

func _hook() -> void:
	over.glitch = 10  # o primeiro quadro já chama atenção
	over.terminal = [["C:\\> scan", WHITE]]
	await _frames(14)
	S.play("ghost_phase")
	over.glitch = 6
	over.terminal.append(["CORRUPTION DETECTED", ACCENT])
	await _frames(34)
	await _type("C:\\> run hound.exe", WHITE, 2)
	await _frames(14)
	await _show_card([["GOOD DOG.", WHITE, 5]], 50, "ui_ok")
	await _show_card([["BAD FILES.", ACCENT, 5]], 50, "ghost_stun")


func _shooting() -> void:
	var s = await _cut("docs", Vector2(150, 168), "RUN. JUMP. SHOOT.")
	var bugs := get_nodes_in_group("enemy").size()
	var p = s.player
	p.facing = 1
	_hold("right")
	await _frames(18)
	_hold("right", false)
	_hold("shoot")
	for i in 84:
		await physics_frame
		if get_nodes_in_group("enemy").size() < bugs:
			break
	_report("tiro mata bug", get_nodes_in_group("enemy").size() < bugs)
	_hold("right")
	_hold("jump")
	await _frames(22)
	_release()
	await _frames(14)


func _hidden() -> void:
	var s = await _cut("images", Vector2(13 * T + 8, 440), "REVEAL HIDDEN FILES.")
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	await _frames(14)
	_hold("sniff")
	await _frames(30)
	_hold("sniff", false)
	_report("materializa arquivo oculto", s.blocks.any(func(b): return b.secret and b.active))
	await _frames(50)


func _quarantine() -> void:
	G.hp = 5
	G.sniff = 100.0
	var s = await _cut("gallery", Vector2(20 * T, 168), "BREAK QUARANTINE.")
	await _frames(8)
	_report("quarentena tranca", s.quarantine.locked())
	s.player.facing = 1
	_hold("shoot")
	await _frames(95)
	_release()
	await _frames(20)


func _chip() -> void:
	G.taken["quarantine:installers"] = true
	await _cut("installers", Vector2(40 * T + 8, 168), "FIND NEW TOOLS.")
	for e in get_nodes_in_group("enemy"):
		e.queue_free()
	_hold("right")
	await _frames(40)
	_release()
	await _frames(62)
	_report("pega o chip", G.abilities.dash)


func _laser() -> void:
	await _cut("docs", Vector2(38 * T, 168), "DASH THROUGH DANGER.")
	for e in get_nodes_in_group("enemy"):
		if e.global_position.distance_to(Vector2(40 * T, 168)) < 40.0:
			e.queue_free()
	await _frames(14)
	_hold("right")
	var crossed := false
	for i in 100:
		await physics_frame
		if G.room != "docs" or not is_instance_valid(current_scene):
			break
		var x: float = current_scene.player.global_position.x
		_hold("dash", 712.0 - x < 34.0 and x < 712.0)
		if x > 730.0:
			crossed = true
			break
	_release()
	_report("atravessa o laser", crossed)
	await _frames(26)


func _sniffing() -> void:
	for id in ["gallery", "installers", "drivers"]:
		G.taken["clue:" + id] = true
	var s = await _cut("trash", Vector2(36 * T, 168), "SNIFF OUT SECRETS.")
	for e in get_nodes_in_group("enemy"):
		if e.global_position.y > 150.0:
			e.queue_free()
	await _frames(8)
	_hold("sniff")
	await _frames(30)
	_hold("right")
	for i in 100:
		await physics_frame
		if s.revealed:
			break
	_hold("sniff", false)
	_report("abre a parede", s.revealed)
	await _frames(45)
	_release()


func _arena() -> void:
	_release()
	seed(7)
	G.hp = 5
	G.enter_arena("trash", Vector2(720, 168))
	await _frames(4)
	over.caption = "DIVE INTO PROCESSES."
	over.glitch = 5
	var a = current_scene
	a._wave = 2
	a._wave_t = 0.1
	a._sector_t = 1.0
	for i in 300:
		if i == 120:
			over.caption = "NEVER STAND STILL."
			over.glitch = 3
		var h = a.hound
		var near: Node2D = null
		for e in get_nodes_in_group("enemy"):
			if near == null or h.global_position.distance_to(e.global_position) < h.global_position.distance_to(near.global_position):
				near = e
		_release()
		_hold(["up", "right", "down", "left"][int(i / 62) % 4])
		if near != null:
			var aim: Vector2 = (near.global_position - h.global_position).normalized()
			if absf(aim.x) > 0.05:
				Input.action_press("aim_right" if aim.x > 0 else "aim_left", absf(aim.x))
			if absf(aim.y) > 0.05:
				Input.action_press("aim_down" if aim.y > 0 else "aim_up", absf(aim.y))
		_hold("shoot")
		await physics_frame
	_report("sala de cima sem morrer", a.hound.hp > 0)


## Joga a luta por até `limit` quadros. Para quando o chefe cai ou `until` vira verdade.
func _fight(limit: int, until: Callable) -> void:
	var b = current_scene.boss
	var p = current_scene.player
	var dash_for := 0
	for i in limit:
		if not is_instance_valid(b) or p.hp <= 0 or until.call(b):
			break
		var d: float = b.global_position.x - p.global_position.x
		var toward := "right" if d > 0.0 else "left"
		var close: bool = b.state == CHARGE and absf(b.lane - p.global_position.y) < 18.0 and absf(d) < 55.0
		_release()
		if close or (b.state == STUNNED and (absf(d) > 90.0 or p.facing != signi(int(d)))):
			_hold(toward)
		if b.state == STUNNED:
			_hold("shoot")
			if b.second_phase():
				_hold("sniff")
		dash_for -= 1
		if close and dash_for < -20:
			dash_for = 4
		if dash_for > 1:
			_hold("dash")
		await physics_frame
	_release()


func _boss() -> void:
	G.hp = 5
	G.sniff = 100.0
	await _show_card([["THEN THERE'S", WHITE, 3], ["THE GHOST FILE.", ACCENT, 4]], 64, "ghost_warn")

	# primeira fase: investida, dash, atordoado
	var s = await _cut("ghost", Vector2(96, 168), "DODGE THE CHARGE.")
	s.boss.hp = 42
	s.boss._drift()
	s.boss._position_for_charge()
	await _fight(300, func(b): return b.second_phase())
	_report("chega a segunda fase", is_instance_valid(s.boss) and s.boss.second_phase())
	await _frames(12)

	# segunda fase: cópias, e só o faro acerta
	G.sniff = 100.0
	G.hp = 5
	s = await _cut("ghost", Vector2(96, 168), "TRUST YOUR NOSE.")
	s.boss.hp = 12
	s.boss._drift()
	s.boss._position_for_charge()
	await _fight(420, func(_b): return false)
	_report("derruba o chefe", G.taken.has("boss_desktop"))
	over.caption = ""
	await _frames(42)


func _ending() -> void:
	_release()
	over.glitch = 8
	over.caption = ""
	over.card = []
	over.ending = true
	if current_scene != null:
		current_scene.queue_free()
	S.muffled = false
	S.music("title")
	await _frames(240)
