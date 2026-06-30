extends Node
## 地图加载测试场景

@export var test_map_id: int = 10000

# 相机控制
var _camera: Camera2D = null
var _is_dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _camera_start_pos: Vector2 = Vector2.ZERO
var _zoom_min: float = 0.1
var _zoom_max: float = 3.0

func _ready() -> void:
	# 创建相机（先 add_child 再 make_current）
	_camera = Camera2D.new()
	_camera.name = "Camera2D"
	_camera.zoom = Vector2(0.5, 0.5)
	add_child(_camera)
	_camera.make_current()
	
	# 创建 MapLoader 实例
	var loader = MapLoader.new()
	loader.name = "MapLoader"
	loader.maps_root_dir = "res://assets/maps/exported"
	add_child(loader)
	
	# 连接信号
	loader.map_loaded.connect(_on_map_loaded)
	loader.map_load_failed.connect(_on_map_failed)
	
	# 加载地图
	print("Loading map %d..." % test_map_id)
	var map_node = loader.load_map(test_map_id)
	
	if map_node:
		add_child(map_node)
		print("Map node added to scene")

func _on_map_loaded(map_id: int) -> void:
	print("Map %d loaded successfully!" % map_id)
	
	var map_root = get_node_or_null("Map_" + str(map_id))
	if map_root:
		var count = _count_nodes(map_root)
		print("Total nodes in map: %d" % count)
	
	# 相机居中到地图
	_center_camera_on_map()

func _on_map_failed(map_id: int, error: String) -> void:
	printerr("Map %d load failed: %s" % [map_id, error])

## 将相机移动到地图中心
func _center_camera_on_map() -> void:
	var loader = get_node_or_null("MapLoader") as MapLoader
	if not loader or not _camera:
		return
	
	var data = loader.get_current_map_data()
	var info = data.get("info", {})
	var vr_left = info.get("vrLeft", -500)
	var vr_right = info.get("vrRight", 500)
	var vr_top = info.get("vrTop", -500)
	var vr_bottom = info.get("vrBottom", 500)
	
	var center_x = float(vr_left + vr_right) / 2.0
	var center_y = float(vr_top + vr_bottom) / 2.0
	_camera.position = Vector2(center_x, center_y)
	
	# 自动缩放以适配窗口
	var map_width = vr_right - vr_left
	var map_height = vr_bottom - vr_top
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_x = viewport_size.x / float(map_width) if map_width > 0 else 1.0
	var zoom_y = viewport_size.y / float(map_height) if map_height > 0 else 1.0
	var auto_zoom = min(zoom_x, zoom_y) * 0.85  # 留 15% 边距
	auto_zoom = clamp(auto_zoom, _zoom_min, _zoom_max)
	_camera.zoom = Vector2(auto_zoom, auto_zoom)
	
	print("Camera: center=(%.0f, %.0f) zoom=%.2f" % [center_x, center_y, auto_zoom])
	print("Map bounds: left=%d right=%d top=%d bottom=%d size=%dx%d" % [vr_left, vr_right, vr_top, vr_bottom, map_width, map_height])

func _count_nodes(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

# ============================================
# 输入处理
# ============================================

func _input(event: InputEvent) -> void:
	if not _camera:
		return
	
	# 鼠标滚轮缩放（以鼠标位置为中心）
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(event.position, 1.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(event.position, 1.0 / 1.2)
	
	# 鼠标中键拖拽
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
			if _is_dragging:
				_drag_start = event.position
				_camera_start_pos = _camera.position
	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _drag_start
		_camera.position = _camera_start_pos - delta / _camera.zoom
	
	# 方向键移动相机（用 _process 持续移动）
	if event is InputEventKey:
		if event.keycode == KEY_HOME and event.pressed:
			_center_camera_on_map()

# 持续按键移动（在 _process 中处理，避免 _input 的单次触发）
func _process(_delta: float) -> void:
	if not _camera:
		return
	var move_speed = 500.0 * _delta
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		_camera.position.x -= move_speed
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		_camera.position.x += move_speed
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		_camera.position.y -= move_speed
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		_camera.position.y += move_speed

## 以鼠标位置为中心缩放
func _zoom_at_point(mouse_pos: Vector2, factor: float) -> void:
	var old_zoom = _camera.zoom
	var new_zoom = old_zoom * factor
	new_zoom = Vector2(
		clamp(new_zoom.x, _zoom_min, _zoom_max),
		clamp(new_zoom.y, _zoom_min, _zoom_max)
	)
	
	# 计算鼠标在世界空间中的位置
	var mouse_world_before = _camera.get_screen_center_position() + (mouse_pos - get_viewport().get_visible_rect().size / 2) / old_zoom
	
	_camera.zoom = new_zoom
	
	# 调整相机位置使鼠标指向的世界点不变
	var mouse_world_after = _camera.get_screen_center_position() + (mouse_pos - get_viewport().get_visible_rect().size / 2) / new_zoom
	_camera.position += mouse_world_before - mouse_world_after
