extends GraphNode

class_name JSONNode
@onready var type_name_label: Label = $TypeSlot/TypeNameLabel

@export var node_data ={}
var node_type = null

enum slot_types  {
	TYPE_DICTIONARY,
	TYPE_ARRAY,
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_BOOL,
}

var slot_colors = {
	TYPE_DICTIONARY = Color.ROYAL_BLUE,
	TYPE_ARRAY = Color.DARK_ORANGE,
	TYPE_INT = Color.FOREST_GREEN,
	TYPE_FLOAT = Color.FOREST_GREEN,
	TYPE_STRING = Color.PURPLE,
	TYPE_BOOL = Color.TEAL,
}


func add_slots_from_data() -> void:
	for i in node_data.size():
		var key = node_data.keys()[i]
		var value = node_data[key]
		if key == "$type":
			type_name_label.text = str(value)
			node_type = str(value)
			title = str(value)
		else:
			match typeof(value):
				TYPE_DICTIONARY:
					var h_split_container = HSplitContainer.new()
					var slot_label = Label.new()
					slot_label.text = key + ": "
					h_split_container.add_child(slot_label)
					var slot_value = "{}"
					var slot_value_label = Label.new()
					slot_value_label.text = slot_value
					slot_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					h_split_container.add_child(slot_value_label)
					add_child(h_split_container)
					set_slot(
						i, 
						false, 
						slot_types.TYPE_DICTIONARY, 
						slot_colors.TYPE_DICTIONARY, 
						true,
						slot_types.TYPE_DICTIONARY, 
						slot_colors.TYPE_DICTIONARY
					)
	
				TYPE_ARRAY:
					var h_split_container = HSplitContainer.new()
					var slot_label = Label.new()
					slot_label.text = key + ": "
					h_split_container.add_child(slot_label)
					var slot_value = "[]"
					var slot_value_label = Label.new()
					slot_value_label.text = slot_value
					slot_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					h_split_container.add_child(slot_value_label)
					add_child(h_split_container)
					set_slot(
						i, 
						false, 
						slot_types.TYPE_ARRAY, 
						slot_colors.TYPE_ARRAY, 
						true,
						slot_types.TYPE_ARRAY, 
						slot_colors.TYPE_ARRAY
					)
				TYPE_INT:
					var h_split_container = HSplitContainer.new()
					var slot_label = Label.new()
					slot_label.text = key + ": "
					h_split_container.add_child(slot_label)
					var slot_value = SpinBox.new()
					slot_value.min_value = -INF
					slot_value.max_value = INF
					slot_value.step = 1
					slot_value.value = value
					slot_value.connect("value_changed", Callable(self, "_on_slot_value_changed").bind(key))
					slot_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					h_split_container.add_child(slot_value)
					add_child(h_split_container)
					set_slot(
						i,
						false,
						slot_types.TYPE_INT,
						slot_colors.TYPE_INT,
						false,
						slot_types.TYPE_INT,
						slot_colors.TYPE_INT
					)
				TYPE_FLOAT:
					var h_split_container = HSplitContainer.new()
					var slot_label = Label.new()
					slot_label.text = key + ": "
					h_split_container.add_child(slot_label)
					var slot_value = SpinBox.new()
					slot_value.min_value = -INF
					slot_value.max_value = INF
					slot_value.step = 0.01
					slot_value.value = value
					slot_value.connect("value_changed", Callable(self, "_on_slot_value_changed").bind(key))
					slot_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					h_split_container.add_child(slot_value)
					add_child(h_split_container)
					set_slot(
						i,
						false,
						slot_types.TYPE_FLOAT,
						slot_colors.TYPE_FLOAT,
						false,
						slot_types.TYPE_FLOAT,
						slot_colors.TYPE_FLOAT
					)	
					
				TYPE_STRING:
					var h_split_container = HSplitContainer.new()
					var slot_label = Label.new()
					slot_label.text = key + ": "
					h_split_container.add_child(slot_label)
					var slot_value = LineEdit.new()
					slot_value.text = value
					slot_value.connect("text_changed", Callable(self, "_on_slot_value_changed").bind(key))
					slot_value.alignment = HORIZONTAL_ALIGNMENT_RIGHT
					h_split_container.add_child(slot_value)
					add_child(h_split_container)
					set_slot(
						i,
						false,
						slot_types.TYPE_STRING,
						slot_colors.TYPE_STRING,
						false,
						slot_types.TYPE_STRING,
						slot_colors.TYPE_STRING
					)	
					
				TYPE_BOOL:
					var h_split_container = HSplitContainer.new()
					var slot_label = Label.new()
					slot_label.text = key + ": "
					h_split_container.add_child(slot_label)
					var slot_value = CheckBox.new()
					slot_value.pressed = value
					slot_value.connect("toggled", Callable(self, "_on_slot_value_changed").bind(key))
					h_split_container.add_child(slot_value)
					slot_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					add_child(h_split_container)
					set_slot(
						i,
						false,
						slot_types.TYPE_BOOL,
						slot_colors.TYPE_BOOL,
						false,
						slot_types.TYPE_BOOL,
						slot_colors.TYPE_BOOL
					)
				_:
					push_warning("Unsupported data type for key: %s" % key)
		
				

func _on_slot_value_changed(key: String, new_value) -> void:
	node_data[key] = new_value
