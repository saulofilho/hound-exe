extends SceneTree
## Teste de fumaça: joga o corredor sozinho e confere o básico.
## Rodar: godot --headless --path . -s tests/smoke.gd

var main: Node
var frame := 0
var log := {}


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _press(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _physics_process(_delta: float) -> bool:
	frame += 1
	var p = main.player
	if frame > 110 and frame < 200:
		var n := 0
		for c in main.get_children():
			if c is Bullet:
				n += 1
		log.max_bullets = maxi(log.get("max_bullets", 0), n)
		var hps := []
		for e in get_nodes_in_group("enemy"):
			hps.append(e.hp)
		log.enemy_hp = hps
	match frame:
		5:
			log.start = p.global_position
			log.bugs_start = get_nodes_in_group("enemy").size()
			_press("jump", true)
		20:
			log.jump_peak = log.start.y - p.global_position.y
			_press("jump", false)
		50:
			_press("right", true)
		105:
			log.walked = p.global_position.x - log.start.x
		110:
			_press("right", false)
			_press("shoot", true)
		200:
			_press("shoot", false)
			log.bugs_after_shooting = get_nodes_in_group("enemy").size()
			log.x_before_dash = p.global_position.x
			_press("dash", true)
		203:
			_press("dash", false)
		215:
			log.dash_distance = p.global_position.x - log.x_before_dash
		400:
			log.hp = p.hp
			for k in log:
				print("%s = %s" % [k, log[k]])
			var ok: bool = log.walked > 40 and log.jump_peak > 20 and log.dash_distance > 30
			print("SMOKE ", "OK" if ok else "FALHOU")
			return true
	return false
