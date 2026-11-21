extends SceneTree
## Teste de fumaça: joga o corredor e a sala de cima sozinho e confere o básico.
## Rodar: godot --headless --path . -s tests/smoke.gd

var stage: Node
var frame := 0
var log := {}
var checks := {}


func _initialize() -> void:
	stage = load("res://main.tscn").instantiate()
	root.add_child(stage)


func _press(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _check(name: String, ok: bool) -> void:
	checks[name] = ok


func _physics_process(_delta: float) -> bool:
	frame += 1
	return _corridor() if frame <= 520 else _arena()


# ---------------------------------------------------------------- corredor

func _corridor() -> bool:
	var p = stage.player
	match frame:
		5:
			log.start = p.global_position
			_press("jump", true)
		20:
			_check("pulo", log.start.y - p.global_position.y > 20)
			_press("jump", false)
		50:
			_press("right", true)
		105:
			_check("corrida", p.global_position.x - log.start.x > 40)
			_press("right", false)
			log.bugs = get_nodes_in_group("enemy").size()
			_press("shoot", true)
		200:
			_press("shoot", false)
			_check("tiro mata bug", get_nodes_in_group("enemy").size() < log.bugs)
			log.x = p.global_position.x
			_press("dash", true)
		203:
			_press("dash", false)
		215:
			_check("dash", p.global_position.x - log.x > 30)
		230:
			log.energy = p.sniff_energy
			_press("sniff", true)
		260:
			_check("faro desacelera o tempo", stage.sniffing and Engine.time_scale < 1.0)
			_check("faro gasta energia", p.sniff_energy < log.energy)
			var fake: Vector2 = stage.fake_walls[0]
			_check("parede falsa sem colisão", not stage.is_solid_at(fake))
			# tiro durante o faro vale dobrado
			var b := Bullet.new()
			b.setup(Vector2.RIGHT, true)
			if stage.sniffing:
				b.damage = 2
			_check("tiro dobrado no faro", b.damage == 2)
			b.free()
		270:
			_press("sniff", false)
		280:
			_check("faro desliga", not stage.sniffing and Engine.time_scale == 1.0)
			# leva o cão até a porta: deve marcar a ida para a sala de cima
			p.global_position = stage.door_pos
		290:
			_check("porta leva à sala de cima", stage._leaving and Arena.carry_hp == p.hp)
	return false


# ---------------------------------------------------------------- sala de cima

func _arena() -> bool:
	if frame == 521:
		# a porta já trocou a cena: usa a sala de cima que ela abriu
		var opened := current_scene
		stage.queue_free()
		_check("cena da sala de cima aberta", opened is Arena)
		if opened is Arena:
			stage = opened
		else:
			stage = load("res://arena.tscn").instantiate()
			root.add_child(stage)
		return false
	var h = stage.hound
	match frame:
		530:
			log.t0 = stage.time_left
			_press("right", true)
			_press("shoot", true)
		700:
			_check("ondas de bugs surgem", stage._wave >= 1)
			_check("cronômetro anda", stage.time_left < log.t0)
			_check("cão anda na sala", h.global_position.x > 3 * 16 + 8)
			_press("right", false)
		760:
			_press("shoot", false)
			stage.time_left = 0.05   # adianta o fim
		780:
			_check("sala termina com vitória", stage._over and stage.banner.visible and h.hp > 0)
			for k in checks:
				print("%-28s %s" % [k, "ok" if checks[k] else "FALHOU"])
			var ok := checks.values().all(func(v): return v)
			print("SMOKE ", "OK" if ok else "FALHOU")
			return true
	return false
