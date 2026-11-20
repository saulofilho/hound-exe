extends SceneTree
## Joga o corredor sozinho e salva quadros 3× (pixel nítido) em docs/img/.
## Rodar (precisa de janela): godot --path . -s tools/capture.gd

const SHOTS := {150: "gameplay-shoot.png", 330: "gameplay-jump.png", 520: "gameplay-turret.png"}

var main: Node
var frame := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/img"))


func _physics_process(_delta: float) -> bool:
	frame += 1
	# roteiro: anda atirando, pula de tempos em tempos
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
	if SHOTS.has(frame):
		var img := root.get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("res://docs/img/" + SHOTS[frame])
	if frame > 520:
		return true
	return false
