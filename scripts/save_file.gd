class_name SaveFile
## Leitura e escrita do save. É JSON de propósito: só dados, nada executável.
##
## Gravar: escreve em .tmp, confere, guarda o save válido anterior em .bak e troca.
## Ler: usa o principal; se faltar ou estiver inválido, usa o .bak.

const VERSION := 1
const PATH := "user://save.json"


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## Devolve {} se não houver save válido.
static func read(path: String) -> Dictionary:
	var data := _read_one(path)
	return data if not data.is_empty() else _read_one(path + ".bak")


static func write(path: String, data: Dictionary) -> bool:
	var out := data.duplicate()
	out["version"] = VERSION
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(out, "\t"))
	file.close()
	if _read_one(tmp).is_empty():
		return false  # disco cheio ou escrita pela metade: mantém o save atual

	var target := ProjectSettings.globalize_path(path)
	# um arquivo estragado nunca substitui a cópia boa
	if not _read_one(path).is_empty():
		if DirAccess.copy_absolute(target, target + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(target + ".tmp", target) == OK


static func _read_one(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var data: Variant = json.data
	if not data is Dictionary:
		return {}
	return data if _is_valid(data) else {}


static func _is_valid(data: Dictionary) -> bool:
	var version: Variant = data.get("version")
	if not (version is float or version is int) or int(version) != VERSION:
		return false

	var restore: Variant = data.get("restore")
	if not restore is String:
		return false
	# "" = ainda sem ponto de restauração; senão, precisa ser uma sala que tem um
	if restore != "":
		if not Rooms.DATA.has(restore) or Rooms.restore_point(restore) == Vector2.ZERO:
			return false

	if not data.get("dash") is bool:
		return false
	for key in ["visited", "taken"]:
		var list: Variant = data.get(key)
		if not list is Array:
			return false
		for item in list:
			if not item is String:
				return false
			if key == "visited" and not Rooms.DATA.has(item):
				return false
	return true
