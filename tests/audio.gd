extends SceneTree
## Áudio: arquivos, loops, cada evento com o seu som, volumes salvos e a saída
## gravada do mixer (estouro, emenda do loop, abafamento, mudo).
## Precisa de tempo real, então sem --fixed-fps:
##   godot --headless --path . -s tests/audio.gd

const PATH := "user://test_audio.json"
const SETTINGS := "user://test_audio.settings.json"

var G: Node
var S: Node
var rec: AudioEffectRecord
var failures := 0


func _initialize() -> void:
	G = root.get_node("Game")
	S = root.get_node("Sound")
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	print("%-48s %-7s %s" % [what, "ok" if ok else "FALHOU", detail])
	if not ok:
		failures += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _hold(action: String, n: int) -> void:
	Input.action_press(action)
	await _frames(n)
	Input.action_release(action)
	await _frames(2)


func _key(key: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.physical_keycode = key
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await _frames(3)


func _heard(effect: String) -> void:
	_check("evento toca: " + effect, S.played.get(effect, 0) > 0)


func _clean() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp", SETTINGS, "user://test_audio.options.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _run() -> void:
	await physics_frame
	_clean()
	_files()
	G.save_path = PATH
	await _events()
	await _volumes()
	await _mixer()
	_clean()
	print("AUDIO ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await S.shutdown()
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- arquivos

func _files() -> void:
	var used := {}
	var quoted := RegEx.create_from_string('"([a-z_]+)"')
	var call := RegEx.create_from_string("Sound\\.play(?:\\.bind)?\\((.*)")
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			for m in call.search_all(FileAccess.get_file_as_string("res://scripts/" + file)):
				for q in quoted.search_all(m.get_string(1).get_slice("\n", 0)):
					used[q.get_string(1)] = true
	used.erase("scent_")
	used.erase("_die")
	used.erase("_hit")
	for kind in ["walker", "turret", "chaser"]:
		used[kind + "_hit"] = true
		used[kind + "_die"] = true
	for kind in ["walker", "turret", "ghost", "secret"]:
		used["scent_" + kind] = true
	for track in S.TRACKS.values():
		for layer in track.base + ([track.extra] if track.extra != "" else []):
			used[layer] = true
	var missing := used.keys().filter(func(n): return load("res://audio/%s.wav" % n) == null if ResourceLoader.exists("res://audio/%s.wav" % n) else true)
	_check("todo som usado existe", missing.is_empty(), str(missing))
	var orphans := []
	for file in DirAccess.get_files_at("res://audio"):
		if file.ends_with(".wav") and not used.has(file.get_basename()):
			orphans.append(file)
	_check("nenhum arquivo sem uso", orphans.is_empty(), str(orphans))

	var bad := []
	for name in used:
		if name.begins_with("music_"):
			var w: AudioStreamWAV = load("res://audio/%s.wav" % name)
			if w.loop_mode != AudioStreamWAV.LOOP_FORWARD or w.loop_end != roundi(w.get_length() * w.mix_rate) - 1:
				bad.append(name)
	_check("trilhas em loop ate a ultima amostra", bad.is_empty(), str(bad))
	for pair in [["music_desktop", "music_desktop_tension"], ["music_boss", "music_boss_copies"]]:
		var a: AudioStreamWAV = load("res://audio/%s.wav" % pair[0])
		var b: AudioStreamWAV = load("res://audio/%s.wav" % pair[1])
		_check("camadas do mesmo tamanho: " + pair[0], a.loop_end == b.loop_end)


# ---------------------------------------------------------------- eventos

func _events() -> void:
	change_scene_to_file("res://title.tscn")
	await _frames(6)
	_check("titulo: musica", S.current == "title")
	_check("foco inicial nao faz barulho", not S.played.has("ui_move"))
	await _key(KEY_DOWN)
	_heard("ui_move")
	await _key(KEY_UP)
	await _key(KEY_ENTER)
	await _frames(8)
	_heard("ui_ok")
	_check("regiao: musica", S.current == "desktop")

	await _hold("jump", 20)
	await _frames(30)
	_heard("jump")
	_heard("land")
	await _hold("right", 25)
	_heard("restore")
	await _hold("shoot", 10)
	_heard("shoot")

	G.enter("downloads", Vector2(18 * 16 + 8, 168))
	await _frames(8)
	var music_player = S._music
	await _hold("right", 40)
	_heard("chip")
	_check("trocar de sala nao reinicia a musica", S._music == music_player and S.current == "desktop")
	await _frames(40)
	await _hold("dash", 3)
	_heard("dash")
	var s = current_scene
	s.player.hp = 3
	s.player.global_position = s.patches[0]
	await _frames(4)
	_heard("pickup")

	G.enter("docs", Vector2(12 * 16 + 8, 168))
	await _frames(8)
	s = current_scene
	var walker = null
	var turret = null
	for e in get_nodes_in_group("enemy"):
		if e.sound_kind == "walker":
			walker = e
		else:
			turret = e
	s.player.global_position = walker.global_position - Vector2(70, 0)
	await _frames(50)
	_check("bug perto: tensao sobe", S.tension > 0.5, str(S.tension))
	await _hold("sniff", 40)
	_heard("sniff")
	_check("faro toca o cheiro", S.played.keys().any(func(k): return k.begins_with("scent_")))
	Input.action_press("sniff")
	await _frames(6)
	_check("faro abafa a musica", S.muffled)
	Input.action_release("sniff")
	await _frames(6)
	_check("sem faro, desabafa", not S.muffled)
	for e in [[walker, "walker"], [turret, "turret"]]:
		if is_instance_valid(e[0]):
			e[0].hit(1, Vector2.RIGHT)
			e[0].hit(9, Vector2.RIGHT)
			_heard(e[1] + "_hit")
			_heard(e[1] + "_die")
	await _frames(10)
	s.player.global_position = Vector2(700, 56)
	s.player.facing = 1
	await _frames(4)
	G.enter("c_drive", Vector2(340, 80))
	await _frames(8)
	current_scene.player.facing = 1
	await _hold("shoot", 12)
	await _frames(20)
	_heard("spark")
	_check("sem bug: tensao cai", S.tension == 0.0)

	G.enter("trash", Vector2(680, 168))  # colado na parede falsa
	await _frames(8)
	s = current_scene
	await _hold("sniff", 30)
	_heard("scent_secret")
	s.player._iframes = 0.0
	s.player.hp = 3
	s.player.take_damage(1, s.player.global_position + Vector2(8, 0))
	_heard("hurt")
	s.player._iframes = 0.0
	s.player.hp = 1
	s.player.take_damage(1, s.player.global_position + Vector2(8, 0))
	await _frames(8)
	_heard("death")
	_check("tela azul abafa a musica", S.muffled)
	G.respawn()
	await _frames(8)
	s = current_scene
	_check("renascer desabafa", not S.muffled)
	G.enter("trash", Vector2(680, 168))
	await _frames(8)
	s = current_scene
	s.player.global_position = s.door_pos
	await _frames(8)
	_heard("door")
	_check("sala de cima: musica", S.current == "arena")

	s = current_scene
	s._wave_t = 0.0
	await _frames(4)
	_heard("wave")
	var bug = get_first_node_in_group("enemy")
	bug.hit(1, Vector2.RIGHT)
	bug.hit(1, Vector2.RIGHT)
	_heard("chaser_hit")
	_heard("chaser_die")
	s.time_left = 0.02
	await _frames(5)
	_heard("victory")
	_check("vitoria: musica para", S.current == "")

	G.enter("ghost")
	await _frames(8)
	_check("chefe: musica", S.current == "boss")
	var b = current_scene.boss
	current_scene.player._iframes = 99.0
	b._drift()
	b._shot_t = 0.0
	await _frames(3)
	_heard("ghost_fire")
	b._left = 0.0
	await _frames(4)
	b.position = Vector2(b._edge(b.side), b.lane)
	await _frames(3)
	_heard("ghost_warn")
	b._left = 0.0
	await _frames(3)
	_heard("ghost_charge")
	b.position.x = b._edge(-b.side)
	await _frames(3)
	_heard("ghost_stun")
	b.hit(33, Vector2.RIGHT)
	await _frames(4)
	_heard("ghost_hit")
	_heard("ghost_phase")
	_check("segunda fase: camada das copias", S.tension == 1.0)
	b.hit(99, Vector2.RIGHT)
	await _frames(4)
	_heard("ghost_die")
	_check("chefe cai: musica para", S.current == "")


# ---------------------------------------------------------------- volumes

func _volumes() -> void:
	G.enter("c_drive")
	await _frames(8)
	await _key(KEY_ESCAPE)
	_heard("pause")
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	var row: Button = root.gui_get_focus_owner()
	_check("pausa > SOM abre nos volumes", "MÚSICA 75%" in row.text, row.text)
	await _key(KEY_LEFT)
	_check("esquerda abaixa", S.volumes.Music == 50 and "50%" in row.text)
	await _key(KEY_D)
	_check("D aumenta", S.volumes.Music == 75)
	await _key(KEY_A)
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_B
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(3)
	_check("B volta um nivel, ainda pausado", paused and root.gui_get_focus_owner().text == "CONTINUAR")
	await _key(KEY_ESCAPE)
	await _frames(3)
	S.volumes = S.DEFAULTS.duplicate()
	S.load_settings()
	_check("volume sobrevive a reabrir", S.volumes.Music == 50)
	for bad in ["{{", "[]", '{"Music":"alto","Effects":33}', '{"Music":999}']:
		var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		S.load_settings()
		_check("config ruim usa o padrao: " + bad, S.volumes == S.DEFAULTS)


# ---------------------------------------------------------------- mixer

func _record(seconds: float) -> PackedFloat32Array:
	rec.set_recording_active(true)
	await _wait(seconds)
	rec.set_recording_active(false)
	var out := PackedFloat32Array()
	var wav := rec.get_recording()
	if wav != null:
		for i in range(0, wav.data.size() - 3, 4):  # canal esquerdo
			out.append(wav.data.decode_s16(i) / 32768.0)
	return out


func _rms(a: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in a:
		sum += v * v
	return sqrt(sum / maxi(a.size(), 1))


func _peak(a: PackedFloat32Array) -> float:
	var top := 0.0
	for v in a:
		top = maxf(top, absf(v))
	return top


## Energia nos agudos: RMS da diferença entre amostras vizinhas.
func _bright(a: PackedFloat32Array) -> float:
	var sum := 0.0
	for i in range(1, a.size()):
		sum += (a[i] - a[i - 1]) ** 2
	return sqrt(sum / maxi(a.size(), 1))


func _db(v: float) -> String:
	return "%.1f dB" % linear_to_db(maxf(v, 0.00001))


func _mixer() -> void:
	# cena vazia: nada do jogo mexe na música durante a medição
	var blank := Node.new()
	current_scene.queue_free()
	root.add_child(blank)
	current_scene = blank
	await _frames(3)
	paused = false
	S.muffled = false
	S.volumes = S.DEFAULTS.duplicate()
	S._apply_volumes()
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)  # depois do limitador

	for track in ["title", "desktop", "arena", "boss"]:
		S.music(track)
		await _wait(0.8)
		var a: PackedFloat32Array = await _record(5.0)
		var level := linear_to_db(maxf(_rms(a), 0.00001))
		_check("nivel da musica: " + track, level > -36.0 and level < -12.0 and _peak(a) < 0.9, "RMS %.1f dB, pico %s" % [level, _db(_peak(a))])

	S.music("desktop")
	await _wait(0.8)
	var calm: PackedFloat32Array = await _record(4.3)
	S.tension = 1.0
	await _wait(1.0)
	var tense: PackedFloat32Array = await _record(4.3)
	_check("tensao muda a saida", _bright(tense) > _bright(calm) * 1.05, "%s -> %s" % [_db(_bright(calm)), _db(_bright(tense))])
	S.muffled = true
	await _wait(0.4)
	var muffled: PackedFloat32Array = await _record(4.3)
	_check("abafado corta os agudos", _bright(muffled) < _bright(tense) * 0.5, "%s -> %s" % [_db(_bright(tense)), _db(_bright(muffled))])
	S.muffled = false
	paused = true
	await _wait(0.5)
	var ducked: PackedFloat32Array = await _record(4.3)
	paused = false
	_check("pausa abaixa a musica", _rms(ducked) < _rms(tense) * 0.6, "%s -> %s" % [_db(_rms(tense)), _db(_rms(ducked))])
	S.music("")
	await _wait(1.0)

	# emenda: toca os últimos instantes e atravessa o loop
	for name in ["music_title", "music_desktop", "music_desktop_tension", "music_arena", "music_boss", "music_boss_copies", "music_ambience"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://audio/%s.wav" % name)
		root.add_child(p)
		p.play(p.stream.get_length() - 0.35)
		await _wait(0.08)
		var seam: PackedFloat32Array = await _record(0.6)
		var after := seam.slice(int(seam.size() * 0.6))
		_check("loop continua: " + name, p.playing and _rms(after) > 0.0005, _db(_rms(after)))
		p.stop()
		p.stream = null
		p.queue_free()
		await _wait(0.1)

	S.music("boss")
	S.tension = 1.0
	S.volumes = {"Music": 100, "Effects": 100}
	S._apply_volumes()
	await _wait(1.2)
	rec.set_recording_active(true)
	for i in 8:
		for e in ["shoot", "ghost_die", "ghost_stun", "death", "victory", "turret_die", "chip", "hurt", "dash", "walker_die"]:
			S.play(e)
		await _wait(0.09)
	await _wait(0.4)
	rec.set_recording_active(false)
	var wav := rec.get_recording()
	var top := 0
	for i in wav.data.size() / 2:
		top = maxi(top, absi(wav.data.decode_s16(i * 2)))
	_check("tudo junto no maximo nao estoura", top < 30100, _db(top / 32768.0))

	await _wait(1.5)
	S.volumes = {"Music": 0, "Effects": 0}
	S._apply_volumes()
	await _wait(0.4)
	S.play("ghost_die")
	var mute: PackedFloat32Array = await _record(0.6)
	_check("0% e mudo de verdade", _peak(mute) < 0.0001)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	rec = null
