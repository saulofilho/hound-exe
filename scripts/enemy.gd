class_name Enemy
extends CharacterBody2D
## Base dos bugs: vida, piscar ao ser atingido, knockback e morte com estilhaços.

const HIT_COLOR := Color.WHITE
const BUG_COLOR := Color(1.0, 0.42, 0.24)  # cor de destaque provisória

var hp := 3
var _flash := 0.0
var _knock := Vector2.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)
	add_to_group("enemy")


func hit(amount: int, dir: Vector2) -> void:
	hp -= amount
	_flash = 0.08
	_knock = dir * 60.0
	var main := get_parent()
	main.add_shake(2.0)
	if hp <= 0:
		main.add_shake(5.0)
		main.hitstop(0.05)
		_burst()
		queue_free()


func _burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color = BUG_COLOR
	p.global_position = global_position
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)


func tick(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_knock = _knock.move_toward(Vector2.ZERO, delta * 400.0)
	queue_redraw()


func body_color() -> Color:
	return HIT_COLOR if _flash > 0.0 else BUG_COLOR
