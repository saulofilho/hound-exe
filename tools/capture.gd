extends SceneTree
## Joga o protótipo sozinho e salva quadros 3× (pixel nítido) em docs/img/.
## Rodar (precisa de janela): godot --path . -s tools/capture.gd

const SHOTS := {
	150: "gameplay-shoot.png",
	330: "gameplay-jump.png",
	420: "gameplay-sniff.png",
	760: "gameplay-arena.png",
}

var stage: Node
var frame := 0


func _initialize() -> void:
	stage = load("res://main.tscn").instantiate()
	root.add_child(stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 380:
		# corredor: anda atirando e pula de tempos em tempos
		if frame == 20:
			Input.action_press("right")
			Input.action_press("shoot")
		if frame % 70 == 0:
			Input.action_press("jump")
		if frame % 70 == 18:
			Input.action_release("jump")
		if frame == 300:
			Input.action_press("up")
		if frame == 340:
			Input.action_release("up")
	elif frame == 380:
		# perto da parede falsa, para mostrar o faro
		Input.action_release("right")
		Input.action_release("shoot")
		stage.player.global_position = Vector2(61 * 16 + 8, 168)
		Input.action_press("sniff")
	elif frame == 430:
		Input.action_release("sniff")
		stage.player.global_position = stage.door_pos  # a porta abre a sala de cima
	elif frame == 440:
		var opened := current_scene
		stage.queue_free()
		stage = opened
		Input.action_press("shoot")
		Input.action_press("right")
	elif frame > 440:
		# sala de cima: anda em círculos atirando
		var phase := int((frame - 440) / 45) % 4
		for a in ["right", "down", "left", "up"]:
			Input.action_release(a)
		Input.action_press(["right", "down", "left", "up"][phase])

	if SHOTS.has(frame):
		var img := root.get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("res://docs/img/" + SHOTS[frame])
	return frame > 760
