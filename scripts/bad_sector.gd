class_name BadSector
extends Node2D
## Setor corrompido da sala de cima: marca o chão, avisa e corrompe.
## Não dá para atirar nele. A única resposta é sair de cima.

const RADIUS := 22.0
const WARN := 1.0          # tempo para sair
const LINGER := 1.6        # corrompido, ainda machuca

var hound: TopHound
var _age := 0.0
var _burst := false


func _ready() -> void:
	z_index = -5  # no chão, embaixo de todo mundo
	Sound.play("zone_warn")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= WARN + LINGER:
		queue_free()
		return
	if _age >= WARN:
		if not _burst:
			_burst = true
			Sound.play("zone_burst")
			get_parent().add_shake(2.0)
		if is_instance_valid(hound) and hound.hp > 0 and hound.global_position.distance_to(global_position) < RADIUS:
			hound.take_damage(1, global_position)
	queue_redraw()


func _draw() -> void:
	var cell := 4
	var reach := int(RADIUS / cell) + 1
	var filling := minf(_age / WARN, 1.0) * RADIUS
	var noise := int(_age * 14.0)
	for j in range(-reach, reach + 1):
		for i in range(-reach, reach + 1):
			var at := Vector2(i, j) * cell
			var d := at.length()
			if d > RADIUS:
				continue
			if _age < WARN:
				# o miolo cresce até a borda: dá para ver quando vai estourar
				if d > RADIUS - cell:
					if int(_age * 10.0) % 2 == 0:
						draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), Art.ACCENT)
				elif d < filling and (i + j) % 2 == 0:
					draw_rect(Rect2(at, Vector2(2, 2)), Art.ACCENT)
			elif posmod(i * 7 + j * 13 + noise, 5) < 3:
				draw_rect(Rect2(at - Vector2(2, 2), Vector2(3, 3)), Art.ACCENT if posmod(i + j + noise, 4) > 0 else Art.WHITE)
