class_name Player
extends CharacterBody2D
## O cão: correr, pular (coyote time + jump buffer + pulo variável), dash e tiro em 3 direções.

const MAX_HP := 5
const RUN := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const GRAVITY := 900.0
const MAX_FALL := 280.0
const JUMP := -265.0
const JUMP_CUT := 0.45        # soltar o pulo cedo corta a subida
const COYOTE := 0.1
const BUFFER := 0.12
const DASH_SPEED := 270.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.45
const FIRE_RATE := 0.13
const IFRAMES := 0.8

var hp := MAX_HP
var facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _fire_cd := 0.0
var _iframes := 0.0
var _recoil := 0.0
var _air_dash := true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 12)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)
	add_to_group("player")


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("left", "right")
	if dir != 0.0:
		facing = signi(int(signf(dir)))

	_coyote = COYOTE if is_on_floor() else maxf(_coyote - delta, 0.0)
	_buffer = BUFFER if Input.is_action_just_pressed("jump") else maxf(_buffer - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_recoil = move_toward(_recoil, 0.0, delta * 600.0)
	if is_on_floor():
		_air_dash = true

	if _dash_t > 0.0:
		# durante o dash: linha reta, sem gravidade, invulnerável
		_dash_t -= delta
		velocity = Vector2(facing * DASH_SPEED, 0.0)
	else:
		velocity.x = move_toward(velocity.x, dir * RUN, (ACCEL if dir != 0.0 else FRICTION) * delta) + _recoil
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

		if _buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP
			_buffer = 0.0
			_coyote = 0.0
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= JUMP_CUT

		if Input.is_action_just_pressed("dash") and _dash_cd == 0.0 and (is_on_floor() or _air_dash):
			_dash_t = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			_iframes = maxf(_iframes, DASH_TIME)
			if not is_on_floor():
				_air_dash = false

	if Input.is_action_pressed("shoot") and _fire_cd == 0.0:
		_shoot()

	move_and_slide()
	_check_contact_damage()
	queue_redraw()


func _shoot() -> void:
	_fire_cd = FIRE_RATE
	var aim := Vector2(facing, 0)
	if Input.is_action_pressed("up"):
		aim = Vector2(0, -1) if Input.get_axis("left", "right") == 0.0 else Vector2(facing, -1).normalized()
	var b := Bullet.new()
	b.setup(aim, true)
	b.global_position = global_position + Vector2(facing * 8, 1) + aim * 4
	get_parent().add_child(b)
	if aim.y == 0.0:
		_recoil = -facing * 25.0  # um pequeno coice dá peso ao tiro
	get_parent().add_shake(1.0)


func _check_contact_damage() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if global_position.distance_to(e.global_position) < 13.0:
			take_damage(1, e.global_position)


func take_damage(amount: int, from: Vector2) -> void:
	if _iframes > 0.0 or hp <= 0:
		return
	hp -= amount
	_iframes = IFRAMES
	velocity = Vector2(signf(global_position.x - from.x) * 140.0, -160.0)
	var main := get_parent()
	main.add_shake(4.0)
	main.hitstop(0.06)
	if hp <= 0:
		main.show_banner("TELA AZUL\n\nUm erro fatal ocorreu no hound.exe.\nPressione R para reiniciar.", Color(0.45, 0.6, 1.0))
		set_physics_process(false)
		visible = false


func _draw() -> void:
	# cão provisório em blocos (corpo, cabeça, orelha, rabo e patas)
	if _iframes > 0.0 and _dash_t <= 0.0 and int(_iframes * 20.0) % 2 == 0:
		return
	var c := Color(0.55, 0.85, 1.0) if _dash_t > 0.0 else Color.WHITE
	var f := float(facing)
	var flip := func(r: Rect2) -> Rect2:
		return r if f > 0 else Rect2(Vector2(-r.position.x - r.size.x, r.position.y), r.size)
	draw_rect(flip.call(Rect2(-6, -1, 10, 6)), c)        # corpo
	draw_rect(flip.call(Rect2(3, -5, 5, 6)), c)          # cabeça
	draw_rect(flip.call(Rect2(7, -3, 2, 3)), c)          # focinho
	draw_rect(flip.call(Rect2(3, -7, 2, 2)), c)          # orelha
	draw_rect(flip.call(Rect2(5, -3, 1, 1)), Color.BLACK)  # olho
	draw_rect(flip.call(Rect2(-8, -2, 2, 1)), c)         # rabo
	var step := int(Time.get_ticks_msec() / 120) % 2 if absf(velocity.x) > 10.0 and is_on_floor() else 0
	for lx in [-5, -2, 1, 3]:
		draw_rect(flip.call(Rect2(lx + step, 5, 1, 3)), c)  # patas
	if _dash_t > 0.0:
		for i in 3:
			draw_rect(flip.call(Rect2(-12 - i * 5, i * 2 - 1, 3, 1)), c)
