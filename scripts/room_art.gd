class_name RoomArt
extends Node2D
## Cenário parado de uma sala: papel de parede, paredes e plataformas-janela.
## Sai do mesmo mapa ASCII das colisões, então não tem como divergir delas.

const T := 16
const WINDOW_MAX := 8          # uma fileira solta até este tamanho vira janela
const ICONS := ["folder", "page", "drive", "download", "bin", "computer"]
const THEMES := {
	"c_drive": ["computer", "drive", "folder"],
	"docs": ["folder", "page", "page"],
	"downloads": ["download", "page", "download"],
	"trash": ["bin", "page", "folder"],
	"ghost": ["page"],
	"arena": [],
}

var map: Array = []
var theme := ""
var exits: Array = []
var reveal := false:           # no faro a parede falsa some do cenário
	set(value):
		if value != reveal:
			reveal = value
			queue_redraw()

var _icons: Texture2D


func _ready() -> void:
	z_index = -10
	_icons = Art.texture("icons")


func _char(x: int, y: int) -> String:
	if y < 0 or y >= map.size() or x < 0 or x >= map[0].length():
		return ""
	return map[y][x]


func _solid(x: int, y: int) -> bool:
	var c := _char(x, y)
	# fora do mapa conta como parede, para a borda só ter traço do lado de dentro
	return c == "" or c == "#" or (c == "F" and not reveal)


func _draw() -> void:
	if theme == "arena":
		_grid()
	else:
		_wallpaper()
	for y in map.size():
		var x := 0
		while x < map[0].length():
			if not _solid(x, y):
				x += 1
				continue
			var start := x
			while x < map[0].length() and _solid(x, y):
				x += 1
			if _is_window(start, x, y):
				_window(start, x, y)
			else:
				for cell in range(start, x):
					_wall(cell, y)
	_exit_arrows()


func _is_window(from: int, to: int, y: int) -> bool:
	if y <= 0 or y >= map.size() - 1 or from <= 0 or to >= map[0].length() or to - from > WINDOW_MAX or to - from < 2:
		return false
	for x in range(from, to):
		if _solid(x, y - 1) or _solid(x, y + 1):
			return false
	return true


func _window(from: int, to: int, y: int) -> void:
	var r := Rect2(from * T, y * T, (to - from) * T, T)
	draw_rect(r, Art.BLACK)
	Art.border(self, r)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), Art.WHITE)
	for i in 2:
		draw_rect(Rect2(r.position + Vector2(3, 2 + i * 2), Vector2(r.size.x - 14, 1)), Art.BLACK)
	draw_rect(Rect2(r.position + Vector2(r.size.x - 7, 1), Vector2(4, 4)), Art.BLACK)
	var x := 4.0
	while x < r.size.x - 6:
		draw_rect(Rect2(r.position + Vector2(x, 10), Vector2(5, 1)), Art.MID)
		x += 8.0


func _wall(x: int, y: int) -> void:
	var p := Vector2(x * T, y * T)
	draw_rect(Rect2(p, Vector2(T, T)), Art.SHADE)
	for j in range(1, T, 4):
		for i in range(1, T, 4):
			var shift := 2 if j % 8 == 1 else 0
			draw_rect(Rect2(p + Vector2(i + shift, j), Vector2(1, 1)), Art.DIM)
	if not _solid(x, y - 1):
		draw_rect(Rect2(p, Vector2(T, 2)), Art.WHITE)
	if not _solid(x, y + 1):
		draw_rect(Rect2(p + Vector2(0, T - 1), Vector2(T, 1)), Art.WHITE)
	if not _solid(x - 1, y):
		draw_rect(Rect2(p, Vector2(1, T)), Art.WHITE)
	if not _solid(x + 1, y):
		draw_rect(Rect2(p + Vector2(T - 1, 0), Vector2(1, T)), Art.WHITE)


func _wallpaper() -> void:
	var kinds: Array = THEMES.get(theme, [])
	if kinds.is_empty():
		return
	for x in range(2, map[0].length() - 2, 5):
		for y in range(1, map.size() - 4, 3):
			var roll := (x * 7 + y * 13 + x * y) % 11
			if roll > 6 or not _empty(x, y):
				continue
			var kind: String = kinds[roll % kinds.size()]
			var at := Vector2(x * T + 4, y * T + 4)
			Art.frame(self, _icons, ICONS.find(kind), at, Vector2(24, 24), Art.DIM)
			draw_rect(Rect2(at + Vector2(3, 26), Vector2(10 + roll * 2, 1)), Art.DIM)


## Cabe um ícone aqui? (2x2 células livres de parede, item e bug)
func _empty(x: int, y: int) -> bool:
	for j in 2:
		for i in 2:
			if _char(x + i, y + j) != ".":
				return false
	return true


func _grid() -> void:
	for y in range(1, map.size()):
		for x in range(1, map[0].length()):
			draw_rect(Rect2(x * T - 2, y * T, 5, 1), Art.DIM)
			draw_rect(Rect2(x * T, y * T - 2, 1, 5), Art.DIM)


## Setinhas discretas nas saídas da sala.
func _exit_arrows() -> void:
	var width: int = map[0].length() * T
	for link in exits:
		var right: bool = link.side == "right"
		var tip := Vector2(width - 5 if right else 5, (link.rows[0] + link.rows[1] + 1) * T / 2.0)
		var back := -1 if right else 1
		for i in 4:
			draw_rect(Rect2(tip + Vector2(back * i, -i), Vector2(1, 1)), Art.WHITE)
			draw_rect(Rect2(tip + Vector2(back * i, i), Vector2(1, 1)), Art.WHITE)
