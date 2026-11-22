class_name Hud
extends Control
## HUD de sistema operacional: a barra de tarefas embaixo, que cobre só o chão,
## e a janelinha de vida do chefe em cima.

var hp := 5
var max_hp := 5
var energy := -1.0        # faro, 0 a 100; < 0 esconde
var sniffing := false
var seconds_left := -1    # cronômetro da sala de cima
var bugs := 0
var place := ""           # nome da sala, no canto do relógio
var boss_life := -1.0     # 0 a 1; < 0 esconde
var hint := ""            # controles, só onde ensinar faz falta


func _ready() -> void:
	size = Art.SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var top := Art.SCREEN.y - Art.BAR_H
	if hint != "":
		draw_rect(Rect2(0, top - 12, Art.SCREEN.x, 12), Art.BLACK)
		Art.text_centered(self, Art.SCREEN.x / 2.0, top - 12, hint, Art.MID)

	var x := Art.taskbar(self)
	var y := top + 3
	Art.text(self, Vector2(x, y), "VIDA")
	x += Art.text_width("VIDA") + 3
	var critical := hp == 1 and Time.get_ticks_msec() / 200 % 2 == 0
	for i in max_hp:
		var cell := Rect2(x + i * 9, y + 2, 7, 8)
		if i < hp:
			draw_rect(cell, Art.ACCENT if critical else Art.WHITE)
		else:
			Art.border(self, cell, Art.MID)
	x += max_hp * 9 + 8

	if energy >= 0.0:
		Art.text(self, Vector2(x, y), "FARO")
		x += Art.text_width("FARO") + 3
		var blocks := ceili(energy / 10.0)
		Art.border(self, Rect2(x, y + 1, 53, 10))
		for i in blocks:
			# abaixo do mínimo para começar a farejar, fica apagado
			var usable := sniffing or energy > Player.SNIFF_MIN
			draw_rect(Rect2(x + 2 + i * 5, y + 3, 4, 6), Art.ACCENT if usable else Art.MID)
		x += 60
	if seconds_left >= 0:
		Art.text(self, Vector2(x, y), "TEMPO %02d" % seconds_left, Art.ACCENT if seconds_left <= 10 else Art.WHITE)
		x += 52
		Art.text(self, Vector2(x, y), "BUGS %d" % bugs)

	if place != "":
		var width := Art.text_width(place) + 8
		Art.border(self, Rect2(Art.SCREEN.x - width - 2, top + 3, width, 13), Art.MID)
		Art.text(self, Vector2(Art.SCREEN.x - width + 2, y), place)

	if boss_life >= 0.0:
		var box := Rect2(92, 4, 200, 15)
		draw_rect(box, Art.BLACK)
		Art.border(self, box)
		Art.text(self, box.position + Vector2(4, 1), "~fantasma.tmp")
		var bar := Rect2(box.position + Vector2(80, 3), Vector2(116, 9))
		Art.border(self, bar)
		for i in ceili(boss_life * 28.0):
			draw_rect(Rect2(bar.position + Vector2(2 + i * 4, 2), Vector2(3, 5)), Art.ACCENT)
