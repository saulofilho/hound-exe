class_name Quarantine
extends Node2D
## Quarentena: quem entra na zona fica trancado até limpar as ondas.

signal cleared

enum State { IDLE, WARNING, FIGHTING, DONE }

const T := 16
const MARK_TIME := 0.9     # o aviso antes de cada bug nascer
const INSET := 12.0        # só tranca com o cão inteiro do lado de dentro

var zone: Rect2i           # em células, com as duas pontas
var waves: Array = []
var gates: Array[Vector2] = []
var state: State = State.IDLE
var wave := 0

var _left := 0.0
var _bodies: Array[StaticBody2D] = []
var _alive: Array[Node] = []


func setup(spec: Dictionary, gate_cells: Array[Vector2], done: bool) -> void:
	var z: Array = spec.zone
	zone = Rect2i(z[0], z[1], z[2] - z[0] + 1, z[3] - z[1] + 1)
	waves = spec.waves
	gates = gate_cells
	if done:
		state = State.DONE


func locked() -> bool:
	return state == State.WARNING or state == State.FIGHTING


func watch(at: Vector2) -> void:
	if state != State.IDLE:
		return
	var box := Rect2(Vector2(zone.position) * T, Vector2(zone.size) * T)
	if box.grow_individual(-INSET, 0, -INSET, 0).has_point(at):
		_lock()


func _lock() -> void:
	for at in gates:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(T, T)
		shape.shape = rect
		body.position = at
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)
	Sound.play("gate")
	get_parent().show_toast(Options.t("quarantine"), 2.5)
	_warn()


func _warn() -> void:
	state = State.WARNING
	_left = MARK_TIME


func _physics_process(delta: float) -> void:
	match state:
		State.WARNING:
			_left -= delta
			if _left <= 0.0:
				_spawn()
		State.FIGHTING:
			_alive = _alive.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
			if _alive.is_empty():
				wave += 1
				if wave < waves.size():
					_warn()
				else:
					_open()
	queue_redraw()


func _spawn() -> void:
	state = State.FIGHTING
	Sound.play("wave")
	_alive.clear()
	for item in waves[wave]:
		var bug: Enemy
		match item[0]:
			"w": bug = Walker.new()
			"t": bug = Turret.new()
			_: bug = Spam.new()
		bug.position = Vector2(item[1] * T + T / 2.0, item[2] * T + T / 2.0)
		get_parent().add_child(bug)
		_alive.append(bug)


func _open() -> void:
	state = State.DONE
	for body in _bodies:
		body.queue_free()
	_bodies.clear()
	Sound.play("victory")
	cleared.emit()


func _draw() -> void:
	if not locked():
		return
	var scroll := Time.get_ticks_msec() / 80 % 8
	for at in gates:
		var r := Rect2(at - Vector2(T, T) / 2.0, Vector2(T, T))
		draw_rect(Rect2(r.position + Vector2(5, 0), Vector2(6, T)), Art.BLACK)
		draw_rect(Rect2(r.position + Vector2(4, 0), Vector2(1, T)), Art.WHITE)
		draw_rect(Rect2(r.position + Vector2(11, 0), Vector2(1, T)), Art.WHITE)
		for y in range(scroll, T, 8):
			draw_rect(Rect2(r.position + Vector2(6, y), Vector2(4, 2)), Art.ACCENT)
	if state == State.WARNING and int(_left * 10.0) % 2 == 0:
		for item in waves[wave]:
			Art.border(self, Rect2(item[1] * T + 2, item[2] * T + 2, 12, 12), Art.ACCENT)
