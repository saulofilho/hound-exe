extends SceneTree
## Arte: a fonte cobre todo texto do jogo, os textos cabem na tela e as folhas
## têm os quadros que os scripts pedem.
## Rodar: godot --headless --path . -s tests/art.gd

const SHEETS := {
	"hound": [24, 16, 14], "top_hound": [24, 24, 4], "walker": [16, 16, 4], "turret": [16, 16, 2],
	"chaser": [16, 16, 2], "ghost": [32, 36, 5], "items": [16, 16, 11], "spam": [16, 16, 3], "laser": [16, 16, 3],
	"icons": [24, 24, 6], "logo": [12, 10, 1],
}
const SCREEN_W := 384.0
const BUTTON_W := 212.0
const TITLE_COLUMN_W := 51.0

var failures := 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	print("%-44s %-7s %s" % [what, "ok" if ok else "FALHOU", detail])
	if not ok:
		failures += 1


func _width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x


func _run() -> void:
	await process_frame
	var font: Font = ThemeDB.fallback_font
	_check("fonte pixel instalada", font is FontFile and font.resource_path.ends_with("hound_font.fnt"))

	var quoted := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var missing := {}
	var wide := []
	var buttons := []
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		for line in FileAccess.get_file_as_string("res://scripts/" + file).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for m in quoted.search_all(line):
				var text := m.get_string(1).c_unescape()
				for c in text:
					if c.unicode_at(0) >= 32 and not font.has_char(c.unicode_at(0)):
						missing[c] = file
				if file == "rooms.gd":
					continue
				for row in text.split("\n"):
					if _width(font, row) > SCREEN_W - 8.0:
						wide.append(row)
				if file in ["title.gd", "pause_menu.gd"] and text == text.to_upper() and text.length() > 2 and _width(font, text) > BUTTON_W:
					buttons.append(text)
	_check("fonte cobre todo texto do jogo", missing.is_empty(), str(missing))
	_check("nenhum texto passa da tela", wide.is_empty(), str(wide))
	_check("rotulos cabem nos botoes", buttons.is_empty(), str(buttons))
	for label in ["Documentos", "Downloads", "Lixeira"]:
		_check("icone do titulo cabe: " + label, _width(font, label) <= TITLE_COLUMN_W, str(_width(font, label)))
	for c in "ÀÁÂÃÇÉÊÍÓÔÕÚàáâãçéêíóôõú":
		if not font.has_char(c.unicode_at(0)):
			_check("acento do portugues: " + c, false)

	for sheet in SHEETS:
		var spec: Array = SHEETS[sheet]
		var tex: Texture2D = load("res://art/%s.png" % sheet)
		_check("folha: " + sheet, tex != null and tex.get_width() == spec[0] * spec[2] and tex.get_height() == spec[1])

	print("ART ", "OK" if failures == 0 else "FALHOU (%d)" % failures)
	await root.get_node("Sound").shutdown()
	quit(0 if failures == 0 else 1)
