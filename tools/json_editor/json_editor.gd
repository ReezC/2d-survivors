# JsonEditor.gd
extends Control

# JSON数据结构
var json_data = {}
var current_file_path = ""
var is_modified = false
var schema_data = null
var current_node_count = 0

@onready var graph_edit = $GraphEdit
@onready var file_dialog = $FileDialog
@onready var schema_dialog = $SchemaDialog
@onready var save_dialog = $SaveDialog

## key = [TYPE_*]
## value = [int]
@export var json_node_types ={
	TYPE_NIL: 0,
	TYPE_BOOL: 1,
	TYPE_INT: 2,
	TYPE_FLOAT: 3,
	TYPE_STRING: 4,
	TYPE_ARRAY: 5,
	TYPE_DICTIONARY: 6,
}
## key = [int]
## value = [Color]
@export var json_type_colors ={
	0: Color.GRAY,          # TYPE_NIL
	1: Color.ORANGE_RED,    # TYPE_BOOL
	2: Color.DODGER_BLUE,   # TYPE_INT
	3: Color.DODGER_BLUE,   # TYPE_FLOAT
	4: Color.LIME_GREEN,    # TYPE_STRING
	5: Color.MEDIUM_PURPLE, # TYPE_ARRAY
	6: Color.GOLD,          # TYPE_DICTIONARY
}

@export var json_node_scene: PackedScene

func _ready():

	var resolution = Vector2i(1024, 576)
	get_window().content_scale_size = resolution
	get_window().size = resolution
	get_window().position =  DisplayServer.screen_get_size() / 2 - get_window().size / 2
	
	# 在工具栏里添加按钮
	_add_custom_ui_buttons()
	


	
	# 连接信号
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.node_selected.connect(_on_node_selected)
	
	# 连接文件对话框信号
	file_dialog.file_selected.connect(_on_file_dialog_file_selected)
	save_dialog.file_selected.connect(_on_save_dialog_file_selected)
	schema_dialog.file_selected.connect(_on_schema_dialog_file_selected)
	
	
	# 添加右键菜单
	_setup_context_menu()
	
	# # 创建UI按钮
	# _create_ui_buttons()
	
	# 设置窗口初始标题
	update_window_title()

func _add_custom_ui_buttons():
	var menu_box = graph_edit.get_menu_hbox()
	
	# 按钮样式
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	button_style.border_color = Color(0.4, 0.4, 0.4)
	button_style.border_width_left = 2
	button_style.border_width_right = 2
	button_style.border_width_top = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	
	# 创建按钮
	var buttons = [
		{"name": "➕", "tooltip": "新建JSON", "signal": "_on_new_json_pressed"},
		{"name": "🔍", "tooltip": "加载JSON", "signal": "_on_load_json_pressed"},
		{"name": "💾", "tooltip": "保存JSON", "signal": "_on_save_json_pressed"},
		{"name": "📋", "tooltip": "定义Json", "signal": "_on_schema_pressed"}
	]
	
	for button_info in buttons:
		var button = Button.new()
		button.name = button_info.name.replace(" ", "")
		button.text = button_info.name
		button.tooltip_text = button_info.tooltip
		button.custom_minimum_size = Vector2(50, 20)
		button.add_theme_font_size_override("font_size", 16)
		
		# 应用样式
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("hover", button_style.duplicate())
		button.add_theme_stylebox_override("pressed", button_style.duplicate())
		
		var hover_style = button.get_theme_stylebox("hover")
		hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.9)
		
		var pressed_style = button.get_theme_stylebox("pressed")
		pressed_style.bg_color = Color(0.4, 0.4, 0.4, 0.9)
		
		# 连接信号
		button.pressed.connect(Callable(self, button_info.signal))
		
		menu_box.add_child(button)

func _setup_context_menu():
	# 添加右键菜单
	var context_menu = PopupMenu.new()
	context_menu.name = "ContextMenu"
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)
	
	# 添加上下文菜单选项
	context_menu.add_item("添加节点", 0)
	context_menu.add_item("添加数组", 1)
	context_menu.add_item("添加对象", 2)
	context_menu.add_separator()
	context_menu.add_item("删除选中节点", 3)

func _on_context_menu_id_pressed(id):
	var mouse_pos = get_local_mouse_position()
	
	match id:
		0: # 添加节点
			_add_json_node("新增属性", "", mouse_pos)
		1: # 添加数组
			_add_json_node("数组", [], mouse_pos)
		2: # 添加对象
			_add_json_node("对象", {}, mouse_pos)
		3: # 删除选中节点
			_on_delete_nodes_request([])


# 按钮信号处理
func _on_new_json_pressed():
	# 清除当前数据
	json_data = {}
	current_file_path = ""
	is_modified = false
	_clear_all_nodes()
	
	# 打开保存对话框
	save_dialog.mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.title = "新建JSON文件"
	save_dialog.show()

func _on_load_json_pressed():
	# 打开文件对话框
	file_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "加载JSON文件"
	file_dialog.show()

func _on_save_json_pressed():
	if current_file_path and not current_file_path.is_empty():
		# 保存到当前文件
		_save_to_file(current_file_path)
	elif json_data:
		# 没有当前文件，打开保存对话框
		save_dialog.mode = FileDialog.FILE_MODE_SAVE_FILE
		save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		save_dialog.title = "保存JSON文件"
		save_dialog.show()

func _on_schema_pressed():
	# 打开schema文件对话框
	schema_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
	schema_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	schema_dialog.title = "选择Schema文件"
	schema_dialog.show()

# 文件对话框信号处理
func _on_file_dialog_file_selected(path):
	# 关闭对话框并加载文件
	file_dialog.hide()
	_load_json_from_file(path)

func _on_save_dialog_file_selected(path):
	_save_to_file(path)
	current_file_path = path
	is_modified = false
	update_window_title()

func _on_schema_dialog_file_selected(path):
	_load_schema_from_file(path)

# 加载JSON文件
func _load_json_from_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		
		if error == OK:
			json_data = json.data
			current_file_path = file_path
			is_modified = false
			update_window_title()
			_visualize_json_data()
		else:
			print("JSON解析错误: ", json.get_error_message())
			_show_error("JSON解析错误", json.get_error_message())
	else:
		print("无法打开文件: ", file_path)
		_show_error("文件错误", "无法打开文件: " + file_path)

# 保存到文件
func _save_to_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# 从图中重建JSON数据
		_reconstruct_json_from_graph()
		
		# 格式化JSON
		var formatted_json = JSON.stringify(json_data, "\t")
		file.store_string(formatted_json)
		file.close()
		
		is_modified = false
		print("文件已保存: ", file_path)
	else:
		print("无法保存文件: ", file_path)
		_show_error("保存错误", "无法保存文件: " + file_path)

# 从图中重建JSON数据
func _reconstruct_json_from_graph():
	# 这里需要实现从图中节点重建JSON数据的逻辑
	# 目前简单返回加载的数据
	pass

# 加载Schema文件
func _load_schema_from_file(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		
		if error == OK:
			schema_data = json.data
			print("Schema已加载: ", file_path)
			
			# 应用schema规则（后续实现）
			_apply_schema_rules()
		else:
			print("Schema解析错误: ", json.get_error_message())
			_show_error("Schema解析错误", json.get_error_message())
	else:
		print("无法打开Schema文件: ", file_path)
		_show_error("文件错误", "无法打开Schema文件: " + file_path)

# 应用schema规则（占位符）
func _apply_schema_rules():
	# 后续实现schema规则应用
	print("应用schema规则（待实现）")

## 可视化JSON数据
func _visualize_json_data():
	# 清除所有现有节点
	_clear_all_nodes()
	
	if json_data:
		_create_json_node(json_data, current_node_count, Vector2(400, 300))
		
		
		# 递归创建子节点
		#_create_child_nodes("root", json_data, Vector2(400, 300), 0)


## 递归创建JSON节点
## TODO: id 管理
func _create_json_node(node_data,node_id=0, position = Vector2.ZERO,parent_port_type = 0):
	
	# 每次创建node，需要将编辑器记录的node数量+1
	current_node_count += 1

	var node = json_node_scene.instantiate()
	node.position_offset = position

	
	# 设置节点数据
	var node_name = "Node_%d" % node_id
	node.set_node_data(node_data,node_name)

	# 设置节点颜色
	var node_color = json_type_colors[json_node_types[node.node_type]]
	node.set_node_color(node_color)
	

	## 处理字典：添加slots
	## 以键='$type'的值作为slot[0]，并将其设置为node的title
	## 以键='$note'的值作为注释，不创建slot
	## 其他键值对，若key不以'$'开头，则创建slot 
	
	if node.node_type == TYPE_DICTIONARY:
		var now_slot_index = 0
		
		for i in range(node_data.keys().size()):
			var key = node_data.keys()[i]
			var value = node_data[key]

			if key == "$type":
				# 标题已在node初始化时内部设置
				continue
			elif key == "$note":
				# 注释不创建slot
				node.tooltip_text = str(value)
				continue
			else:
				now_slot_index += 1

			var json_node_slot = node.json_node_slot_scene.instantiate()
			json_node_slot.name = str(key)
			json_node_slot.get_node("KeyLabel").text = str(key)


			var right_enable = false
			var value_item = Label.new()
			var slot_color = json_type_colors[json_node_types[typeof(value)]] 
			var value_type = typeof(value)
			
			# godot 会把 不带小数点的数字 解析为 float 类型，所以手动修改
			if value_type == TYPE_FLOAT and value == float(int(value)):
				value_type = TYPE_INT
			
			match value_type:
				TYPE_NIL:
					value_item = json_node_slot.get_node("OtherType")
					value_item.visible = true
					value_item.text = "null"
					
				TYPE_BOOL:
					# 设置复选框可见
					value_item = json_node_slot.get_node("CheckButton")
					value_item.visible = true
					value_item.button_pressed = bool(value)

				TYPE_INT:
					# 设置数字输入框可见
					value_item = json_node_slot.get_node("SpinBox")
					value_item.visible = true
					value_item.step = 1
					value_item.allow_greater = true
					value_item.allow_lesser = true
					value_item.value = float(value)

				
				TYPE_FLOAT:
					# 设置数字输入框可见
					value_item = json_node_slot.get_node("SpinBox")
					value_item.visible = true
					value_item.step = 0.001
					value_item.allow_greater = true
					value_item.allow_lesser = true
					value_item.value = float(value)
					
				TYPE_STRING:
					# 设置文本输入框可见
					value_item = json_node_slot.get_node("LineEdit")
					value_item.visible = true
					value_item.text = str(value)
					
				TYPE_ARRAY:
					# 设置数组标签可见
					value_item = json_node_slot.get_node("OtherType")
					value_item.visible = true
					value_item.text = "Array[%d]" % value.size()
					right_enable = true
					
				TYPE_DICTIONARY:
					# 设置对象标签可见
					value_item = json_node_slot.get_node("OtherType")
					value_item.visible = true
					value_item.text = "其他对象"
					right_enable = true
					
					
			value_item.add_theme_color_override("font_color", slot_color)
			json_node_slot.get_node("KeyLabel").add_theme_color_override("font_color", slot_color)
			json_node_slot.slot_type = value_type
			node.add_slot(json_node_slot, now_slot_index, right_enable, slot_color)
			
			
		graph_edit.add_child(node)

		# 遍历node的slots，连接父节点，递归创建子节点
		for slot_key in node.slot_instances.keys():
			if node.is_slot_enabled_right(slot_key):
				var slot_instance = node.slot_instances[slot_key] as JSONNodeSlot
				var key = slot_instance.name
				var value = node_data[key]
				var value_type = slot_instance.slot_type
				match value_type:
					TYPE_DICTIONARY:
						var slot_position = node.position_offset + Vector2(250, 0)
						var child_node = _create_json_node(value, current_node_count, slot_position, json_node_types[value_type])
						# 连接节点
						graph_edit.connect_node(
							node.name, 
							slot_key,
							child_node.name, 
							0
						)
					TYPE_ARRAY: # 列表结构只允许一层
						if value.size() > 0:
							for j in range(value.size()):
								var array_value = value[j]
								var array_value_type = typeof(array_value)
								var slot_position = node.position_offset + Vector2(250, j * 100)
								var child_node = _create_json_node(array_value, current_node_count, slot_position, json_node_types[array_value_type])
								# 连接节点
								graph_edit.connect_node(
									node.name, 
									slot_key,
									child_node.name, 
									0
								)
	
	elif node.node_type == TYPE_ARRAY:
		pass  # TODO：数组暂不处理

	return node

# 添加JSON节点（用于手动添加）
func _add_json_node(name, data, position = Vector2.ZERO):
	var node = _create_json_node(name, data, position)
	graph_edit.add_child(node)
	is_modified = true
	update_window_title()

# 清除所有节点
func _clear_all_nodes():
	for node in graph_edit.get_children():
		if node is GraphNode:
			node.queue_free()
	
	# 清除所有连接
	for connection in graph_edit.get_connection_list():
		graph_edit.disconnect_node(
			connection["from"], 
			connection["from_port"], 
			connection["to"], 
			connection["to_port"]
		)

# 更新窗口标题
func update_window_title():
	var title = "JSON编辑器"
	if not current_file_path.is_empty():
		title += " - " + current_file_path.get_file()
	if is_modified:
		title += " *"
	get_tree().root.title = title

# 显示错误对话框
func _show_error(title, message):
	var alert = AcceptDialog.new()
	alert.title = title
	alert.dialog_text = message
	add_child(alert)
	alert.popup_centered()

# GraphEdit信号处理
func _on_connection_request(from_node, from_port, to_node, to_port):
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	is_modified = true
	update_window_title()

func _on_disconnection_request(from_node, from_port, to_node, to_port):
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	is_modified = true
	update_window_title()

func _on_delete_nodes_request(nodes):
	for node in graph_edit.get_children():
		if node is GraphNode and node.selected:
			node.queue_free()
	
	is_modified = true
	update_window_title()

func _on_node_selected(node):
	print("节点选中: ", node.name)

func _on_node_close_request(node_name):
	var node = graph_edit.get_node_or_null(NodePath(node_name))
	if node:
		node.queue_free()
		is_modified = true
		update_window_title()

# 右键点击
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var context_menu = get_node_or_null("ContextMenu")
		# print(context_menu)
		if context_menu:
			context_menu.position = get_global_mouse_position()
			context_menu.popup()
