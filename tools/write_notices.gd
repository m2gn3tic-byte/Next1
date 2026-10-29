extends SceneTree
## Include the engine's own notices and the bundled font license in the web ZIP.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var destination := args[0] if not args.is_empty() else "res://build/web/THIRD_PARTY_NOTICES.txt"
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Could not write distribution notices")
		quit(1)
		return
	file.store_string("GODOT ENGINE\nhttps://godotengine.org/license/\n\n")
	file.store_string(Engine.get_license_text())
	file.store_string("\n\nGODOT THIRD-PARTY COMPONENT COPYRIGHTS\n\n")
	for component in Engine.get_copyright_info():
		file.store_string(str(component) + "\n\n")
	file.store_string("\nGODOT THIRD-PARTY LICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	for license_name in licenses:
		file.store_string(str(license_name) + "\n" + str(licenses[license_name]) + "\n\n")
	file.store_string("\nDEJAVU FONTS\n\n")
	file.store_string(FileAccess.get_file_as_string("res://assets/fonts/LICENSE.txt"))
	for name in ["OFL-CJK.txt", "OFL-Devanagari.txt", "OFL-Thai.txt"]:
		file.store_string("\n\nNOTO FONT LICENSE — " + name + "\n\n")
		file.store_string(FileAccess.get_file_as_string("res://assets/fonts/" + name))
	file.store_string("\nCJK UI subset renamed Courier CJK UI; see tools/subset_cjk.py.\n")
	file.close()
	quit(0)
