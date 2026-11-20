class_name Walker
extends Enemy
## Bug que anda: patrulha e vira na parede ou na beira da plataforma.

const SPEED := 38.0
const GRAVITY := 900.0

var dir := -1


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
	var c := body_color()
	var legs := int(Time.get_ticks_msec() / 150) % 2
	draw_rect(Rect2(-6, -3, 12, 8), c)             # carapaça
	draw_rect(Rect2(-4, -6, 8, 3), c)              # cabeça
	draw_rect(Rect2(dir * 2 - 1, -5, 2, 1), Color.BLACK)
	draw_line(Vector2(-6, -1), Vector2(6, 3), Color.BLACK)
	for lx in [-5, 0, 4]:
		draw_rect(Rect2(lx + legs, 5, 1, 3), c)    # patas
