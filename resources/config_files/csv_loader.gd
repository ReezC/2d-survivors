extends Node
class_name CsvLoader

func load_csv(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("无法打开CSV文件: " + path)
		return []
	var content = file.get_csv_line(",")
	var headers = content
	var line = []
	while not file.eof_reached():
		content = file.get_csv_line(",")
		var obj: Dictionary = {}
		for i in range(content.size()):
			obj[headers[i]] = content[i]
		line.push_back(obj)
	return line

func _ready() -> void:
	print(load_csv("res://resources/config_files/attribute.csv"))
	pass
