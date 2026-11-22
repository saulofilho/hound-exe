extends SceneTree
## Escreve THIRD_PARTY_NOTICES.txt com as licenças do Godot desta versão.
## Uso: godot --headless --path . -s tools/notices.gd -- /caminho/de/saida.txt


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("faltou o arquivo de saida")
		quit(1)
		return
	var out := PackedStringArray()
	var rule := "=".repeat(72)
	out.append("Hound.exe - third-party notices\n")
	out.append("The game's code, art, font, music and sounds do not include third-party assets.")
	out.append("It is built with Godot Engine %s, under the licenses below.\n" % Engine.get_version_info().string)
	out.append(rule + "\nGodot Engine license\n" + rule)
	out.append(Engine.get_license_text())
	out.append(rule + "\nComponents bundled with Godot Engine\n" + rule)
	for component in Engine.get_copyright_info():
		out.append(str(component.name))
		for part in component.parts:
			for line in part.copyright:
				out.append("    Copyright " + str(line))
			out.append("    License: " + str(part.license))
		out.append("")
	out.append(rule + "\nLicense texts\n" + rule)
	var licenses := Engine.get_license_info()
	for name in licenses:
		out.append("\n--- %s ---\n" % name)
		out.append(str(licenses[name]))
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("nao consegui escrever " + args[0])
		quit(1)
		return
	file.store_string("\n".join(out))
	file.close()
	await root.get_node("Sound").shutdown()
	quit()
