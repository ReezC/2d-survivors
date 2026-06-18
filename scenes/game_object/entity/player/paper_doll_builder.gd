class_name PaperDollBuilder extends RefCounted
## 纸娃娃构建器 —— 根据 JSON 配置动态创建视觉节点和骨骼树
##
## 使用方式：
##   var builder = PaperDollBuilder.new()
##   builder.build(character_body_node, zmap_resource)
##   builder.add_part_config("res://config/_animconfig_animconfig/00002000.json")
##   builder.add_part_config("res://config/_animconfig_animconfig/00012000.json")

const VISUAL_ITEM_PART_SCRIPT := preload("res://scenes/game_object/visual_item/visual_item_part.gd")

# ---- 内部状态 ----
var _character: Node2D           # character_body 节点
var _visual_parent: Node2D       # "视觉" 容器节点
var _body_bone: Node2D           # "body" 骨骼根节点
var _zmap: zmap

## 已加载的部件配置 {animconfig_id: Dictionary(parsed json)}
var _part_configs: Dictionary = {}

## 精灵节点映射 {sprite_name: VisualItemPart}
var _sprite_nodes: Dictionary = {}

## 骨骼节点映射 {bone_name: Node2D}
var _bone_nodes: Dictionary = {}


func build(character: Node2D) -> void:
	_character = character
	# zmap 引用从 视觉 节点获取，不在 Builder 层持有
	_acquire_zmap_from_visual()

	# 1. 确保 "视觉" 容器存在
	_visual_parent = _character.get_node_or_null("视觉") as Node2D
	if _visual_parent == null:
		_visual_parent = Node2D.new()
		_visual_parent.name = "视觉"
		_character.add_child(_visual_parent)

	# 2. 创建 body 骨骼根节点
	_body_bone = _character.get_node_or_null("body") as Node2D
	if _body_bone == null:
		_body_bone = Node2D.new()
		_body_bone.name = "body"
		_character.add_child(_body_bone)
	_bone_nodes["body"] = _body_bone


func add_part_config(json_path: String) -> void:
	"""加载一个部件的 animconfig JSON 配置并构建其视觉节点"""
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("PaperDollBuilder: 无法打开配置文件 %s" % json_path)
		return
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null or not data.has("id"):
		push_error("PaperDollBuilder: 配置文件格式无效 %s" % json_path)
		return

	var config_id: String = data["id"]
	_part_configs[config_id] = data

	# 3. 收集所有帧中出现的 sprite 名称，为每个创建 VisualItemPart
	var sprite_names := _collect_sprite_names(data)
	for sname in sprite_names:
		if _sprite_nodes.has(sname):
			continue  # 同名 sprite 只创建一次（多个部件可能引用同一骨骼）

		var node_name: String = sname + "_" + data.get("name", "") + "_" + data.get("id", "") 
		var sprite_node := AnimatedSprite2D.new()
		sprite_node.name = node_name
		sprite_node.centered = false
		sprite_node.script = VISUAL_ITEM_PART_SCRIPT
		# 设置 VisualItemPart 属性
		sprite_node.part_name = sname
		sprite_node.z = _get_z_layer_from_data(data, sname)
		# 创建 VisualItem 数据资源
		var vi := VisualItem.new()
		vi.id = data["id"]
		vi.item_name = data.get("name", "")
		vi.动画帧配置文件 = json_path
		sprite_node.source_item = vi
		_visual_parent.add_child(sprite_node)
		_sprite_nodes[sname] = sprite_node

	# 4. 构建此部件的 SpriteFrames（收集所有动画的所有帧的纹理）
	_build_sprite_frames_for_config(data)

	# 5. 从第一帧的骨骼映射构建初始骨骼树
	_build_initial_skeleton(data)

	# 6. 通知 视觉 节点重新分配 z_index（新子节点已加入）
	_refresh_z_index()


func _acquire_zmap_from_visual() -> void:
	"""从 视觉 节点获取 zmap 引用（zmap 归 视觉.gd 管理）"""
	if _visual_parent and _visual_parent.has_method("get") and "zmap_file" in _visual_parent:
		_zmap = _visual_parent.zmap_file


func _refresh_z_index() -> void:
	"""触发 视觉 节点重新为所有子节点分配 z_index"""
	if _visual_parent and _visual_parent.has_method("_ready"):
		# 视觉.gd._ready 已经处理了 z_index 分配，
		# 但新子节点是在 _ready 之后动态添加的，所以手动触发一次刷新
		if _visual_parent.has_method("refresh_z_index"):
			_visual_parent.refresh_z_index()
		elif _visual_parent.has_method("get") and "zmap_file" in _visual_parent:
			var zmap_file: zmap = _visual_parent.zmap_file
			if zmap_file:
				var total_layers: int = zmap_file.get_layer_count()
				for child in _visual_parent.get_children():
					var layer: zmap.Layer
					if "z" in child:
						layer = child.z
					else:
						var idx: int = zmap_file.get_layer_index_by_name(child.name)
						if idx >= 0:
							layer = zmap_file.Layer.values()[idx]
						else:
							continue
					var layer_idx: int = zmap_file.get_layer_index(layer)
					child.z_index = total_layers - layer_idx


func _get_z_layer_from_data(data: Dictionary, sprite_name: String) -> zmap.Layer:
	"""从配置数据中查找 sprite 的 z 层级"""
	for anim_cfg in data.get("animCfg", []):
		for frame in anim_cfg.get("frames", []):
			for sprite_cfg in frame.get("spritecfg", []):
				if sprite_cfg.get("$type", "").ends_with(".Sprite") and sprite_cfg.get("name") == sprite_name:
					var z_name: String = sprite_cfg.get("z", "")
					if _zmap:
						var idx: int = _zmap.get_layer_index_by_name(z_name)
						if idx >= 0:
							return zmap.Layer.values()[idx]
					break
			if true: break
		if true: break
	return zmap.Layer.body


func _collect_sprite_names(data: Dictionary) -> Array[String]:
	"""收集配置中所有独特的 sprite name"""
	var names: Array[String] = []
	for anim_cfg in data.get("animCfg", []):
		for frame in anim_cfg.get("frames", []):
			for sprite_cfg in frame.get("spritecfg", []):
				var stype = sprite_cfg.get("$type", "")
				if stype.ends_with(".Sprite"):
					var sname: String = sprite_cfg.get("name", "")
					if sname not in names:
						names.append(sname)
	return names


func _build_sprite_frames_for_config(data: Dictionary) -> void:
	"""为此配置中每个 sprite 构建 SpriteFrames 资源"""
	for anim_cfg in data.get("animCfg", []):
		var anim_name: String = anim_cfg.get("name", "")
		var frames_array: Array = anim_cfg.get("frames", [])

		# 收集此动画中每个 sprite 的帧纹理
		var sprite_textures: Dictionary = {}  # {sprite_name: [texture, ...]}
		for frame in frames_array:
			for sprite_cfg in frame.get("spritecfg", []):
				var stype = sprite_cfg.get("$type", "")
				if stype.ends_with(".Sprite"):
					var sname: String = sprite_cfg.get("name", "")
					var tex_path: String = sprite_cfg.get("spriteDir", "")
					var tex := load(tex_path) as Texture2D
					if tex == null:
						push_warning("PaperDollBuilder: 无法加载纹理 %s" % tex_path)
						continue
					if not sprite_textures.has(sname):
						sprite_textures[sname] = []
					sprite_textures[sname].append(tex)

		# 为每个 sprite 的 SpriteFrames 添加此动画
		for sname in sprite_textures:
			var sprite_node := _sprite_nodes.get(sname) as VisualItemPart
			if sprite_node == null:
				continue

			var sf := sprite_node.sprite_frames
			if sf == null:
				sf = SpriteFrames.new()

			# 检查动画是否已存在
			if sf.has_animation(anim_name):
				sf.remove_animation(anim_name)

			sf.add_animation(anim_name)
			sf.set_animation_loop(anim_name, true)
			for tex in sprite_textures[sname]:
				sf.add_frame(anim_name, tex, 1.0)

			sprite_node.sprite_frames = sf


func _build_initial_skeleton(data: Dictionary) -> void:
	"""根据第一帧的骨骼映射创建初始骨骼树，并设置精灵 position"""
	var anim_cfgs: Array = data.get("animCfg", [])
	if anim_cfgs.is_empty():
		return
	var frames: Array = anim_cfgs[0].get("frames", [])
	if frames.is_empty():
		return

	for sprite_cfg in frames[0].get("spritecfg", []):
		var stype = sprite_cfg.get("$type", "")
		if not stype.ends_with(".Sprite"):
			continue

		# 计算精灵 position（基于当前已创建的骨骼）
		var sprite_pos := _compute_sprite_position(sprite_cfg)

		# 创建不存在的骨骼：骨骼 position = 精灵 position + 该骨骼的 offset
		for bone_map in sprite_cfg.get("map", []):
			var bone_name: String = bone_map.get("bone", "")
			var off_x: float = bone_map.get("offset_x", 0.0)
			var off_y: float = bone_map.get("offset_y", 0.0)
			var offset := Vector2(off_x, off_y)

			var bone_node := _bone_nodes.get(bone_name) as Node2D

			if bone_node == null:
				# 骨骼不存在 → 在 body 下创建
				bone_node = Node2D.new()
				bone_node.name = bone_name
				_body_bone.add_child(bone_node)
				bone_node.position = sprite_pos + offset
				_bone_nodes[bone_name] = bone_node

	# 初始帧就应用一帧（设置 offset 和动画）
	_apply_frame_visuals(data, 0, 0)


## 获取所有已注册的部件配置
func get_all_configs() -> Dictionary:
	return _part_configs


## 获取精灵节点映射
func get_sprite_nodes() -> Dictionary:
	return _sprite_nodes


## 获取骨骼节点映射
func get_bone_nodes() -> Dictionary:
	return _bone_nodes


## 获取 body 骨骼根节点
func get_body_bone() -> Node2D:
	return _body_bone


func _compute_sprite_position(sprite_cfg: Dictionary) -> Vector2:
	"""计算精灵节点在 视觉 容器下的 position
	
	规则：精灵 position = 最后一个已存在骨骼的全局位置 - 该骨骼在当前 sprite map 中的 offset
	如果 map 中所有骨骼都不存在 → position = (0,0)（绑定到 body）
	"""
	var bone_maps: Array = sprite_cfg.get("map", [])
	if bone_maps.is_empty():
		return Vector2.ZERO
	
	# 找最后一个已存在的骨骼及其 offset
	var last_exist_bone: Node2D = null
	var last_exist_offset := Vector2.ZERO
	
	for bone_map in bone_maps:
		var bone_name: String = bone_map.get("bone", "")
		var off_x: float = bone_map.get("offset_x", 0.0)
		var off_y: float = bone_map.get("offset_y", 0.0)
		var offset := Vector2(off_x, off_y)
		
		var bone_node := _bone_nodes.get(bone_name) as Node2D
		if bone_node != null:
			last_exist_bone = bone_node
			last_exist_offset = offset
	
	var result: Vector2
	if last_exist_bone == null:
		# 全部骨骼都不存在 → 绑定到 body
		result = Vector2.ZERO
	else:
		# 最后一个已存在骨骼的全局位置 - 该骨骼在当前 sprite map 中的 offset
		result = last_exist_bone.position - last_exist_offset
	
	# 换算到 视觉 容器的局部坐标
	if _visual_parent:
		return result - _visual_parent.position
	return result


func _find_bone_in_tree(bone_name: String) -> Node2D:
	"""在 body 骨骼树中递归查找骨骼节点"""
	if _body_bone == null:
		return null
	return _find_bone_recursive(_body_bone, bone_name)


func _find_bone_recursive(parent: Node2D, bone_name: String) -> Node2D:
	for child in parent.get_children():
		if child.name == bone_name:
			return child as Node2D
		if child is Node2D:
			var found := _find_bone_recursive(child as Node2D, bone_name)
			if found:
				return found
	return null


## 应用指定帧的视觉效果（offset + 动画切换）
func _apply_frame_visuals(data: Dictionary, anim_index: int, frame_index: int) -> void:
	var anim_cfgs: Array = data.get("animCfg", [])
	if anim_index >= anim_cfgs.size():
		return
	var anim_cfg: Dictionary = anim_cfgs[anim_index]
	var frames: Array = anim_cfg.get("frames", [])
	if frame_index >= frames.size():
		return
	var frame: Dictionary = frames[frame_index]
	var anim_name: String = anim_cfg.get("name", "")

	for sprite_cfg in frame.get("spritecfg", []):
		var stype = sprite_cfg.get("$type", "")
		if stype.ends_with(".Sprite"):
			var sname: String = sprite_cfg.get("name", "")
			var origin_x: float = sprite_cfg.get("origin_x", 0.0)
			var origin_y: float = sprite_cfg.get("origin_y", 0.0)

			var sprite_node := _sprite_nodes.get(sname) as VisualItemPart
			if sprite_node == null:
				continue

			# offset = -(origin_x, origin_y)：纹理绘制锚点
			sprite_node.offset = Vector2(-origin_x, -origin_y)

			# position = 骨骼链末端的全局位置
			sprite_node.position = _compute_sprite_position(sprite_cfg)

			# 切换动画
			if sprite_node.sprite_frames and sprite_node.sprite_frames.has_animation(anim_name):
				sprite_node.animation = anim_name
			sprite_node.frame = frame_index

		elif stype.ends_with(".FrameLink"):
			# FrameLink 在运行时由 animator 处理
			pass


## 获取某个配置的动画帧数
func get_animation_frame_count(config_data: Dictionary, anim_name: String) -> int:
	for anim_cfg in config_data.get("animCfg", []):
		if anim_cfg.get("name") == anim_name:
			return anim_cfg.get("frames", []).size()
	return 0
