class_name Turret
extends Enemy
## Bug que atira: fica parado e dispara devagar quando o cão chega perto.

const RANGE := 170.0
const FIRE_EVERY := 1.6

var _cooldown := 1.0


func _init() -> void:
	sound_kind = "turret"


func _ready() -> void:
	super()
	hp = 4


func _physics_process(delta: float) -> void:
	tick(delta)
	position += _knock * delta * 0.2
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.visible:
		return
	_cooldown -= delta
	var to := player.global_position - global_position
	if _cooldown <= 0.0 and to.length() < RANGE:
		_cooldown = FIRE_EVERY
		var b := Bullet.new()
		b.setup(to.normalized(), false)
		Sound.play("turret_fire", 1.0, 0.05)
		b.global_position = global_position + to.normalized() * 8.0
		get_parent().add_child(b)


func _draw() -> void:
	var c := body_color()
	var warn := _cooldown < 0.35 and int(Time.get_ticks_msec() / 60) % 2 == 0
	draw_rect(Rect2(-7, -2, 14, 10), c)            # base
	draw_rect(Rect2(-4, -7, 8, 5), c)              # cúpula
	draw_rect(Rect2(-2, -5, 4, 2), Color.WHITE if warn else Color.BLACK)  # olho avisa o tiro
	draw_weak_point(Vector2(0, 4))
