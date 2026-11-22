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
const SNIFF_DRAIN := 35.0     # energia por segundo real farejando
const SNIFF_REGEN := 14.0
const SNIFF_MIN := 15.0       # energia mínima para começar a farejar

var hp := MAX_HP
var sniff_energy := 100.0
var facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _dash_t := 0.0
var _dash_dir := 1
var _dash_cd := 0.0
var _fire_cd := 0.0
var _iframes := 0.0
var _recoil := 0.0
var _air_dash := true
var _scent_t := 0.0
var _sheet: Texture2D


func _ready() -> void:
	_sheet = Art.texture("hound")
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
		if _dash_t <= 0.0:
			if _laser_in_path() and not is_on_wall():
				# nunca termina dentro (ou colado) de um laser: segue até sair do outro lado
				_dash_t = delta
				_iframes = maxf(_iframes, delta * 2.0)
			else:
				_dash_t = 0.0
		# ao terminar, perde o embalo, para não deslizar para dentro do perigo
		velocity = Vector2(_dash_dir * (DASH_SPEED if _dash_t > 0.0 else RUN), 0.0)
	else:
		velocity.x = move_toward(velocity.x, dir * RUN, (ACCEL if dir != 0.0 else FRICTION) * delta) + _recoil
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

		if _buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP
			Sound.play("jump")
			_buffer = 0.0
			_coyote = 0.0
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y *= JUMP_CUT

		if Input.is_action_just_pressed("dash") and Game.abilities.dash and _dash_cd == 0.0 and (is_on_floor() or _air_dash):
			_dash_t = DASH_TIME
			_dash_dir = facing
			Sound.play("dash")
			_dash_cd = DASH_COOLDOWN
			_iframes = maxf(_iframes, DASH_TIME)
			if not is_on_floor():
				_air_dash = false

	_update_sniff(delta)
	if Input.is_action_pressed("shoot") and _fire_cd == 0.0:
		_shoot()

	# lasers (camada 5) só deixam passar durante o dash
	collision_mask = 1 if _dash_t > 0.0 else 1 | 16
	var was_airborne := not is_on_floor()
	var falling := velocity.y
	move_and_slide()
	if was_airborne and is_on_floor() and falling > 120.0:
		Sound.play("land")
	_check_contact_damage()
	queue_redraw()


func _shoot() -> void:
	_fire_cd = FIRE_RATE
	var aim := Vector2(facing, 0)
	if Input.is_action_pressed("up"):
		aim = Vector2(0, -1) if Input.get_axis("left", "right") == 0.0 else Vector2(facing, -1).normalized()
	var b := Bullet.new()
	b.setup(aim, true)
	Sound.play("shoot", 1.0, 0.06)
	if get_parent().sniffing:
		b.damage = 2  # o faro mostra o ponto fraco: tiro dobrado
	b.global_position = global_position + Vector2(facing * 8, 1) + aim * 4
	get_parent().add_child(b)
	if aim.y == 0.0:
		_recoil = -facing * 25.0  # um pequeno coice dá peso ao tiro
	get_parent().add_shake(1.0)


func _update_sniff(delta: float) -> void:
	var stage := get_parent()
	var real := delta / maxf(Engine.time_scale, 0.05)  # a energia corre em tempo real
	var can := sniff_energy > (0.0 if stage.sniffing else SNIFF_MIN)
	stage.set_sniffing(Input.is_action_pressed("sniff") and can and hp > 0)
	if stage.sniffing:
		sniff_energy = maxf(sniff_energy - SNIFF_DRAIN * real, 0.0)
		_scent_t -= real
		if _scent_t <= 0.0:
			_play_scent()
	else:
		sniff_energy = minf(sniff_energy + SNIFF_REGEN * real, 100.0)


## O cheiro mais próximo soa com o seu timbre: mais rápido e agudo quanto mais perto.
func _play_scent() -> void:
	var stage := get_parent()
	var kind := ""
	var nearest := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var d := global_position.distance_to(e.global_position)
		if d < nearest:
			nearest = d
			kind = e.sound_kind
	for secret in stage.fake_walls + stage.chips:
		var d := global_position.distance_to(secret)
		# segredo tem preferência sobre bug à mesma distância
		if d * 0.7 < nearest:
			nearest = d * 0.7
			kind = "secret"
	if kind == "":
		_scent_t = 0.3
		return
	var near := clampf(1.0 - nearest / 280.0, 0.0, 1.0)
	_scent_t = lerpf(0.75, 0.2, near)
	Sound.play("scent_" + kind, lerpf(0.8, 1.4, near))


func heal(amount: int) -> void:
	hp = mini(hp + amount, MAX_HP)


func _laser_in_path() -> bool:
	for l in get_parent().lasers:
		var ahead: float = (l.x - global_position.x) * _dash_dir
		if ahead > -15.0 and ahead < 21.0 and absf(global_position.y + 2.0 - l.y) < 14.0:
			return true
	return false


func _check_contact_damage() -> void:
	if _dash_t <= 0.0 and "lasers" in get_parent():
		for l in get_parent().lasers:
			if absf(global_position.x - l.x) < 14.0 and absf(global_position.y + 2.0 - l.y) < 14.0:
				take_damage(1, l)
	for e in get_tree().get_nodes_in_group("enemy"):
		if global_position.distance_to(e.global_position) < e.contact_radius:
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
	Sound.play("death" if hp <= 0 else "hurt")
	if hp <= 0:
		main.show_banner(Options.t("death_side"), Color("1c2fa8"))
		set_physics_process(false)
		visible = false


func _draw() -> void:
	var hurt := _dash_t <= 0.0 and _iframes > IFRAMES - 0.2
	if not hurt and _iframes > 0.0 and _dash_t <= 0.0 and int(_iframes * 20.0) % 2 == 0:
		return
	var pose := _pose(hurt)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_dash_dir if _dash_t > 0.0 else facing, 1))
	if _dash_t > 0.0:
		for i in [2, 1]:  # rastro do dash
			Art.frame(self, _sheet, pose, Vector2(-12 - i * 8, -8), Vector2(24, 16), Color(1, 1, 1, 0.45 / i))
	Art.frame(self, _sheet, pose, Vector2(-12, -8), Vector2(24, 16))
	draw_set_transform(Vector2.ZERO)


## Quadro da folha hound.png (a ordem está em tools/make_art.py).
func _pose(hurt: bool) -> int:
	var now := Time.get_ticks_msec()
	if hurt:
		return 13
	if _dash_t > 0.0:
		return 8
	var shooting := _fire_cd > 0.0
	if shooting and Input.is_action_pressed("up"):
		return 12
	if get_parent().sniffing:
		return 9 + now / 110 % 2
	if not is_on_floor():
		return 6 if velocity.y < 0.0 else 7
	if absf(velocity.x) > 30.0:
		return 2 + posmod(int(global_position.x / 7.0) * facing, 4)
	if shooting:
		return 11
	return 1 if now % 2400 < 160 else 0
