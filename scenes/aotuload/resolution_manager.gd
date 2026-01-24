extends Node
 #class_name ResolutionManager

# 预设分辨率选项
var preset_resolutions = {
	"low": Vector2i(1280, 720),
	"medium": Vector2i(1920, 1080), 
	"high": Vector2i(2560, 1440),
	"ultra": Vector2i(3840, 2160)
}

func _ready():
	# 监听窗口大小变化
	get_tree().root.size_changed.connect(_on_window_resized)
	set_initial_resolution()

# 设置初始分辨率
func set_initial_resolution():
	var screen_size = DisplayServer.screen_get_size()
	# 选择最接近屏幕尺寸的预设
	var target_resolution = get_closest_resolution(screen_size)
	set_resolution(target_resolution)

## 动态修改分辨率
## @param new_size: Vector2i 新的分辨率尺寸
## @param fullscreen: bool 是否全屏
func set_resolution(new_size: Vector2i, fullscreen: bool = false):
	
	
	if fullscreen:
		# 全屏模式
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		# 窗口模式
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(new_size)
		# 居中窗口
		center_window(new_size)
	# 更新所有UI元素
	update_ui_scaling(new_size)
	# 更新游戏内容缩放
	update_game_scaling(new_size)

# 窗口居中
func center_window(size: Vector2i):
	var screen_size = DisplayServer.screen_get_size()
	var position = (screen_size - size) / 2
	DisplayServer.window_set_position(position)

# 更新UI缩放
func update_ui_scaling(new_size: Vector2i):
	#var base_resolution = Vector2(
		#ProjectSettings.get_setting("display/window/size/viewport_width"),
		#ProjectSettings.get_setting("display/window/size/viewport_height")
	#)
	#
	#var scale_factor = min(new_size.x / base_resolution.x, new_size.y / base_resolution.y)
	#
	## 更新所有CanvasLayer节点
	#for child in get_tree().root.get_children():
		#if child is CanvasLayer:
			#child.scale = Vector2(scale_factor, scale_factor)
	pass	

# 更新游戏内容缩放
func update_game_scaling(new_size: Vector2i):
	#var base_resolution = Vector2(
		#ProjectSettings.get_setting("display/window/size/viewport_width"),
		#ProjectSettings.get_setting("display/window/size/viewport_height")
	#)
	var window = get_tree().root
	window.size = new_size
	window.content_scale_size = new_size
	
	# # 2D游戏：调整Camera2D缩放
	# var cameras = get_tree().get_nodes_in_group("camera")
	# for camera in cameras:
	# 	if camera is Camera2D:
	# 		var aspect_ratio = new_size.x / new_size.y
	# 		var base_aspect = base_resolution.x / base_resolution.y
			
	# 		if aspect_ratio > base_aspect:
	# 			camera.zoom = Vector2(1, 1) * (new_size.y / base_resolution.y)
	# 		else:
	# 			camera.zoom = Vector2(1, 1) * (new_size.x / base_resolution.x)



# 获取最接近的预设分辨率
func get_closest_resolution(target: Vector2i) -> Vector2i:
	var closest = preset_resolutions["medium"]
	var min_distance = INF
	
	for resolution in preset_resolutions.values():
		var distance = target.distance_squared_to(resolution)
		if distance < min_distance:
			min_distance = distance
			closest = resolution
	
	return closest

# 窗口大小变化回调
func _on_window_resized():
	var new_size = get_tree().root.size
	update_ui_scaling(new_size)
	#update_game_scaling(new_size)
