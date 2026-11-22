class_name Art
## Paleta e peças de desenho comuns. As imagens vêm de tools/make_art.py.

const WHITE := Color("f3f3ee")
const BLACK := Color(0, 0, 0)
const ACCENT := Color("2fb5a8")      # a cor da Área de trabalho: só no que é jogável
const DIM := Color("2c2c2e")         # papel de parede: nunca disputa com o jogo
const SHADE := Color("19191b")       # miolo das paredes
const MID := Color("7c7c78")         # textos secundários

const SCREEN := Vector2(384, 216)
const BAR_H := 17.0                  # barra de tarefas
const FONT_SIZE := 11                # a fonte é bitmap: só este tamanho ou múltiplos
const BASELINE := 10.0               # do topo da linha até a base da letra
const LINE_H := 12.0


static var _loaded := {}


## Guarda a referência: o desenho só leva o RID, e a textura solta some da tela.
static func texture(file: String) -> Texture2D:
	if not _loaded.has(file):
		_loaded[file] = load("res://art/%s.png" % file)
	return _loaded[file]


static func release() -> void:
	_loaded.clear()


## Um quadro de uma folha horizontal, com o canto superior esquerdo em `at`.
static func frame(on: CanvasItem, sheet: Texture2D, index: int, at: Vector2, size: Vector2, tint := Color.WHITE) -> void:
	on.draw_texture_rect_region(sheet, Rect2(at, size), Rect2(Vector2(index * size.x, 0), size), tint)


## Texto com o topo da linha em `at`.
static func text(on: CanvasItem, at: Vector2, content: String, color := WHITE, times := 1) -> void:
	on.draw_string(ThemeDB.fallback_font, (at + Vector2(0, BASELINE * times)).floor(), content,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE * times, color)


static func text_width(content: String, times := 1) -> float:
	return ThemeDB.fallback_font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE * times).x


static func text_centered(on: CanvasItem, center: float, top: float, content: String, color := WHITE, times := 1) -> void:
	text(on, Vector2(center - text_width(content, times) / 2.0, top), content, color, times)


static func border(on: CanvasItem, r: Rect2, color := WHITE) -> void:
	on.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), color)
	on.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), color)
	on.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), color)
	on.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), color)


## Janela do Windows 95 em 1-bit: borda, barra de título e sombra dura.
static func window(on: CanvasItem, r: Rect2, title: String, fill := BLACK) -> void:
	on.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), DIM)
	on.draw_rect(r, fill)
	border(on, r)
	on.draw_rect(Rect2(r.position, Vector2(r.size.x, 14)), WHITE)
	text(on, r.position + Vector2(5, 1), title, BLACK)
	var close := Rect2(r.position + Vector2(r.size.x - 13, 2), Vector2(10, 10))
	border(on, close, BLACK)
	for i in 6:
		on.draw_rect(Rect2(close.position + Vector2(2 + i, 2 + i), Vector2(1, 1)), BLACK)
		on.draw_rect(Rect2(close.position + Vector2(7 - i, 2 + i), Vector2(1, 1)), BLACK)


## A barra de tarefas com o botão do cão. Devolve o x livre depois do botão.
static func taskbar(on: CanvasItem) -> float:
	var top := SCREEN.y - BAR_H
	on.draw_rect(Rect2(0, top, SCREEN.x, BAR_H), BLACK)
	on.draw_rect(Rect2(0, top, SCREEN.x, 1), WHITE)
	border(on, Rect2(2, top + 3, 52, 13))
	on.draw_texture(texture("logo"), Vector2(5, top + 4))
	text(on, Vector2(19, top + 3), "HOUND")
	return 60.0
