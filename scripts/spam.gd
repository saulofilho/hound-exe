class_name Spam
extends Enemy
## Spam: um envelope com asas. Paira, treme para avisar e mergulha reto onde o
## cão estava. Desviar é sair da linha; depois ele sobe devagar.

enum State { HOVER, WARN, DIVE, RETURN }

const SIGHT := 130.0
const WARN_TIME := 0.55
const DIVE_TIME := 0.7
const DIVE_SPEED := 180.0
const RETURN_SPEED := 55.0
const REST := 1.1          # tempo mínimo pairando entre mergulhos

var state: State = State.HOVER
var _home := Vector2.ZERO
var _left := REST
var _aim := Vector2.DOWN
var _age := 0.0
var _sheet: Texture2D


func _init() -> void:
	sound_kind = "spam"


func _ready() -> void:
	super()
	hp = 2
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sheet = Art.texture("spam")
	_home = position


func _physics_process(delta: float) -> void:
	tick(delta)
	_age += delta
	_left -= delta
	var target := get_tree().get_first_node_in_group("player") as Node2D
	var goal := Vector2.ZERO
	match state:
		State.HOVER:
			goal = (_home + Vector2(sin(_age * 1.3) * 18.0, sin(_age * 3.1) * 5.0) - position) * 4.0
			if _left <= 0.0 and target != null and target.visible and _sees(target.global_position):
				state = State.WARN
				_left = WARN_TIME
				_aim = (target.global_position - global_position).normalized()
				Sound.play("spam_dive")
		State.WARN:
			if _left <= 0.0:
				state = State.DIVE
				_left = DIVE_TIME
		State.DIVE:
			goal = _aim * DIVE_SPEED
			if _left <= 0.0 or get_slide_collision_count() > 0:
				state = State.RETURN
				_left = 3.0
		State.RETURN:
			goal = (_home - position).limit_length(RETURN_SPEED)
			if position.distance_to(_home) < 6.0 or _left <= 0.0:
				if _left <= 0.0:
					_home = position  # algo no caminho: mora aqui agora
				state = State.HOVER
				_left = REST
	velocity = goal + _knock
	move_and_slide()


func _sees(at: Vector2) -> bool:
	if global_position.distance_to(at) > SIGHT:
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, at, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _draw() -> void:
	var frame := Time.get_ticks_msec() / 110 % 2
	var off := Vector2.ZERO
	if state == State.WARN:
		frame = 2
		off.x = 1 if int(_left * 20.0) % 2 == 0 else -1
		for i in range(1, 8):  # a linha do mergulho
			draw_rect(Rect2(_aim * i * 14.0, Vector2(2, 2)), Art.ACCENT)
	elif state == State.DIVE:
		frame = 2
	Art.frame(self, _sheet, frame, Vector2(-8, -7) + off, SPRITE, body_tint())
	draw_weak_point(Vector2(0, 1))
