class_name Walker
extends Enemy
## Bug que anda: patrulha e vira na parede ou na beira da plataforma.

const SPEED := 38.0
const GRAVITY := 900.0

var dir := -1
var _sheet: Texture2D


func _init() -> void:
	sound_kind = "walker"


func _ready() -> void:
	super()
	_sheet = Art.texture("walker")


func _physics_process(delta: float) -> void:
	tick(delta)
	var main := get_parent()
	var ahead := global_position + Vector2(dir * 9, 2)
	var below := global_position + Vector2(dir * 9, 12)
	if is_on_floor() and (main.is_solid_at(ahead) or not main.is_solid_at(below)):
		dir = -dir
	velocity.x = dir * SPEED + _knock.x
	velocity.y = minf(velocity.y + GRAVITY * delta, 280.0)
	move_and_slide()


func _draw() -> void:
	var step := posmod(int(global_position.x / 4.0), 4)
	Art.frame(self, _sheet, step, Vector2(-8, -8), SPRITE, body_tint())
	draw_weak_point(Vector2(-dir * 3, 1))
