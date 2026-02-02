extends JSONNode

class_name SkillJSONNode



func _ready() -> void:
	type_name_label.text = "Skill"
	if node_data.is_empty():
		node_data["$type"] = "Skill"
		node_data["name"] = "未命名"
		node_data["CD"] = {}
		node_data["skillTriggerRange"] = {}
		node_data["buffOccupyAnim"] = ""
		node_data["buff"] = {}
	
	add_slots_from_data()


	
