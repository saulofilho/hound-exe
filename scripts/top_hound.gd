class_name TopHound
extends CharacterBody2D
## O cão visto de cima: move em 8 direções, mira com mouse ou analógico direito.

const MAX_HP := 5
const SPEED := 105.0
const ACCEL := 1100.0
const DASH_SPEED := 260.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.45
const FIRE_RATE := 0.12
const IFRAMES := 0.8

var hp := MAX_HP
var aim := Vector2.RIGHT
var _move_dir := Vector2.RIGHT
var _mouse_aim := false
var _dash_t := 0.0
var _dash_cd := 0.0
var _fire_cd := 0.0
var _iframes := 0.0
var _sheet: Texture2D


func _ready() -> void:
	_sheet = Art.texture("top_hound")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	add_to_group("player")
	hp = clampi(Game.hp, 1, MAX_HP)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_aim = true


func _physics_process(delta: float) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)

	var move := Input.get_vector("left", "right", "up", "down")
	if move != Vector2.ZERO:
		_move_dir = move.normalized()

	# mira: analógico direito > mouse > direção do movimento
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		aim = stick.normalized()
		_mouse_aim = false
	elif _mouse_aim and get_global_mouse_position() != global_position:
		aim = (get_global_mouse_position() - global_position).normalized()
	elif move != Vector2.ZERO:
		aim = _move_dir

	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _move_dir * DASH_SPEED
	else:
		velocity = velocity.move_toward(move * SPEED, ACCEL * delta)
		if Input.is_action_just_pressed("dash") and _dash_cd == 0.0:
			_dash_t = DASH_TIME
			Sound.play("dash")
			_dash_cd = DASH_COOLDOWN
			_iframes = maxf(_iframes, DASH_TIME)

	if Input.is_action_pressed("shoot") and _fire_cd == 0.0:
		_fire_cd = FIRE_RATE
		var b := Bullet.new()
		b.setup(aim, true)
		Sound.play("shoot", 1.0, 0.06)
		b.global_position = global_position + aim * 9.0
		get_parent().add_child(b)
		get_parent().add_shake(0.8)

	move_and_slide()
	for e in get_tree().get_nodes_in_group("enemy"):
		if global_position.distance_to(e.global_position) < 11.0:
			take_damage(1, e.global_position)
	queue_redraw()


func take_damage(amount: int, from: Vector2) -> void:
	if _iframes > 0.0 or hp <= 0:
		return
	hp -= amount
	_iframes = IFRAMES
	velocity = (global_position - from).normalized() * 160.0
	var stage := get_parent()
	stage.add_shake(4.0)
	stage.hitstop(0.06)
	Sound.play("death" if hp <= 0 else "hurt")
	if hp <= 0:
		Game.died()
		stage.show_banner(Options.t("death_top"), Color("1c2fa8"))
		set_physics_process(false)
		visible = false


func _draw() -> void:
	if _iframes > 0.0 and _dash_t <= 0.0 and int(_iframes * 20.0) % 2 == 0:
		return
	var step := Time.get_ticks_msec() / 90 % 4 if velocity.length() > 15.0 else 1
	if _dash_t > 0.0:
		draw_set_transform(-_move_dir * 9.0, aim.angle())
		Art.frame(self, _sheet, step, Vector2(-12, -12), Vector2(24, 24), Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO, aim.angle())   # tudo virado para a mira
	Art.frame(self, _sheet, step, Vector2(-12, -12), Vector2(24, 24))
	draw_rect(Rect2(14, 0, 2, 1), Art.MID)          # indicador de mira
	draw_set_transform(Vector2.ZERO)
