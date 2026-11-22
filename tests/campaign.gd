extends SceneTree
## A campanha inteira, de jogo novo até o fim, só com os controles: sem teleporte,
## sem mexer em vida, habilidade, pista ou porta. Mede quanto dura para quem já
## sabe o caminho. O caminho vem de tests/planner.py (precisa de python3).
##
## Tudo está vivo: bugs soltos, quarentenas, sala de cima e chefe. O bot não caça
## os bugs soltos, passa por eles e apanha. Morrer é permitido e contado.
## `-- N` joga a variação N: outra semente e outra fase de bugs e plataformas.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/campaign.gd

const ACTIONS := ["left", "right", "up", "down", "jump", "dash", "shoot", "sniff", "restart", "aim_left", "aim_right", "aim_up", "aim_down"]
const RING := [Vector2(52, 40), Vector2(332, 40), Vector2(332, 168), Vector2(52, 168)]
const CHARGE := 4
const STUNNED := 5
const T := 16

var G: Node
var O: Node
var failures := 0
var ticks := 0
var deaths := 0
var falls := 0
var fighting := 0


func _initialize() -> void:
	G = root.get_node("Game")
	O = root.get_node("Options")
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	print("%6.1fs  %-40s %-7s %s" % [ticks / 60.0, what, "ok" if ok else "FALHOU", detail])
	if not ok:
		failures += 1


func _tick() -> void:
	await physics_frame
	ticks += 1


func _wait(n: int) -> void:
	for i in n:
		await _tick()


func _release() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _stage() -> Node:
	var s := current_scene
	return s if s != null and s.get("player") != null else null


func _settle() -> void:
	_release()
	for i in 240:
		await _tick()
		var s := _stage()
		if s != null and is_instance_valid(s.player) and (s.player.hp <= 0 or (s.player.is_on_floor() and s.player.velocity.length() < 16.0 and Engine.time_scale > 0.9)):
			return


## O que o faro precisa renovar antes do próximo passo.
func _sniff_if_needed(to: Vector2) -> void:
	var s := _stage()
	var p = s.player
	var need: bool = not s.revealed and not s.fake_walls.is_empty() and p.global_position.distance_to(s.fake_walls[0]) < 90.0
	for b in s.blocks:
		if b.secret and b._left < 3.5 and b.distance_to_point(p.global_position) < 122.0 and b.distance_to_point(to) < 96.0:
			need = true
	if s.clue_pos != Vector2.ZERO and not s._clue_dug() and p.global_position.distance_to(s.clue_pos) < 70.0:
		need = s.quarantine == null or s.quarantine.state == 3
	if not need:
		return
	while p.sniff_energy <= p.SNIFF_MIN + 1.0:
		await _tick()
	Input.action_press("sniff")
	await _wait(4)
	Input.action_release("sniff")
	await _wait(2)


## A temporária está firme daqui a `t` quadros?
func _firm_at(cell: Array, t: int) -> bool:
	var at := Vector2(cell[0] * T + 8, cell[1] * T + 8)
	for b in _stage().blocks:
		if not b.secret and b.distance_to_point(at) < 2.0:
			var clock: float = fmod(b._clock + t / 60.0, 3.4)
			return clock > 0.05 and clock < 2.33
	return true


## Quantos quadros esperar para este passo e os que saem de cima de temporárias
## darem certo em sequência; -1 se não achar.
func _timing(steps: Array, i: int, t: int, depth := 0) -> int:
	var cells: Array = steps[i].temps
	var last: int = steps[i].inputs.size() - 1
	var lands_on_temp := false
	for cell in cells:
		lands_on_temp = lands_on_temp or cell[3] >= last - 1
	var chained: bool = lands_on_temp and i + 1 < steps.size() and depth < 4
	for wait in range(0, 420, 3):
		var ready := true
		for cell in cells:
			if cell[2] <= 1 and not _firm_at(cell, t + wait):
				return -1  # o apoio some antes de dar a hora
			for at in [cell[2], (cell[2] + cell[3]) / 2, cell[3]]:
				if not _firm_at(cell, t + wait + int(at)):
					ready = false
		if ready and (not chained or _timing(steps, i + 1, t + wait + last + 4, depth + 1) >= 0):
			return wait
	return -1


func _plan(job: Dictionary) -> Array:
	var out := []
	var script := ProjectSettings.globalize_path("res://tests/planner.py")
	var python := OS.get_environment("PYTHON")
	if python == "":
		python = "python" if OS.get_name() == "Windows" else "python3"
	if OS.execute(python, [script, Marshalls.utf8_to_base64(JSON.stringify(job))], out, true) != 0:
		print(out[0])
		return []
	var parsed: Variant = JSON.parse_string(out[0])
	return parsed if parsed is Array else []


func _arrived(goal: Dictionary, room: String) -> bool:
	if G.room != room:
		return goal.has("exit") and G.room == goal.exit
	if goal.has("target"):
		var s := _stage()
		if s == null:
			return false
		var at: Vector2 = s.player.global_position
		var close: bool = absf(at.x - goal.target[0]) < 9.0 and absf(at.y - goal.target[1]) < 10.0
		return close and (not goal.get("ground", false) or s.player.is_on_floor())
	return false


func _revive() -> void:
	deaths += 1
	_release()
	await _wait(4)
	Input.action_press("restart")
	await _wait(2)
	Input.action_release("restart")
	await _wait(8)


## Vai até `goal` replanejando sempre que a realidade discorda do plano.
## Devolve "ok", "morreu" ou por que desistiu.
func _go(goal: Dictionary) -> String:
	var room: String = G.room
	for attempt in 14:
		await _settle()
		var s := _stage()
		if s.player.hp <= 0:
			await _revive()
			return "morreu"
		if s.quarantine != null and s.quarantine.locked():
			if not await _fight():
				return "morreu"
			continue
		var pos: Vector2 = s.player.global_position
		if _arrived(goal, room):
			return "ok"
		var job: Dictionary = goal.duplicate()
		job.merge({"room": room, "pos": [pos.x, pos.y], "dash": G.abilities.dash})
		var steps := _plan(job)
		if steps.is_empty():
			if attempt > 5:
				return "sem caminho de %s" % pos.round()
			await _wait(30)
			continue
		for index in steps.size():
			var step: Dictionary = steps[index]
			var end := Vector2(step.end[0], step.end[1])
			await _sniff_if_needed(end)
			if not step.temps.is_empty():
				await _wait(maxi(_timing(steps, index, 0), 0))
			var hp: int = s.player.hp
			var from: Vector2 = s.player.global_position.round()
			for input in step.inputs:
				await _tick()
				if not is_instance_valid(s) or _stage() != s:
					break
				for item in [["left", input[0] < 0], ["right", input[0] > 0], ["jump", input[1] > 0], ["dash", input[2] > 0]]:
					if item[1]:
						Input.action_press(item[0])
					else:
						Input.action_release(item[0])
				if s.quarantine != null and s.quarantine.locked():
					break
			await _tick()
			_release()
			if not is_instance_valid(s) or G.room != room or _stage() != s:
				for i in 30:
					await _tick()
					if _stage() != null and _stage() != s:
						break
				return "ok" if _arrived(goal, room) else "caiu em " + G.room
			if s.player.hp < hp:
				falls += 1
				break
			if _arrived(goal, room):
				return "ok"
			if s.quarantine != null and s.quarantine.locked():
				break
			if s.player.global_position.distance_to(end) > 4.0:
				if "-v" in OS.get_cmdline_user_args():
					print("  desvio em %s: de %s, previsto %s, deu %s, %d quadros %s" % [room, from, end.round(), s.player.global_position.round(), step.inputs.size(), step.temps])
				break
	var last := _stage()
	return "desistiu em %s" % (last.player.global_position.round() if last != null else Vector2.ZERO)


## Um apoio dentro da zona de onde um tiro reto, com ou sem pulo, pega `prey`.
func _perch(prey: Node2D) -> Array:
	var s := _stage()
	var best := []
	var zone: Rect2i = s.quarantine.zone
	var at: Vector2 = prey.global_position
	var space: PhysicsDirectSpaceState2D = s.player.get_world_2d().direct_space_state
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x + 1, zone.end.x - 1):
			if s.is_solid(Vector2i(x, y)) or not s.is_solid(Vector2i(x, y + 1)):
				continue
			var spot := Vector2(x * T + 8, y * T + 8)
			var rise: float = spot.y - at.y
			if rise < -6.0 or rise > 38.0 or absf(spot.x - at.x) < 36.0 or absf(spot.x - at.x) > 150.0:
				continue
			var line := PhysicsRayQueryParameters2D.create(Vector2(spot.x, at.y), at, 1)
			if not space.intersect_ray(line).is_empty():
				continue
			if best.is_empty() or spot.distance_to(at) < Vector2(best[0], best[1]).distance_to(at):
				best = [spot.x, spot.y]
	return best


## Sobe até o apoio sem parar de atirar; qualquer desvio devolve o comando à luta.
func _climb(prey: Node2D) -> void:
	await _settle()
	var s := _stage()
	var p = s.player
	if p.hp <= 0 or not is_instance_valid(prey):
		return
	var spot := _perch(prey)
	if spot.is_empty():
		return
	var steps := _plan({"room": G.room, "pos": [p.global_position.x, p.global_position.y], "dash": G.abilities.dash, "target": spot, "ground": true})
	for step in steps:
		for input in step.inputs:
			await _tick()
			for item in [["left", input[0] < 0], ["right", input[0] > 0], ["jump", input[1] > 0], ["dash", input[2] > 0], ["shoot", true]]:
				if item[1]:
					Input.action_press(item[0])
				else:
					Input.action_release(item[0])
		await _tick()
		_release()
		if p.hp <= 0 or p.global_position.distance_to(Vector2(step.end[0], step.end[1])) > 5.0:
			return


## Quarentena: mira nas oito direções que o tiro tem e foge de quem encosta.
func _fight() -> bool:
	var s := _stage()
	var p = s.player
	var left: float = (s.quarantine.zone.position.x + 1) * T
	var right: float = (s.quarantine.zone.end.x - 1) * T
	var jump := 0
	var dash := 0
	var sweep := "right"
	var stale := 0
	var score := ""
	var began := ticks
	for i in 60 * 40:
		if not s.quarantine.locked():
			break
		if p.hp <= 0:
			await _revive()
			return false
		await _tick()
		_release()
		jump -= 1
		dash -= 1
		var prey: Node2D = null
		for e in get_nodes_in_group("enemy"):
			if prey == null or p.global_position.distance_to(e.global_position) < p.global_position.distance_to(prey.global_position):
				prey = e
		if prey == null:
			continue
		stale += 1
		var health := 0
		for e in get_nodes_in_group("enemy"):
			health += e.hp
		var now := "%d %d" % [s.quarantine.wave, health]
		if now != score:
			score = now
			stale = 0
		elif stale > 200:
			stale = 0  # nada morre daqui: procura um lugar mais alto
			await _climb(prey)
			continue
		var to: Vector2 = prey.global_position + Vector2(0, 2) - p.global_position
		if i % 900 == 899 and "-v" in OS.get_cmdline_user_args():
			print("  luta: onda %d, %s em %s, cao em %s" % [s.quarantine.wave, prey.sound_kind, prey.global_position.round(), p.global_position.round()])
		var away := "left" if to.x > 0.0 else "right"
		var toward := "right" if to.x > 0.0 else "left"
		var flat := absf(to.y)
		var wide := absf(to.x)
		var muzzle: float = absf(to.x - p.facing * 8.0)  # o tiro sai do focinho
		var ray := PhysicsRayQueryParameters2D.create(p.global_position + Vector2(p.facing * 8, 1), prey.global_position + Vector2(0, 2), 1)
		var covered: bool = not p.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
		var move := ""
		var hop := false  # dá para acertar pulando daqui mesmo
		if to.y < -8.0 and flat < 40.0 and wide >= 30.0 and wide < 160.0:
			var level := PhysicsRayQueryParameters2D.create(Vector2(p.global_position.x, prey.global_position.y), prey.global_position, 1)
			hop = p.get_world_2d().direct_space_state.intersect_ray(level).is_empty()
		if hop:
			if p.facing != (1 if to.x > 0.0 else -1):
				move = toward
			if p.is_on_floor() and jump <= 0:
				jump = 20
			Input.action_press("shoot")
		elif covered and to.length() >= 34.0:
			# há uma plataforma no meio: varre a zona até achar linha de tiro
			if p.global_position.x < left + 20.0:
				sweep = "right"
			elif p.global_position.x > right - 20.0:
				sweep = "left"
			move = sweep
			if p.is_on_floor() and p.is_on_wall() and jump <= 0:
				jump = 18
		elif to.length() < 34.0:
			move = away
			if (away == "left" and p.global_position.x < left) or (away == "right" and p.global_position.x > right):
				move = toward
				if p.is_on_floor() and jump <= 0:
					jump = 18
				if G.abilities.dash and dash <= 0:
					dash = 30
		elif to.y < -10.0 and muzzle < 6.0:
			Input.action_press("up")
			Input.action_press("shoot")
		elif to.y < -10.0 and absf(muzzle - flat) < 9.0:
			move = toward
			Input.action_press("up")
			Input.action_press("shoot")
		elif flat < 9.0:
			if wide > 150.0 or p.facing != (1 if to.x > 0.0 else -1):
				move = toward
			Input.action_press("shoot")
		elif to.y < 0.0:
			if flat < 42.0 and wide < 160.0:
				if p.is_on_floor() and jump <= 0:
					jump = 14
				if p.facing != (1 if to.x > 0.0 else -1):
					move = toward
				Input.action_press("shoot")
			else:
				move = toward if wide > 7.0 else ""
		else:
			move = toward
		if move != "":
			Input.action_press(move)
		if jump > 1:
			Input.action_press("jump")
		if dash > 27:
			Input.action_press("dash")
		if p.sniff_energy > 40.0 and i % 120 < 30:
			Input.action_press("sniff")
	_release()
	var won: bool = not s.quarantine.locked()
	if won:
		fighting += ticks - began
		_check("quarentena de %s" % G.room, true, "vida %d, %d s" % [p.hp, (ticks - began) / 60])
	return won


func _enter_folder(to: String) -> String:
	var s := _stage()
	for folder in s.folders:
		if folder.to != to:
			continue
		var got := await _go({"target": [folder.at.x, folder.at.y], "ground": true})
		if got != "ok":
			return got
		await _settle()
		Input.action_press("down")
		await _wait(3)
		Input.action_release("down")
		await _wait(10)
		return "ok" if G.room == to else "a pasta nao abriu"
	return "sem pasta para " + to


func _point(char: String) -> Array:
	var map: Array = _stage().MAP
	for y in map.size():
		var x: int = map[y].find(char)
		if x >= 0:
			return [x * T + 8.0, y * T + 8.0]
	return []


## Uma sala: ponto de restauração, o que pegar nela e a saída (">" sala, "/" pasta).
func _visit(room: String, wants: Array) -> bool:
	for life in 6:
		if G.room != room:
			_check("esta em " + room, false, "esta em " + G.room)
			return false
		var all := true
		for want in wants:
			var kind: String = want
			var got := "ok"
			if kind.begins_with("/"):
				got = await _enter_folder(kind.substr(1))
			elif kind.begins_with(">"):
				got = await _go({"exit": kind.substr(1)})
			elif kind == "R" and G.restore.get("room", "") == room:
				continue
			elif kind == "A" and G.abilities.dash:
				continue
			elif kind == "V" and G.taken.has("clue:" + room):
				continue
			elif kind == "S" and G.taken.has("backup:" + room):
				continue
			else:
				var at := _point(kind)
				got = await _go({"target": at})
				if got == "ok" and kind == "V" and not G.taken.has("clue:" + room):
					await _sniff_if_needed(Vector2(at[0], at[1]))
					await _wait(6)
				await _wait(2)
			if got == "morreu" and G.room == room:
				all = false
				break
			if got != "ok":
				_check("%s: %s" % [room, kind], false, got)
				return false
		if all:
			_check(" ".join([room] + wants), true)
			return true
	_check(room + ": morre sempre", false)
	return false


func _arena() -> bool:
	for i in 120:
		await _tick()
		if current_scene != null and current_scene.name == "Arena":
			break
	if current_scene.name != "Arena":
		return false
	var s = current_scene
	var h = s.hound
	var next := 0
	while not s._over and h.hp > 0:
		var to: Vector2 = RING[next] - h.global_position
		if to.length() < 8.0:
			next = (next + 1) % RING.size()
		var move := to.normalized()
		var aim := move
		var near := INF
		for e in get_nodes_in_group("enemy"):
			if h.global_position.distance_to(e.global_position) < near:
				near = h.global_position.distance_to(e.global_position)
				aim = (e.global_position - h.global_position).normalized()
		_release()
		for axis in [[move.x, "left", "right"], [move.y, "up", "down"], [aim.x, "aim_left", "aim_right"], [aim.y, "aim_up", "aim_down"]]:
			if absf(axis[0]) > 0.01:
				Input.action_press(axis[2] if axis[0] > 0.0 else axis[1], minf(absf(axis[0]), 1.0))
		Input.action_press("shoot")
		await _tick()
	_release()
	if h.hp <= 0:
		await _revive()
		return false
	for i in 300:
		await _tick()
		if _stage() != null:
			break
	return G.taken.has("arena_desktop")


func _boss() -> bool:
	for i in 120:
		await _tick()
		if G.room == "ghost" and _stage() != null:
			break
	await _wait(3)
	var s := _stage()
	if s == null or s.boss == null:
		return false
	var b = s.boss
	var p = s.player
	var dash := 0
	for i in 60 * 120:
		if not is_instance_valid(b) or p.hp <= 0:
			break
		var d: float = b.global_position.x - p.global_position.x
		var toward := "right" if d > 0.0 else "left"
		var dodge: bool = b.state == CHARGE and absf(b.lane - p.global_position.y) < 18.0 and absf(d) < 55.0
		for c in s.get_children():
			if c.get("friendly") == false:
				var v: Vector2 = c.global_position - p.global_position
				if v.length() < 26.0 and v.dot(c.dir) < 0.0:
					dodge = true
		_release()
		if dodge:
			Input.action_press(toward)
		if b.state == STUNNED:
			if absf(d) > 100.0 or p.facing != signi(int(d)):
				Input.action_press(toward)
			Input.action_press("shoot")
			if b.second_phase():
				Input.action_press("sniff")
		dash -= 1
		if dodge and dash <= 0 and p._dash_cd == 0.0:
			dash = 4
		if dash > 1:
			Input.action_press("dash")
		await _tick()
	_release()
	if p.hp <= 0:
		await _revive()
		return false
	return G.taken.has("boss_desktop")


func _to_door(scene: String) -> bool:
	await _go({"target": _point("D")})
	for i in 60:
		await _tick()
		if (scene == "arena" and current_scene != null and current_scene.name == "Arena") or G.room == scene:
			return true
	return false


func _run() -> void:
	await physics_frame
	var args := OS.get_cmdline_user_args()
	var variant := int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 0
	seed(variant + 3)
	G.new_game()
	O.show_ending = true
	change_scene_to_file("res://main.tscn")
	await _wait(6 + variant * 37)  # desloca o relógio de tudo que se mexe
	var route := [
		["c_drive", ["R", "S", ">docs"]],
		["docs", ["S", "/images"]],
		["images", ["R", "S", ">gallery"]],
		["gallery", ["S", "R", "V", "/docs"]],
		["docs", [">downloads"]],
		["downloads", ["S", ">temp"]],
		["temp", ["R", "S", ">installers"]],
		["installers", ["R", "S", "A", "V", "/downloads"]],
		["downloads", [">docs"]],
		["docs", [">trash"]],
		["trash", ["R", "S", "/system32"]],
		["system32", ["R", "S", ">drivers"]],
		["drivers", ["R", "S", "V", "/trash"]],
	]
	var good := true
	for stop in route:
		good = await _visit(stop[0], stop[1])
		if not good:
			break
	if good:
		_check("tres pistas e todos os segredos", G.clue_count() == 3 and G.secret_count() == load("res://scripts/rooms.gd").secret_total(), "%d, %d" % [G.clue_count(), G.secret_count()])
		var won := false
		for i in 5:
			if await _to_door("arena") and await _arena():
				won = true
				break
		_check("sala de cima", won)
		if won:
			won = false
			for i in 8:
				if await _to_door("ghost") and await _boss():
					won = true
					break
			_check("chefe", won)
		if won:
			var s := _stage()
			for i in 600:
				if G.room != "ghost":
					break
				_release()
				Input.action_press("right" if s.exit_pos.x > s.player.global_position.x else "left")
				await _tick()
			_release()
			for i in 20:
				await process_frame
			_check("fim da demo", G.room == "trash" and paused and current_scene.pause_menu.page == 2)
	print("so em quarentenas: %d s" % (fighting / 60))
	print("duracao do bot: %d:%02d  mortes: %d  danos no caminho: %d  salas: %d" % [ticks / 3600, ticks / 60 % 60, deaths, falls, G.visited.size()])
	print("CAMPAIGN ", "OK" if failures == 0 and good else "FALHOU")
	_release()
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 and good else 1)
