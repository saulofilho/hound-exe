class_name SpecialBlock
extends StaticBody2D
## Plataforma que vai e volta:
## - oculta (o): só existe por alguns segundos depois de farejada de perto;
## - temporária (T): existe e some num ciclo, piscando antes.

const T := 16
const REVEAL_RANGE := 128.0
const HIDDEN_FOR := 7.0    # segundos de jogo depois de farejada
const TEMP_ON := 2.4
const TEMP_OFF := 1.0
const BLINK := 1.2         # pisca antes de sumir

var width := 1
var secret := false        # true = oculta; false = temporária
var phase := 0.0
var active := false

var _left := 0.0
var _clock := 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	z_index = -4
	collision_mask = 0
	collision_layer = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * T, T)
	_shape.shape = rect
	add_child(_shape)
	_clock = phase
	_update(0.0)


func distance_to_point(at: Vector2) -> float:
	var half := width * T / 2.0
	var near := Vector2(clampf(at.x, global_position.x - half, global_position.x + half), global_position.y)
	return at.distance_to(near)


## Farejada: materializa, ou renova o tempo.
func reveal() -> void:
	if secret:
		if _left <= 0.0:
			Sound.play("materialize")
		_left = HIDDEN_FOR


func _physics_process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	var want: bool
	if secret:
		_left = maxf(_left - delta, 0.0)
		want = _left > 0.0
	else:
		_clock = fmod(_clock + delta, TEMP_ON + TEMP_OFF)
		want = _clock < TEMP_ON
	# nunca aparece por cima do cão: espera ele sair
	if want and not active and is_inside_tree():
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null:
			var d := player.global_position + Vector2(0, 2) - global_position
			if absf(d.x) < width * T / 2.0 + 5.0 and absf(d.y) < T / 2.0 + 5.5:
				want = false
	active = want
	collision_layer = 1 if active else 0
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-width * T / 2.0, -T / 2.0, width * T, T)
	var sniffing: bool = get_parent().sniffing
	if not active:
		# a oculta é invisível; farejando, um pontilhado. A temporária deixa a marca.
		if secret and not sniffing:
			return
		var color := Art.ACCENT if secret else Art.DIM
		for i in range(0, int(r.size.x), 4):
			draw_rect(Rect2(r.position + Vector2(i, 0), Vector2(2, 1)), color)
			draw_rect(Rect2(r.position + Vector2(i, T - 1), Vector2(2, 1)), color)
		return
	var left := _left if secret else TEMP_ON - _clock
	if left < BLINK and int(left * 10.0) % 2 == 0:
		Art.border(self, r, Art.MID)
		return
	draw_rect(r, Art.BLACK)
	Art.border(self, r, Art.ACCENT if secret else Art.WHITE)
	var x := r.position.x + 3
	while x < r.end.x - 3:
		if secret:
			draw_rect(Rect2(x, -2, 2, 2), Art.ACCENT)
		else:
			draw_rect(Rect2(x, r.position.y + 3, 4, 2), Art.WHITE)  # tarja de "temporário"
		x += 7.0
