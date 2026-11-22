class_name Chaser
extends Enemy
## Bug da sala de cima: corre direto para o cão, em enxame.

var speed := 40.0


func _init() -> void:
	sound_kind = "chaser"


func _ready() -> void:
	super()
	hp = 2


func _physics_process(delta: float) -> void:
	tick(delta)
	var target := get_tree().get_first_node_in_group("player") as Node2D
	var to := Vector2.ZERO
	if target != null and target.visible:
		to = (target.global_position - global_position).normalized()
	velocity = to * speed + _knock
	move_and_slide()


func _draw() -> void:
	var c := body_color()
	var legs := int(Time.get_ticks_msec() / 120) % 2
	draw_rect(Rect2(-5, -3, 10, 10), c)            # corpo visto de cima
	draw_rect(Rect2(-3, -6, 6, 3), c)              # cabeça
	draw_rect(Rect2(-2, -5, 1, 1), Color.BLACK)
	draw_rect(Rect2(1, -5, 1, 1), Color.BLACK)
	for ly in [-1, 2, 5]:
		draw_rect(Rect2(-7 - legs, ly, 2, 1), c)    # patas
		draw_rect(Rect2(5 + legs, ly, 2, 1), c)
	draw_weak_point(Vector2(0, 2))
