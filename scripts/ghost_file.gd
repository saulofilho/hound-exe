class_name GhostFile
extends Enemy
## Arquivo Fantasma, chefe da Área de trabalho.
##
## Ciclo: FLUTUA (atira) → POSICIONA → AVISA (mostra a linha) → AVANÇA → ATORDOADO.
## Primeira fase: leva tiro atordoado ou farejado (aí o dano é dobrado).
## Segunda fase: acelera, atira em leque, cria cópias, e só o faro acerta.
## A investida tira 2 de vida: quem não sai da linha não chega ao fim.

signal defeated

enum State { INTRO, DRIFT, POSITION, AIM, CHARGE, STUNNED }

# mais que duas janelas de dano inteiras (cerca de 46): quem não desvia morre
# na terceira investida, antes de conseguir a terceira janela
const MAX_HP_BOSS := 64
const LANES := [168.0, 136.0, 104.0]  # chão, plataformas laterais, plataforma do meio
const LEFT_X := 30.0                  # cola na parede: não sobra canto seguro
const RIGHT_X := 354.0
const PERCH_Y := 70.0
const FALL_Y := 162.0                 # atordoado, cai ao alcance do tiro reto
const CONTACT := 17.0
const CHARGE_DAMAGE := 2
const SPRITE_SIZE := Vector2(32, 36)

var state: State = State.INTRO
var lane: float = LANES[0]
var side := 1                         # 1 = direita da sala, -1 = esquerda
var _left := 1.6                      # tempo que falta no estado atual
var _shot_t := 0.0
var _player: Node2D
var _hint_t := 0.0
var _sheet: Texture2D


func _init() -> void:
	sound_kind = "ghost"


func _ready() -> void:
	hp = MAX_HP_BOSS
	contact_radius = 0.0
	contact_damage = CHARGE_DAMAGE
	collision_layer = 0
	_sheet = Art.texture("ghost")
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
	if state == State.INTRO:
		return false
	if get_parent().sniffing:
		return true
	return state == State.STUNNED and not second_phase()


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
				Sound.play("ghost_warn")
				_left = 0.65 if second_phase() else 0.85
		State.AIM:
			if _left <= 0.0:
				state = State.CHARGE
				Sound.play("ghost_charge")
				contact_radius = CONTACT
		State.CHARGE:
			var speed := 270.0 if second_phase() else 225.0
			position.x = move_toward(position.x, _edge(-side), speed * delta)
			# confere aqui também: o último passo antes da parede tem que pegar o canto
			if global_position.distance_to(_player.global_position) < CONTACT:
				_player.take_damage(CHARGE_DAMAGE, global_position)
			if is_equal_approx(position.x, _edge(-side)):
				_stun()
		State.STUNNED:
			_teach_sniff(delta)
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
	Sound.play("ghost_stun")


## Segunda fase, atordoado, e o jogador atira sem farejar: diz por que não pega.
func _teach_sniff(delta: float) -> void:
	_hint_t = maxf(_hint_t - delta, 0.0)
	if _hint_t == 0.0 and second_phase() and not get_parent().sniffing and Input.is_action_pressed("shoot"):
		_hint_t = 4.0
		get_parent().show_toast(Options.t("boss_need_sniff"), 2.5)


func _fire() -> void:
	_shot_t = 1.0
	Sound.play("ghost_fire")
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
	Sound.play("ghost_die" if hp == 0 else "ghost_hit", 1.0, 0.08)
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
		Sound.play("ghost_phase")
		main.show_toast(Options.t("boss_copies"), 3.0)


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	var main := get_parent()
	if state == State.STUNNED and second_phase() and not main.sniffing:
		# caído entre as cópias: intangível até o faro separar o original
		var inward := 1.0 if position.x < 192.0 else -1.0  # as cópias ficam dentro da sala
		for dx in [30.0, 60.0]:
			_draw_file(Vector2(dx * inward, 0), false)
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


## `solid` = dá para acertar. A folha ghost.png tem os cinco estados.
func _draw_file(off: Vector2, solid: bool) -> void:
	var look := 1  # escondido
	if _flash > 0.0:
		look = 4
	elif state == State.STUNNED and solid:
		look = 3
	elif state == State.CHARGE:
		look = 2
	elif solid:
		look = 0
	Art.frame(self, _sheet, look, (off - Vector2(16, 19)).round(), SPRITE_SIZE)
	if off == Vector2.ZERO and solid:
		draw_weak_point(off + Vector2(0, 2))
