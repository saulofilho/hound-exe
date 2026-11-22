class_name DialogBox
extends Control
## Caixa de diálogo que se ajusta ao texto. A primeira linha pode ser o título.

var text := "":
	set(value):
		text = value
		queue_redraw()
var fill := Art.BLACK:
	set(value):
		fill = value
		queue_redraw()
var titled := false        # true: janela com a primeira linha na barra
var top := -1.0            # < 0 centraliza na tela


func _ready() -> void:
	size = Art.SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if text == "":
		return
	var lines := Array(text.split("\n"))
	var title := ""
	if titled:
		title = lines.pop_front()
		while not lines.is_empty() and lines[0] == "":
			lines.pop_front()
	var width := maxf(Art.text_width(title) + 26.0, 120.0)
	for line in lines:
		width = maxf(width, Art.text_width(line) + 20.0)
	width = ceilf(width)
	var head := 14.0 if titled else 0.0
	var height := head + lines.size() * Art.LINE_H + (12.0 if titled else 6.0)
	var y := top if top >= 0.0 else floorf((Art.SCREEN.y - Art.BAR_H - height) / 2.0)
	var box := Rect2(floorf((Art.SCREEN.x - width) / 2.0), y, width, height)
	var ink := Art.BLACK if fill == Art.ACCENT else Art.WHITE
	if titled:
		Art.window(self, box, title, fill)
	else:
		draw_rect(box, fill)
		Art.border(self, box)
	for i in lines.size():
		Art.text_centered(self, box.get_center().x, box.position.y + head + (6.0 if titled else 3.0) + i * Art.LINE_H, lines[i], ink)
