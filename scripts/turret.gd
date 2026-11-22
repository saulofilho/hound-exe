class_name Turret
extends Enemy
## Bug que atira: fica parado e dispara devagar quando o cão chega perto.

const RANGE := 170.0
const FIRE_EVERY := 1.6

var reach := RANGE            # a da sala de cima alcança a sala toda
var _cooldown := 1.0
var _sheet: Texture2D


func _init() -> void:
	sound_kind = "turret"


func _ready() -> void:
	super()
	hp = 4
	_sheet = Art.texture("turret")


func _physics_process(delta: float) -> void:
	tick(delta)
	position += _knock * delta * 0.2
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or not player.visible:
		return
	_cooldown -= delta
	var to := player.global_position - global_position
	if _cooldown <= 0.0 and to.length() < reach:
		_cooldown = FIRE_EVERY
		var b := Bullet.new()
		b.setup(to.normalized(), false)
		Sound.play("turret_fire", 1.0, 0.05)
		b.global_position = global_position + to.normalized() * 8.0
		get_parent().add_child(b)


func _draw() -> void:
	var warn := _cooldown < 0.35 and int(Time.get_ticks_msec() / 60) % 2 == 0
	Art.frame(self, _sheet, 1 if warn else 0, Vector2(-8, -8), SPRITE, body_tint())  # o olho avisa o tiro
	draw_weak_point(Vector2(0, 0))
