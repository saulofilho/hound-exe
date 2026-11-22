class_name Hud
extends Control
## HUD de sistema operacional: a barra de tarefas embaixo, que cobre só o chão,
## e a janelinha de vida do chefe em cima.

var hp := 5
var max_hp := 5
var energy := -1.0        # faro; < 0 esconde
var max_energy := 100.0
var clues := -1           # pistas achadas; < 0 esconde
var sniffing := false
var seconds_left := -1    # cronômetro da sala de cima
var bugs := 0
var place := ""           # nome da sala, no canto do relógio
var boss_life := -1.0     # 0 a 1; < 0 esconde
var restart_hold := 0.0   # 0 a 1 enquanto segura R
var hint := ""            # controles, só onde ensinar faz falta


func _ready() -> void:
	size = Art.SCREEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Depois de remapear os nomes crescem: quebra entre itens em vez de cortar.
static func hint_lines(text: String) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for part in text.split(" · "):
		var longer := part if line == "" else line + " · " + part
		if line != "" and Art.text_width(longer) > Art.SCREEN.x - 8.0:
			lines.append(line)
			line = part
		else:
			line = longer
	if line != "":
		lines.append(line)
	return lines


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var top := Art.SCREEN.y - Art.BAR_H
	if hint != "":
		var lines := hint_lines(hint)
		var band := lines.size() * 12.0
		draw_rect(Rect2(0, top - band, Art.SCREEN.x, band), Art.BLACK)
		for i in lines.size():
			Art.text_centered(self, Art.SCREEN.x / 2.0, top - band + i * 12.0, lines[i], Art.MID)

	var x := Art.taskbar(self)
	var y := top + 3
	var life := Options.t("hud_life")
	Art.text(self, Vector2(x, y), life)
	x += Art.text_width(life) + 3
	var critical := hp == 1 and Time.get_ticks_msec() / 200 % 2 == 0
	for i in max_hp:
		var cell := Rect2(x + i * 9, y + 2, 7, 8)
		if i < hp:
			draw_rect(cell, Art.ACCENT if critical else Art.WHITE)
		else:
			Art.border(self, cell, Art.MID)
	x += max_hp * 9 + 8

	if energy >= 0.0:
		var sniff := Options.t("hud_sniff")
		Art.text(self, Vector2(x, y), sniff)
		x += Art.text_width(sniff) + 3
		var blocks := clampi(ceili(energy / max_energy * 10.0), 0, 10)
		Art.border(self, Rect2(x, y + 1, 53, 10))
		for i in blocks:
			# abaixo do mínimo para começar a farejar, fica apagado
			var usable := sniffing or energy > Player.SNIFF_MIN
			draw_rect(Rect2(x + 2 + i * 5, y + 3, 4, 6), Art.ACCENT if usable else Art.MID)
		x += 58
		if clues >= 0:
			for i in Rooms.CLUES:
				# uma lupa por pista
				var at := Vector2(x + i * 11, y + 2)
				var ink := Art.ACCENT if i < clues else Art.MID
				Art.border(self, Rect2(at, Vector2(6, 6)), ink)
				draw_rect(Rect2(at + Vector2(6, 6), Vector2(2, 2)), ink)
				if i < clues:
					draw_rect(Rect2(at + Vector2(2, 2), Vector2(2, 2)), ink)
	if seconds_left >= 0:
		Art.text(self, Vector2(x, y), Options.t("hud_time") % seconds_left, Art.ACCENT if seconds_left <= 10 else Art.WHITE)
		x += 52
		Art.text(self, Vector2(x, y), Options.t("hud_bugs") % bugs)

	if place != "":
		var width := Art.text_width(place) + 8
		Art.border(self, Rect2(Art.SCREEN.x - width - 2, top + 3, width, 13), Art.MID)
		Art.text(self, Vector2(Art.SCREEN.x - width + 2, y), place)

	if restart_hold > 0.0:
		var track := Rect2(132, top - 9, 120, 7)
		draw_rect(track, Art.BLACK)
		Art.border(self, track)
		draw_rect(Rect2(track.position + Vector2(2, 2), Vector2(116.0 * minf(restart_hold, 1.0), 3)), Art.ACCENT)

	if boss_life >= 0.0:
		var box := Rect2(92, 4, 200, 15)
		draw_rect(box, Art.BLACK)
		Art.border(self, box)
		Art.text(self, box.position + Vector2(4, 1), Options.t("boss_file"))
		var bar := Rect2(box.position + Vector2(80, 3), Vector2(116, 9))
		Art.border(self, bar)
		for i in ceili(boss_life * 28.0):
			draw_rect(Rect2(bar.position + Vector2(2 + i * 4, 2), Vector2(3, 5)), Art.ACCENT)
