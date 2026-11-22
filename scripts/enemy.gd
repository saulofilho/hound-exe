class_name Enemy
extends CharacterBody2D
## Base dos bugs: vida, piscar ao ser atingido, knockback e morte com estilhaços.

const BUG_COLOR := Art.ACCENT  # olhos, tiros e avisos: a cor da região
const SPRITE := Vector2(16, 16)

var hp := 3
var contact_radius := 13.0    # 0 = não machuca ao encostar
var sound_kind := ""          # prefixo dos sons deste bug
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
	main.add_shake(3.0 if amount > 1 else 2.0)
	Sound.play(sound_kind + ("_die" if hp <= 0 else "_hit"), 1.0, 0.08)
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
	p.color = Art.WHITE
	p.global_position = global_position
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)


func tick(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_knock = _knock.move_toward(Vector2.ZERO, delta * 400.0)
	queue_redraw()


## Durante o faro, o ponto fraco pisca em branco (o tiro ali vale dobrado).
func draw_weak_point(at: Vector2) -> void:
	if get_parent().sniffing and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Art.BLACK)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Art.ACCENT)
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), Art.WHITE)


func body_tint() -> Color:
	return Art.ACCENT if _flash > 0.0 else Color.WHITE
