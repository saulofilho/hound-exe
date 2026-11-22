extends Node
## Áudio do jogo (autoload "Sound"): efeitos, música em camadas e volumes.
##
## Os arquivos vêm de tools/make_audio.py. A música tem uma camada extra que
## sobe com `tension` (bug por perto; segunda fase do chefe) e fica abafada
## durante o faro, a pausa e a tela azul.

const TRACKS := {
	"title": {"base": ["music_title"], "extra": ""},
	"desktop": {"base": ["music_desktop", "music_ambience"], "extra": "music_desktop_tension"},
	"arena": {"base": ["music_arena"], "extra": ""},
	"boss": {"base": ["music_boss"], "extra": "music_boss_copies"},
}
const VOICES := 20
const REPEAT_GAP_MS := 35      # o mesmo efeito não empilha no mesmo instante
const STEPS := [0, 25, 50, 75, 100]
const DEFAULTS := {"Music": 75, "Effects": 100}
const SILENT_DB := -60.0
const PAUSE_DUCK_DB := -8.0
const FADE_PER_SECOND := 120.0 # dB por segundo

var current := ""              # música tocando
var tension := 0.0             # 0 a 1, quem decide é a tela
var muffled := false
var volumes := DEFAULTS.duplicate()
var played := {}               # quantas vezes cada efeito tocou (para os testes)

var _effects := {}
var _last_played := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _outgoing: AudioStreamPlayer
var _layers: AudioStreamSynchronized
var _extra_index := -1
var _extra_level := 0.0
var _lowpass: AudioEffectLowPassFilter
var _last_tick := 0
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in VOICES:
		_voices.append(_player("Effects"))
	_music = _player("Music")
	_outgoing = _player("Music")
	_apply_volumes()
	_last_tick = Time.get_ticks_msec()


func _setup_buses() -> void:
	for bus in ["Music", "Effects"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 700.0
	var music_bus := AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(music_bus, _lowpass, 0)
	AudioServer.set_bus_effect_enabled(music_bus, 0, false)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _exit_tree() -> void:
	_release()


func _release() -> void:
	_closed = true
	for p in _voices + [_music, _outgoing]:
		p.stop()
		p.stream = null
	_effects.clear()
	_layers = null


## Chamar com await antes de fechar: o mixer roda em outra thread e precisa de
## uns instantes para soltar o que tocava (senão o Godot acusa vazamento).
func shutdown() -> void:
	_release()
	var until := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		OS.delay_msec(5)


# ---- efeitos

## `pitch` muda a altura; `vary` sorteia uma variação pequena em volta dela.
func play(effect: String, pitch := 1.0, vary := 0.0) -> void:
	if _closed:
		return
	var now := Time.get_ticks_msec()
	played[effect] = played.get(effect, 0) + 1
	if now - _last_played.get(effect, -1000) < REPEAT_GAP_MS:
		return
	_last_played[effect] = now
	if not _effects.has(effect):
		_effects[effect] = load("res://audio/%s.wav" % effect)
	var stream: AudioStream = _effects[effect]
	if stream == null:
		return
	var voice := _free_voice()
	voice.stream = stream
	# randf() global é da jogabilidade: o som usa o relógio para não mexer nele
	var wobble := (float(hash(now + played[effect]) % 1000) / 500.0 - 1.0) * vary
	voice.pitch_scale = maxf(pitch + wobble, 0.1)
	voice.play()


func _free_voice() -> AudioStreamPlayer:
	for i in VOICES:
		var voice := _voices[(_next_voice + i) % VOICES]
		if not voice.playing:
			_next_voice = (_next_voice + i + 1) % VOICES
			return voice
	_next_voice = (_next_voice + 1) % VOICES
	return _voices[_next_voice]


# ---- música

## Troca de música com fade. Pedir a que já toca não recomeça; "" = silêncio.
func music(track: String) -> void:
	if _closed or track == current:
		return
	current = track
	tension = 0.0
	_extra_level = 0.0
	_extra_index = -1

	var old := _music
	_music = _outgoing
	_outgoing = old
	_music.stop()
	_music.stream = null
	_layers = null
	if track == "":
		return

	var files: Array = TRACKS[track].base.duplicate()
	if TRACKS[track].extra != "":
		_extra_index = files.size()
		files.append(TRACKS[track].extra)
	_layers = AudioStreamSynchronized.new()
	_layers.stream_count = files.size()
	for i in files.size():
		_layers.set_sync_stream(i, load("res://audio/%s.wav" % files[i]))
		_layers.set_sync_stream_volume(i, SILENT_DB if i == _extra_index else 0.0)
	_music.stream = _layers
	_music.volume_db = -18.0
	_music.play()


func _process(_delta: float) -> void:
	# tempo real: o faro e o hitstop mexem em Engine.time_scale
	var now := Time.get_ticks_msec()
	var real := minf((now - _last_tick) / 1000.0, 0.25)
	_last_tick = now

	if _outgoing.playing:
		_outgoing.volume_db -= FADE_PER_SECOND * real
		if _outgoing.volume_db <= SILENT_DB:
			_outgoing.stop()
			_outgoing.stream = null

	var paused := get_tree().paused
	var target := PAUSE_DUCK_DB if paused else 0.0
	_music.volume_db = move_toward(_music.volume_db, target, FADE_PER_SECOND * 0.5 * real)
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index("Music"), 0, muffled or paused)

	if _layers != null and _extra_index >= 0:
		_extra_level = move_toward(_extra_level, clampf(tension, 0.0, 1.0), real * 1.5)
		_layers.set_sync_stream_volume(_extra_index, maxf(linear_to_db(_extra_level), SILENT_DB))


# ---- volumes (ficam num arquivo ao lado do save)

## `step` = -1 ou 1; 0 dá a volta (para clique e botão A).
func change_volume(bus: String, step: int) -> void:
	var i := STEPS.find(volumes[bus])
	i = posmod(i - 1, STEPS.size()) if step == 0 else clampi(i + step, 0, STEPS.size() - 1)
	volumes[bus] = STEPS[i]
	_apply_volumes()
	_write_settings()


func _apply_volumes() -> void:
	for bus in volumes:
		var i := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(i, volumes[bus] == 0)
		# curva ao quadrado: 50% soa como metade
		var level: float = volumes[bus] / 100.0
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(level * level, 0.001)))


func settings_path() -> String:
	return "" if Game.save_path == "" else Game.save_path.get_basename() + ".settings.json"


func load_settings() -> void:
	volumes = DEFAULTS.duplicate()
	var path := settings_path()
	if path != "" and FileAccess.file_exists(path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			for bus in DEFAULTS:
				var value: Variant = json.data.get(bus)
				if (value is float or value is int) and int(value) in STEPS:
					volumes[bus] = int(value)
	_apply_volumes()


func _write_settings() -> void:
	var path := settings_path()
	if path == "":
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(volumes))
		file.close()
