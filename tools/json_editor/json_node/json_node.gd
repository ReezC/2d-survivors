extends GraphNode

@export var json_node_slot_scene: PackedScene

var node_data = null
var data_type = TYPE_NIL
var node_type = TYPE_NIL
var parent_node = null
var parent_slot_index = -1
var child_nodes = {}
var slot_instances = {}
## 设置节点数据
## 会将节点的title和name信息初始化
## 初始拥有slot[0]，内容为node_name



func set_node_data(node_data,node_name="未命名") -> void:
	node_data = node_data
	data_type = typeof(node_data)
	node_type = data_type
	match node_type:
		TYPE_NIL:
			self.title += " (null)"
		TYPE_BOOL:
			self.title += " (bool)"
		TYPE_INT, TYPE_FLOAT:
			self.title += " (number)"
		TYPE_STRING:
			self.title += " (string)"
		TYPE_ARRAY:
			self.title += " (array[%d])" % node_data.size()
		TYPE_DICTIONARY:
			self.title += " (object)"
	
	# name 应设置为唯一标识
	self.name = node_name
	var name_slot = get_node("NameSlot") as JSONNodeSlot
	name_slot.get_node("KeyLabel").text = self.name

	# 将'$type'键的值作为title
	if node_type == TYPE_DICTIONARY:
		self.title = node_data.get("$type","空类型")
	

## 设置标题颜色
func set_node_color(color: Color) -> void:
	var name_slot = get_node("NameSlot") as JSONNodeSlot
	name_slot.get_node("KeyLabel").add_theme_color_override("font_color", color)
	self.add_theme_color_override("title_color", color)

func add_slot(json_node_slot: JSONNodeSlot,slot_index = -1, right_enable: bool = false, slot_color: Color = Color.WHITE) -> void:
	self.add_child(json_node_slot)
	self.set_slot_enabled_right(slot_index, right_enable)
	self.set_slot_color_right(slot_index, slot_color)
	slot_instances[slot_index] = json_node_slot
