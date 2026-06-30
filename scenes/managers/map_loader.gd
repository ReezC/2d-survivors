extends Node
## MapleStory 地图加载器 — 参考 MapleNecrocer 渲染方式
class_name MapLoader

signal map_loaded(map_id: int)
signal map_load_failed(map_id: int, error: String)

@export var maps_root_dir: String = "res://assets/maps/exported"
@export var default_tile_color: Color = Color(0.3, 0.5, 0.2)
@export var default_obj_color: Color = Color(0.3, 0.3, 0.8)
@export var default_back_color: Color = Color(0.2, 0.4, 0.2)

var _current_map_data: Dictionary = {}
var _current_map_id: int = 0
var _map_root_node: Node2D = null
var _image_cache: Dictionary = {}

func load_map(map_id: int) -> Node2D:
	unload_map()
	var map_id_str = _fmt(map_id)
	var json_path = maps_root_dir + "/" + map_id_str + "/map_data.json"
	if not FileAccess.file_exists(json_path):
		push_error("MapLoader: not found: " + json_path)
		map_load_failed.emit(map_id, "JSON not found")
		return null
	var f = FileAccess.open(json_path, FileAccess.READ)
	var txt = f.get_as_text(); f.close()
	var j = JSON.new()
	if j.parse(txt) != OK:
		push_error("MapLoader: JSON parse error")
		map_load_failed.emit(map_id, "JSON parse error")
		return null
	_current_map_data = j.get_data()
	_current_map_id = map_id
	_map_root_node = _build()
	map_loaded.emit(map_id)
	return _map_root_node

func unload_map():
	if _map_root_node: _map_root_node.queue_free(); _map_root_node = null
	_back_sprites.clear()
	_current_map_data = {}; _current_map_id = 0; _image_cache.clear()


func get_current_map_data() -> Dictionary: return _current_map_data
func _fmt(id: int) -> String: return "%09d" % id

# ================================================================
# 构建场景
# ================================================================

func _build() -> Node2D:
	var r = Node2D.new(); r.name = "Map_" + str(_current_map_id)
	_bg(r); _back(r); _tile(r); _obj(r); _fh(r); _portal(r); _life(r)
	return r

# ================================================================
# 背景色
# ================================================================
func _bg(r: Node2D):
	var c = ColorRect.new(); c.name = "Sky"
	c.color = Color(0.05, 0.1, 0.2); c.size = Vector2(10000, 10000)
	c.position = Vector2(-5000, -5000); c.z_index = -1000
	r.add_child(c)

# ================================================================
# Back 远景层（手动视差计算）
#
# MapleNecrocer 公式:
#   Back.X = -PosX - (100+RX)/100 * (Camera.X + DisplaySize.X/2) + Camera.X
# 简化: 相对于地图原点，back 移动速度 = 1 + RX/100 倍的相机移动
#   等价于: back 位置 = wz_x + (1 + RX/100) * (-Camera.X)
#   Godot 中: sprite 放在 ParallaxLayer 或手动 update 位置
#
# 这里用手动计算，在 _process 中根据相机位置更新 back sprite 位置
# ================================================================
var _back_sprites: Array = []  # [{sprite, base_x, base_y, rx, ry, btype, front, flow_x, flow_y, chip_w, chip_h, is_tiled}]


func _back(r: Node2D):
	var data = _current_map_data.get("back", [])
	if data.is_empty(): return
	
	_back_sprites.clear()
	
	for it in data:
		var btype = it.get("type", 0)
		var cx = it.get("cx", 0)
		var cy = it.get("cy", 0)
		var tex = null
		var imf = it.get("imageFile", "")
		if imf != null and imf != "":
			tex = _tex(imf)
		
		# 获取图片尺寸
		var img_w = 0
		var img_h = 0
		if tex:
			img_w = int(tex.get_width())
			img_h = int(tex.get_height())
		
		# 确定平铺尺寸: cx/cy 为 0 时用图片原始尺寸
		var chip_w = cx if cx > 0 else img_w
		var chip_h = cy if cy > 0 else img_h
		
		# 判断是否需要平铺
		var tiled = btype >= 1 and btype <= 7
		
		# 创建节点（直接放地图根节点下，用世界坐标）
		var s: Node2D
		if tiled:
			s = _create_tiled_back(tex, btype, chip_w, chip_h, it)
		else:
			var spr = Sprite2D.new()
			spr.centered = false
			spr.texture = tex if tex else _ph(Vector2(16, 16), default_back_color)
			var org = it.get("origin", { "x": 0, "y": 0 })
			var ox = org.get("x", 0)
			var oy = org.get("y", 0)
			var flip = it.get("flip", false)
			if flip and tex:
				ox = -ox + int(tex.get_size().x)
			spr.offset = Vector2(-ox, -oy)
			spr.flip_h = flip
			var alpha = it.get("alpha", 255) / 255.0
			spr.modulate.a = alpha
			s = spr
		
		s.name = "back_" + str(it.get("index", 0))
		var front = it.get("front", false)
		s.z_index = 500 if front else -500
		
		r.add_child(s)
		
		_back_sprites.append({
			sprite = s,
			base_x = it.get("x", 0),
			base_y = it.get("y", 0),
			rx = it.get("rx", 0),
			ry = it.get("ry", 0),
			btype = btype,
			front = front,
			flow_x = it.get("flowX", 0),
			flow_y = it.get("flowY", 0),
			chip_w = chip_w,
			chip_h = chip_h,
			img_w = img_w,
			img_h = img_h,
			is_tiled = tiled,
		})
	
	print("Back layers: " + str(data.size()) + " items (world-space parallax)")

# 创建平铺背景节点
func _create_tiled_back(tex: Texture2D, btype: int, chip_w: int, chip_h: int, item: Dictionary) -> Node2D:
	var container = Node2D.new()
	
	# 平铺方向
	var tile_h = btype == 1 or btype == 4  # 水平平铺
	var tile_v = btype == 2 or btype == 5  # 垂直平铺
	var tile_full = btype == 3 or btype == 6 or btype == 7  # 全平铺
	
	# 根据视口大小创建足够的子Sprite来覆盖屏幕
	# 注意：实际平铺会在 _process 中根据相机位置动态调整
	var spr = Sprite2D.new()
	spr.centered = false
	spr.texture = tex if tex else _ph(Vector2(16, 16), default_back_color)
	
	var org = item.get("origin", { "x": 0, "y": 0 })
	var ox = org.get("x", 0)
	var oy = org.get("y", 0)
	var flip = item.get("flip", false)
	if flip and tex:
		ox = -ox + int(tex.get_size().x)
	spr.offset = Vector2(-ox, -oy)
	spr.flip_h = flip
	
	var alpha = item.get("alpha", 255) / 255.0
	spr.modulate.a = alpha
	
	container.add_child(spr)
	container.set_meta("tile_h", tile_h or tile_full)
	container.set_meta("tile_v", tile_v or tile_full)
	container.set_meta("chip_w", chip_w)
	container.set_meta("chip_h", chip_h)
	
	return container


# 在 _process 中更新 back 层位置（世界坐标）
# 视差公式: back_pos = base_pos + (-rx/100) * camera_pos
func _process(_delta: float) -> void:
	if _back_sprites.is_empty():
		return
	
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	
	var cx = cam.global_position.x
	var cy = cam.global_position.y
	
	var vp = get_viewport().get_visible_rect().size
	var vw = vp.x / cam.zoom.x
	var vh = vp.y / cam.zoom.y
	
	for bd in _back_sprites:
		var s = bd.sprite
		if not is_instance_valid(s): continue
		
		var btype = bd.btype
		var rx = bd.rx
		var ry = bd.ry
		var base_x = bd.base_x
		var base_y = bd.base_y
		
		# 世界坐标视差公式
		var pos_x = base_x + (-rx / 100.0) * cx
		var pos_y = base_y + (-ry / 100.0) * cy
		
		# 特殊类型自动移动
		if btype == 4 or btype == 6:
			pos_x -= rx * 5.0 * _delta
		if btype == 5 or btype == 7:
			pos_y -= ry * 5.0 * _delta
		
		# FlowX/FlowY 流动效果
		if bd.flow_x != 0:
			pos_x -= bd.flow_x * 5.0 * _delta
		if bd.flow_y != 0:
			pos_y -= bd.flow_y * 5.0 * _delta
		
		if bd.is_tiled:
			_update_tiled_back(bd, pos_x, pos_y, vw, vh)
		else:
			s.position = Vector2(pos_x, pos_y)

# 更新平铺背景的子节点
# 容器位置跟随视差，子节点在容器内平铺
func _update_tiled_back(bd: Dictionary, world_x: float, world_y: float, vw: float, vh: float) -> void:
	var container = bd.sprite
	var tile_h = container.get_meta("tile_h", false)
	var tile_v = container.get_meta("tile_v", false)
	var chip_w = container.get_meta("chip_w", 1)
	var chip_h = container.get_meta("chip_h", 1)
	
	if chip_w <= 0: chip_w = 1
	if chip_h <= 0: chip_h = 1
	
	# 容器位置 = 视差后的世界坐标
	container.position = Vector2(world_x, world_y)
	
	# 获取相机位置
	var cam = get_viewport().get_camera_2d()
	var cx = cam.global_position.x if cam else 0.0
	var cy = cam.global_position.y if cam else 0.0
	
	# 计算视口在容器本地坐标系中的范围
	# 容器本地坐标 = 世界坐标 - 容器世界坐标
	var local_left = (cx - vw / 2.0) - world_x
	var local_top = (cy - vh / 2.0) - world_y
	var local_right = local_left + vw
	var local_bottom = local_top + vh
	
	# 扩展一些边距
	local_left -= chip_w
	local_top -= chip_h
	local_right += chip_w
	local_bottom += chip_h
	
	# 计算需要覆盖的 tile 范围
	var start_col = int(floor(local_left / chip_w))
	var end_col = int(ceil(local_right / chip_w))
	var start_row = int(floor(local_top / chip_h))
	var end_row = int(ceil(local_bottom / chip_h))
	
	var need_cols = end_col - start_col
	var need_rows = end_row - start_row
	var needed_count = need_cols * need_rows
	
	# 确保子节点数量足够
	var children = container.get_children()
	var current_count = children.size()
	
	if current_count == 0:
		return
	var template = children[0]
	
	while current_count < needed_count:
		var new_spr = template.duplicate()
		container.add_child(new_spr)
		current_count += 1
	while current_count > needed_count:
		container.remove_child(children[current_count - 1])
		children[current_count - 1].queue_free()
		current_count -= 1
	
	children = container.get_children()
	
	# 放置子节点（相对于容器）
	var idx = 0
	for row in range(start_row, end_row):
		for col in range(start_col, end_col):
			if idx >= children.size(): break
			var child = children[idx]
			var lx = col * chip_w
			var ly = row * chip_h
			if not tile_h:
				lx = 0
			if not tile_v:
				ly = 0
			child.position = Vector2(lx, ly)
			idx += 1



# ================================================================
# Tile 地面层
# ================================================================
func _tile(r: Node2D):
	var ct = Node2D.new(); ct.name = "TileContainer"; ct.z_index = 0
	r.add_child(ct)
	for ld in _current_map_data.get("layers", []):
		var li = ld.get("level", 0)
		for it in ld.get("tile", []):
			var s = _spr(it, false)
			s.z_index = clampi(li * 500 + 100, -4096, 4096)
			s.name = "t_l" + str(li) + "_" + str(it.get("index", 0))
			ct.add_child(s)

# ================================================================
# Obj 物件层
# ================================================================
func _obj(r: Node2D):
	var ct = Node2D.new(); ct.name = "ObjContainer"; ct.z_index = 1
	r.add_child(ct)
	var all: Array = []
	for ld in _current_map_data.get("layers", []):
		var li = ld.get("level", 0)
		for it in ld.get("obj", []):
			it["_l"] = li; all.append(it)
	all.sort_custom(func(a, b): return (a["_l"] * 100000 + a.get("z", 0)) < (b["_l"] * 100000 + b.get("z", 0)))
	for it in all:
		var s = _spr(it, false)
		s.z_index = clampi(it["_l"] * 500 + it.get("z", 0), -4096, 4096)
		s.name = "o_l" + str(it["_l"]) + "_" + str(it.get("index", 0))
		ct.add_child(s)

# ================================================================
# 统一 Sprite 创建（核心：origin → offset = -origin）
# ================================================================
func _spr(item: Dictionary, _is_back: bool) -> Sprite2D:
	var s = Sprite2D.new()
	s.centered = false  # 左上角对齐，与 WZ 坐标一致
	var tex = null
	var imf = item.get("imageFile", "")
	if imf != null and imf != "":
		tex = _tex(imf)
	if not tex:
		tex = _ph(Vector2(16, 16), default_tile_color)
	s.texture = tex
	
	# 关键：offset = -origin（在 Godot 中实现 MonoGame origin 效果）
	var org = item.get("origin", { "x": 0, "y": 0 })
	var ox = org.get("x", 0)
	var oy = org.get("y", 0)
	var flip = item.get("flip", false)
	if flip and tex:
		ox = -ox + int(tex.get_size().x)
	s.offset = Vector2(-ox, -oy)
	
	s.position = Vector2(item.get("x", 0), item.get("y", 0))
	s.flip_h = flip
	
	var alpha = item.get("alpha", 255) / 255.0
	s.modulate.a = alpha
	
	return s

# ================================================================
# Foothold 碰撞
# ================================================================
func _fh(r: Node2D):
	var ct = Node2D.new(); ct.name = "FH"; r.add_child(ct)
	for fh in _current_map_data.get("footholds", []):
		var x1 = fh.get("x1", 0); var y1 = fh.get("y1", 0)
		var x2 = fh.get("x2", 0); var y2 = fh.get("y2", 0)
		if x1 == 0 and y1 == 0 and x2 == 0 and y2 == 0: continue
		var b = StaticBody2D.new(); b.collision_layer = 1; b.collision_mask = 0
		b.name = "fh_" + str(fh.get("id", 0))
		var sh = CollisionShape2D.new()
		var sg = SegmentShape2D.new(); sg.a = Vector2(x1, y1); sg.b = Vector2(x2, y2)
		sh.shape = sg; b.add_child(sh); ct.add_child(b)

# ================================================================
# Portal 传送门
# ================================================================
func _portal(r: Node2D):
	var ct = Node2D.new(); ct.name = "Portals"; r.add_child(ct)
	for p in _current_map_data.get("portals", []):
		var a = Area2D.new(); a.name = "p_" + str(p.get("id", 0))
		a.position = Vector2(p.get("x", 0), p.get("y", 0))
		var sh = CollisionShape2D.new()
		var rect = RectangleShape2D.new(); rect.size = Vector2(40, 80)
		sh.shape = rect; a.add_child(sh)
		var lb = Label.new(); lb.text = p.get("pn", "?")
		lb.position = Vector2(-20, -50)
		lb.add_theme_font_size_override("font_size", 10)
		lb.add_theme_color_override("font_color", Color.YELLOW)
		a.add_child(lb); a.set_meta("portal_data", p); ct.add_child(a)

# ================================================================
# Life 标记
# ================================================================
func _life(r: Node2D):
	var ct = Node2D.new(); ct.name = "Life"; r.add_child(ct)
	for it in _current_map_data.get("life", []):
		var m = Marker2D.new(); m.name = "lf_" + str(it.get("index", 0))
		m.position = Vector2(it.get("x", 0), it.get("y", 0))
		m.set_meta("life_data", it); ct.add_child(m)

# ================================================================
# 纹理 & 占位
# ================================================================
func _tex(imf: String) -> Texture2D:
	if _image_cache.has(imf): return _image_cache[imf]
	var fp = maps_root_dir + "/" + _fmt(_current_map_id) + "/" + imf
	if ResourceLoader.exists(fp):
		var t = ResourceLoader.load(fp, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if t: _image_cache[imf] = t; return t
	print("MapLoader: NOT FOUND: " + fp)
	return null

func _ph(sz: Vector2, cl: Color) -> ImageTexture:
	var im = Image.create(int(sz.x), int(sz.y), false, Image.FORMAT_RGBA8)
	im.fill(cl)
	var dk = cl.darkened(0.3)
	for x in int(sz.x): im.set_pixel(x, 0, dk); im.set_pixel(x, int(sz.y)-1, dk)
	for y in int(sz.y): im.set_pixel(0, y, dk); im.set_pixel(int(sz.x)-1, y, dk)
	return ImageTexture.create_from_image(im)
