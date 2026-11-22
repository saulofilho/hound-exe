class_name Chaser
extends Enemy
## Bug da sala de cima: corre direto para o cão, em enxame.

var speed := 40.0
var _sheet: Texture2D


func _init() -> void:
	sound_kind = "chaser"


func _ready() -> void:
	super()
	hp = 2
	_sheet = Art.texture("chaser")


func _physics_process(delta: float) -> void:
	tick(delta)
	var target := get_tree().get_first_node_in_group("player") as Node2D
	var to := Vector2.ZERO
	if target != null and target.visible:
		to = (target.global_position - global_position).normalized()
	velocity = to * speed + _knock
	move_and_slide()


func _draw() -> void:
	Art.frame(self, _sheet, Time.get_ticks_msec() / 120 % 2, Vector2(-8, -6), SPRITE, body_tint())
	draw_weak_point(Vector2(0, 2))
