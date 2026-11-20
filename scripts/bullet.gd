class_name Bullet
extends Area2D
## Tiro do cão (rápido, curto) ou do inimigo (lento, maior).

var dir := Vector2.RIGHT
var speed := 360.0
var friendly := true
var _life := 0.6


func setup(direction: Vector2, from_player: bool) -> void:
	dir = direction
	friendly = from_player
	if not friendly:
		speed = 95.0
		_life = 4.0


func _ready() -> void:
	collision_layer = 0
	# amigo: atinge paredes (1) e inimigos (4) · inimigo: paredes (1) e o cão (2)
	collision_mask = 1 | 4 if friendly else 1 | 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2.0 if friendly else 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += dir * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if friendly and body.is_in_group("enemy"):
		body.hit(1, dir)
	elif not friendly and body.is_in_group("player"):
		body.take_damage(1, global_position)
	_spark()
	queue_free()


func _spark() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.2
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2.ZERO
	p.global_position = global_position
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)


func _draw() -> void:
	if friendly:
		draw_rect(Rect2(-3, -1, 6, 2) if dir.y == 0.0 else Rect2(-1, -3, 2, 6), Color.WHITE)
	else:
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.42, 0.24))
		draw_circle(Vector2.ZERO, 1.0, Color.BLACK)
