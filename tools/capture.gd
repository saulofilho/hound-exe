extends SceneTree
## Joga a região sozinho e salva quadros 3× (pixel nítido) em docs/img/.
## Rodar (precisa de janela): godot --path . -s tools/capture.gd

const T := 16
var G: Node  # autoload Game


func _initialize() -> void:
	G = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))
	_run()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(file: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png("res://docs/img/" + file)


func _go(room: String, pos: Vector2) -> void:
	G.enter(room, pos)
	await _frames(6)


func _run() -> void:
	await physics_frame
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
	await _go("trash", Vector2(40 * T + 8, 168))
	Input.action_press("sniff")
	await _frames(25)
	await _shot("gameplay-sniff.png")
	Input.action_release("sniff")

	# Explorer
	G.restore = {"room": "trash", "pos": Vector2(3 * T + 8, 168)}
	await _frames(10)
	Input.action_press("map")
	await _frames(2)
	Input.action_release("map")
	await _frames(10)
	await _shot("gameplay-explorer.png")
	Input.action_press("map")
	await _frames(2)
	Input.action_release("map")

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
	quit()
