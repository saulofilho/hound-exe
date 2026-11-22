extends SceneTree
## Joga a região sozinho e salva quadros 3× (pixel nítido) em docs/img/.
## Rodar (precisa de janela): godot --path . -s tools/capture.gd

const T := 16
# `-- store`: só estas, em inglês, 1920x1080, em steam/screenshots/
const STORE := [
	"gameplay-shoot.png", "boss-copies.png", "gameplay-arena.png", "gameplay-sniff.png",
	"gameplay-laser.png", "boss-stunned.png", "gameplay-chip.png", "boss-intro.png",
]
var G: Node  # autoload Game
var store := false


func _initialize() -> void:
	G = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))
	store = "store" in OS.get_cmdline_user_args()
	if store:
		root.get_node("Options").language = "en"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://steam/screenshots"))
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(file: String) -> void:
	await process_frame
	RenderingServer.force_draw()  # desenha mesmo com a janela coberta
	var img := root.get_texture().get_image()
	var times := 5 if store else 3  # 5x = 1920x1080 exatos
	img.resize(img.get_width() * times, img.get_height() * times, Image.INTERPOLATE_NEAREST)
	if not store:
		img.save_png("res://docs/img/" + file)
	elif file in STORE:
		img.convert(Image.FORMAT_RGB8)
		img.save_png("res://steam/screenshots/%02d-%s" % [STORE.find(file) + 1, file])


func _go(room: String, pos: Vector2) -> void:
	G.enter(room, pos)
	await _frames(6)


func _run() -> void:
	await physics_frame
	if not store:
		await _menus()
	G.new_game()
	for r in ["c_drive", "docs", "downloads", "trash"]:
		G.visited[r] = true

	# Documentos: atirando nos bugs
	await _go("docs", Vector2(12 * T + 8, 168))
	Input.action_press("shoot")
	await _frames(70)
	await _shot("gameplay-shoot.png")
	Input.action_release("shoot")

	# Documentos: a subida e o laser que só o dash atravessa
	await _go("docs", Vector2(39 * T + 8, 168))
	await _frames(40)
	await _shot("gameplay-laser.png")

	# Downloads: o chip de dash
	await _go("downloads", Vector2(15 * T + 8, 168))
	await _frames(20)
	await _shot("gameplay-chip.png")

	# Lixeira: farejando a parede falsa
	G.abilities.dash = true
	await _go("trash", Vector2(36 * T + 8, 168))  # fora do alcance que abre a parede: o rastro aparece
	Input.action_press("sniff")
	await _frames(25)
	await _shot("gameplay-sniff.png")
	Input.action_release("sniff")

	# Explorer
	G.restore = {"room": "trash", "pos": Vector2(3 * T + 8, 168)}
	await _frames(10)
	current_scene._map_view.open()
	await _frames(10)
	await _shot("gameplay-explorer.png")
	current_scene._map_view.close()
	await _frames(4)

	# sala de cima
	G.enter_arena("trash", Vector2(44 * T, 168))
	await _frames(6)
	Input.action_press("shoot")
	for i in 330:
		var dir: String = ["right", "down", "left", "up"][int(i / 45) % 4]
		for a in ["right", "down", "left", "up"]:
			Input.action_release(a)
		Input.action_press(dir)
		await physics_frame
	await _shot("gameplay-arena.png")
	for action in ["shoot", "right", "down", "left", "up"]:
		Input.action_release(action)
	await _boss()
	await root.get_node("Sound").shutdown()
	quit()


func _boss() -> void:
	G.hp = G.MAX_HP
	G.visited["ghost"] = true
	G.enter("ghost")
	await _frames(40)
	await _shot("boss-intro.png")

	var s = current_scene
	var b = s.boss
	b.set_physics_process(false)
	s.toast.text = ""
	s.player.global_position = Vector2(120, 168)
	s.player.facing = 1
	b.hp = 22
	b.state = 3  # AVISA
	b.side = 1
	b.lane = 168.0
	b.position = Vector2(348, 168)
	b._left = 0.5
	b.queue_redraw()
	await _frames(3)
	await _shot("boss-copies.png")

	Input.action_press("sniff")
	await _frames(3)
	b.queue_redraw()
	await _frames(2)
	await _shot("boss-sniff.png")
	Input.action_release("sniff")
	await _frames(4)

	b.hp = 50  # primeira fase: atordoado, leva tiro sem faro
	b.state = 5  # ATORDOADO
	b._left = 2.0
	b.position = Vector2(220, 162)
	b.collision_layer = 4
	b.queue_redraw()
	Input.action_press("shoot")
	await _frames(12)
	b.queue_redraw()
	await _shot("boss-stunned.png")
	Input.action_release("shoot")

	current_scene._map_view.open()
	await _frames(5)
	await _shot("gameplay-explorer.png")


## Título, pausa, primeira sala e tela azul. O disco fica desligado ao jogar.
func _menus() -> void:
	G.save_path = "user://capture_unused.json"  # o título só lê; nada é gravado
	change_scene_to_file("res://title.tscn")
	await _frames(10)
	await _shot("title.png")

	G.save_path = ""
	G.new_game()
	G.enter("c_drive")
	await _frames(150)
	await _shot("gameplay-start.png")
	var s = current_scene
	G.save_path = "user://capture_unused.json"  # só para o texto da pausa
	s.pause_menu.open()
	await _frames(4)
	await _shot("pause.png")
	s.pause_menu.close()
	await _frames(6)
	G.save_path = ""
	s.player.hp = 1
	s.player.take_damage(1, s.player.global_position + Vector2(10, 0))
	await _frames(20)
	await _shot("blue-screen.png")
