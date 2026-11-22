class_name GhostFile
extends Enemy
## Arquivo Fantasma, chefe da Área de trabalho.
##
## Ciclo: FLUTUA (atira) → POSICIONA → AVISA (mostra a linha) → AVANÇA → ATORDOADO.
## Só leva tiro atordoado ou enquanto o cão fareja (aí o dano é dobrado).
## Com metade da vida, acelera, atira em leque e mostra cópias falsas nas outras
## linhas; o faro apaga as cópias.

signal defeated

enum State { INTRO, DRIFT, POSITION, AIM, CHARGE, STUNNED }

const MAX_HP_BOSS := 48
const LANES := [168.0, 136.0, 104.0]  # chão, plataformas laterais, plataforma do meio
const LEFT_X := 36.0
const RIGHT_X := 348.0
const PERCH_Y := 70.0
const FALL_Y := 162.0                 # atordoado, cai ao alcance do tiro reto
const CONTACT := 17.0
const PAPER := Color(0.92, 0.92, 0.86)

var state: State = State.INTRO
var lane: float = LANES[0]
var side := 1                         # 1 = direita da sala, -1 = esquerda
var _left := 1.6                      # tempo que falta no estado atual
var _shot_t := 0.0
var _player: Node2D


func _ready() -> void:
	hp = MAX_HP_BOSS
	contact_radius = 0.0
	collision_layer = 0
	collision_mask = 0  # é um fantasma: atravessa plataformas
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 30)
	shape.shape = rect
	add_child(shape)
	add_to_group("enemy")
	_player = get_tree().get_first_node_in_group("player") as Node2D


func second_phase() -> bool:
	return hp * 2 <= MAX_HP_BOSS


func is_vulnerable() -> bool:
	return state != State.INTRO and (state == State.STUNNED or get_parent().sniffing)


func _physics_process(delta: float) -> void:
	tick(delta)
	if not is_instance_valid(_player) or not _player.visible:
		return
	_left -= delta
	match state:
		State.INTRO:
			if _left <= 0.0:
				_drift()
		State.DRIFT:
			# paira do lado oposto ao cão
			var away := 270.0 if _player.global_position.x < 192.0 else 114.0
			var perch := Vector2(away, PERCH_Y + sin(_left * 4.0) * 6.0)
			position = position.move_toward(perch, 90.0 * delta)
			_shot_t -= delta
			if _shot_t <= 0.0:
				_fire()
			if _left <= 0.0:
				_position_for_charge()
		State.POSITION:
			var start := Vector2(_edge(side), lane)
			position = position.move_toward(start, 320.0 * delta)
			if position.is_equal_approx(start):
				state = State.AIM
				_left = 0.65 if second_phase() else 0.85
		State.AIM:
			if _left <= 0.0:
				state = State.CHARGE
				contact_radius = CONTACT
		State.CHARGE:
			var speed := 270.0 if second_phase() else 225.0
			position.x = move_toward(position.x, _edge(-side), speed * delta)
			if is_equal_approx(position.x, _edge(-side)):
				_stun()
		State.STUNNED:
			position.y = move_toward(position.y, FALL_Y, 220.0 * delta)
			if _left <= 0.0:
				_drift()
	# intangível = os tiros passam direto
	collision_layer = 4 if is_vulnerable() else 0


func _edge(which: int) -> float:
	return RIGHT_X if which > 0 else LEFT_X


func _drift() -> void:
	state = State.DRIFT
	contact_radius = 0.0
	_left = 1.6 if second_phase() else 2.2
	_shot_t = 0.7


func _position_for_charge() -> void:
	state = State.POSITION
	side = 1 if _player.global_position.x < 192.0 else -1
	# trava na linha mais perto da altura do cão
	lane = LANES[0]
	for y in LANES:
		if absf(y - _player.global_position.y) < absf(lane - _player.global_position.y):
			lane = y


func _stun() -> void:
	state = State.STUNNED
	contact_radius = 0.0
	_left = 1.8 if second_phase() else 2.2
	get_parent().add_shake(6.0)


func _fire() -> void:
	_shot_t = 1.0
	var aim := (_player.global_position - global_position).normalized()
	var angles := [-0.35, 0.0, 0.35] if second_phase() else [0.0]
	for a in angles:
		var b := Bullet.new()
		b.setup(aim.rotated(a), false)
		b.global_position = global_position + aim * 10.0
		get_parent().add_child(b)


func hit(amount: int, _dir: Vector2) -> void:
	if hp <= 0 or not _player.visible:
		return
	var was_second := second_phase()
	hp = maxi(hp - amount, 0)
	_flash = 0.06
	var main := get_parent()
	main.add_shake(2.5 if amount > 1 else 1.5)
	if hp == 0:
		main.add_shake(9.0)
		main.hitstop(0.18)
		_burst()
		defeated.emit()
		queue_free()
	elif second_phase() and not was_second:
		main.add_shake(6.0)
		main.show_toast("O arquivo criou cópias. Fareje o original.", 3.0)


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	var main := get_parent()
	if state == State.AIM or state == State.CHARGE:
		var shown: Array = [lane]
		if second_phase() and not main.sniffing:
			shown = LANES
		for y in shown:
			var off := Vector2(0, y - position.y)
			if state == State.AIM:
				_draw_warning(off)
			if y != lane:
				_draw_file(off, false)  # cópia: igual ao original, mas inofensiva
	_draw_file(Vector2.ZERO, is_vulnerable())


func _draw_warning(off: Vector2) -> void:
	if int(_left * 12.0) % 2 != 0:
		return
	var reach := _edge(-side) - position.x
	var i := 22.0
	while i < absf(reach):
		draw_rect(Rect2(off + Vector2(signf(reach) * i - 2.0, 1), Vector2(5, 2)), BUG_COLOR)
		i += 10.0


## Uma folha de canto dobrado e barra rasgada. `solid` = dá para acertar.
func _draw_file(off: Vector2, solid: bool) -> void:
	var shape := PackedVector2Array([
		Vector2(-12, -15), Vector2(6, -15), Vector2(12, -9), Vector2(12, 14),
		Vector2(8, 10), Vector2(4, 15), Vector2(0, 10), Vector2(-4, 15),
		Vector2(-8, 10), Vector2(-12, 14),
	])
	for i in shape.size():
		shape[i] += off
	var charging := state == State.CHARGE
	var fill := PAPER
	if _flash > 0.0:
		fill = BUG_COLOR
	elif not solid:
		fill.a = 0.55 if charging else 0.16
	draw_colored_polygon(shape, fill)

	var edge := BUG_COLOR if charging else PAPER
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, edge, 1.0)
	draw_polyline(PackedVector2Array([off + Vector2(6, -15), off + Vector2(6, -9), off + Vector2(12, -9)]), edge, 1.0)

	var ink := Color.BLACK if solid else edge
	if state == State.STUNNED:
		# olhos em X
		for ex in [-5.0, 4.0]:
			draw_line(off + Vector2(ex - 2, -5), off + Vector2(ex + 2, -1), ink)
			draw_line(off + Vector2(ex + 2, -5), off + Vector2(ex - 2, -1), ink)
	else:
		draw_rect(Rect2(off + Vector2(-7, -6), Vector2(4, 5)), ink)
		draw_rect(Rect2(off + Vector2(2, -6), Vector2(4, 5)), ink)
	for i in 3:
		draw_rect(Rect2(off + Vector2(-7, 2 + i * 3), Vector2(13 - i * 3, 1)), ink)
	if off == Vector2.ZERO and solid:
		draw_weak_point(off + Vector2(0, 2))
