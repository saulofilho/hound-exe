extends SceneTree
## Luta com o Arquivo Fantasma só com os controles, sem mexer na vida de ninguém.
## Rodar: godot --headless --fixed-fps 60 --path . -s tests/boss.gd
##
## Estratégias: parado e atirar sem desviar (têm que perder); desviar no dash,
## pular e farejar mais (têm que vencer). Na segunda fase todos farejam.

const DRIFT := 1
const CHARGE := 4
const STUNNED := 5
const ACTIONS := ["left", "right", "up", "jump", "dash", "shoot", "sniff"]
const LIMIT := 60 * 150

var G: Node
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _release() -> void:
	for a in ACTIONS:
		Input.action_release(a)


func _set_held(action: String, on: bool) -> void:
	if on == Input.is_action_pressed(action):
		return
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _fight(style: String, delay: int) -> Dictionary:
	_release()
	G.new_game()
	G.abilities.dash = true
	G.enter("ghost")
	await _frames(5 + delay)
	var s = current_scene
	var p = s.player
	var b = s.boss
	var tick := 0
	var dash_hold := 0
	var hurt := 0
	var last_hp: int = p.hp
	while tick < LIMIT and p.hp > 0 and is_instance_valid(b):
		tick += 1
		if style != "parado":
			var want := {}
			var d: float = b.global_position.x - p.global_position.x
			var toward := "right" if d > 0 else "left"
			var dodge := false
			if style != "so_atira":
				if b.state == CHARGE and absf(b.lane - p.global_position.y) < 18.0:
					dodge = absf(d) < 55.0
					if dodge:
						want[toward] = true
				for c in s.get_children():
					if c.get("friendly") == false:
						var v: Vector2 = c.global_position - p.global_position
						if v.length() < 26.0 and v.dot(c.dir) < 0.0:
							dodge = true
			if b.state == STUNNED:
				if b.second_phase():
					want["sniff"] = true
				if absf(d) > 100.0 or p.facing != signi(int(d)):
					want[toward] = true
				want["shoot"] = absf(d) < 220.0
			elif style == "faro" and b.state == DRIFT and (s.sniffing or p.sniff_energy > 70.0):
				want["sniff"] = true
				want["shoot"] = true
				want["up"] = true
				if absf(d) > 12.0:
					want[toward] = true
			if style == "pula":
				# sem dash: sai de baixo das plataformas e pula a investida
				dodge = false
				want.erase("dash")
				var reach := 78.0 if b.second_phase() else 66.0
				var rising: bool = p.velocity.y < 0.0
				if b.state == CHARGE:
					want.erase(toward)
					want["jump"] = absf(d) < reach or rising
				elif b.state != STUNNED:
					want.erase(toward)
					var home := 124.0 if p.global_position.x < 192.0 else 260.0
					if absf(home - p.global_position.x) > 5.0:
						want["right" if home > p.global_position.x else "left"] = true
			dash_hold -= 1
			if dodge and dash_hold <= 0 and p._dash_cd == 0.0:
				dash_hold = 4
			want["dash"] = dash_hold > 1
			for a in ACTIONS:
				_set_held(a, want.get(a, false))
		await physics_frame
		hurt += maxi(last_hp - p.hp, 0)
		last_hp = p.hp
	_release()
	await _frames(20)
	var won: bool = G.taken.has("boss_desktop")
	var result := {"won": won, "seconds": tick / 60.0, "hurt": hurt, "boss": b.hp if is_instance_valid(b) else 0}
	if won and style == "desvia" and delay == 0:
		_expect("vitoria enche a vida", p.hp == p.MAX_HP)
		_expect("vitoria limpa os tiros inimigos", s.get_children().all(func(c): return c.get("friendly") != false))
	return result


func _expect(what: String, ok: bool) -> void:
	print("%-40s %s" % [what, "ok" if ok else "FALHOU"])
	if not ok:
		failures += 1


func _run() -> void:
	await physics_frame
	change_scene_to_file("res://main.tscn")
	await _frames(3)
	for style in ["parado", "so_atira", "desvia", "pula", "faro"]:
		for delay in [0, 7, 19, 31, 47, 73]:
			var r: Dictionary = await _fight(style, delay)
			print("%-9s inicio+%-3d %s em %5.1fs  dano=%d chefe=%d" % [style, delay, "VENCEU" if r.won else "perdeu", r.seconds, r.hurt, r.boss])
			if style in ["parado", "so_atira"]:
				_expect("  sem desviar nao vence", not r.won)
			elif style in ["desvia", "pula", "faro"]:
				_expect("  luta vencivel", r.won)
	print("BOSS ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)
