class_name VisualItemPart extends AnimatedSprite2D
@export var part_name: String = "未命名部件"
@export var z: zmap.Layer = zmap.Layer.body
@export var source_item: VisualItem

## 当为 true 时，PaperDollAnimator 不会覆盖此节点的 frame/animation 属性，
## 改为由场景中的 AnimationPlayer 控制帧切换。
@export var 外部动画控制: bool = false

## 缓存的 JSON 配置数据，由 _ready() 加载
var _config_data: Dictionary = {}
## 缓存配置文件路径，用于报错信息
var _config_path: String = ""


func _ready() -> void:
	if source_item == null:
		push_warning("VisualItemPart '%s' 未指定 source_item" % part_name)
		return

	_config_path = source_item.动画帧配置文件
	if _config_path.is_empty():
		push_warning("VisualItemPart '%s' 动画帧配置文件路径为空" % part_name)
		return

	# 加载 JSON 配置
	var file := FileAccess.open(_config_path, FileAccess.READ)
	if file == null:
		push_error("VisualItemPart '%s': 无法打开配置文件 %s" % [part_name, _config_path])
		return
	_config_data = JSON.parse_string(file.get_as_text())
	file.close()

	if _config_data == null:
		push_error("VisualItemPart '%s': 配置文件 JSON 解析失败 %s" % [part_name, _config_path])


func set_origin(anim_name: String, frame_index: int) -> void:
	if _config_data.is_empty():
		push_error("VisualItemPart '%s': 配置数据未加载 (%s)" % [part_name, _config_path])
		return

	# 查找匹配的动画配置
	for anim_cfg in _config_data.get("animCfg", []):
		if anim_cfg.get("name") != anim_name:
			continue

		var frames: Array = anim_cfg.get("frames", [])
		if frame_index >= frames.size():
			push_warning("VisualItemPart '%s': frame_index %d 超出范围（动画 '%s' 共 %d 帧）" % [part_name, frame_index, anim_name, frames.size()])
			return

		var frame_data: Dictionary = frames[frame_index]

		for sprite_cfg in frame_data.get("spritecfg", []):
			var stype: String = sprite_cfg.get("$type", "")

			if stype.ends_with(".Sprite"):
				var sname: String = sprite_cfg.get("name", "")
				if sname == part_name:
					var origin_x: float = sprite_cfg.get("origin_x", 0.0)
					var origin_y: float = sprite_cfg.get("origin_y", 0.0)
					self.offset = Vector2(-origin_x, -origin_y)
					return

			elif stype.ends_with(".FrameLink"):
				# FrameLink 跨配置引用需由 Builder/Animator 解析，此处略过
				pass

		push_warning("VisualItemPart '%s': 在动画 '%s' 帧 %d 中未找到精灵 '%s'" % [part_name, anim_name, frame_index, part_name])
		return

	push_warning("VisualItemPart '%s': 未找到动画 '%s'" % [part_name, anim_name])


func set_bone(anim_name: String, frame_index: int) -> void:
	"""从配置的 bone map 直接计算骨骼位置，创建/更新骨骼链，并设置此精灵的 position 和 offset。

	骨骼由本方法完全管理（从 offset 直接计算），不依赖 Animator 的骨骼系统。
	Animator 的 _process_skeleton_maps 遇到外部控制的骨骼时只读不写，避免冲突。

	计算逻辑与 _process_skeleton_maps 一致：
	- body 作为链起点（sprite_pos_root = Vector2.ZERO）
	- bone[i].position = sprite_pos_root + offset[i]
	- sprite.position = last_bone.position - last_offset - visual_pos
	"""
	if _config_data.is_empty():
		push_error("VisualItemPart '%s': 配置数据未加载 (%s)" % [part_name, _config_path])
		return

	# 查找匹配的动画配置
	for anim_cfg in _config_data.get("animCfg", []):
		if anim_cfg.get("name") != anim_name:
			continue

		var frames: Array = anim_cfg.get("frames", [])
		if frame_index >= frames.size():
			return

		var frame_data: Dictionary = frames[frame_index]

		for sprite_cfg in frame_data.get("spritecfg", []):
			var stype: String = sprite_cfg.get("$type", "")
			if not stype.ends_with(".Sprite"):
				continue
			if sprite_cfg.get("name", "") != part_name:
				continue

			# ---- 找到匹配的 sprite 配置 ----

			# 设置纹理绘制锚点
			var origin_x: float = sprite_cfg.get("origin_x", 0.0)
			var origin_y: float = sprite_cfg.get("origin_y", 0.0)
			self.offset = Vector2(-origin_x, -origin_y)

			var bone_maps: Array = sprite_cfg.get("map", [])
			if bone_maps.is_empty():
				self.position = Vector2.ZERO
				return

			var body_bone := _find_body_bone()
			if body_bone == null:
				self.position = Vector2.ZERO
				return

			# ---- 从 scratch 创建/更新骨骼链 ----
			# body 是骨骼链的根，sprite_pos_root 恒为 ZERO（链中无前置骨骼）
			var sprite_pos_root := Vector2.ZERO
			var last_bone: Node2D = null
			var last_offset := Vector2.ZERO

			for bone_map in bone_maps:
				var bone_name: String = bone_map.get("bone", "")
				var off_x: float = bone_map.get("offset_x", 0.0)
				var off_y: float = bone_map.get("offset_y", 0.0)
				var bone_offset := Vector2(off_x, off_y)

				# 查找或创建骨骼（在 body 子树下）
				var bone_node := _find_or_create_bone(bone_name, body_bone)
				if bone_node == null:
					continue

				# 设置骨骼位置（从 offset 直接计算，不依赖任何外部状态）
				bone_node.position = sprite_pos_root + bone_offset

				# 标记为外部动画控制，Animator 遇到此骨骼时只读不写
				bone_node.set_meta(&"_external_control", true)

				last_bone = bone_node
				last_offset = bone_offset

			# ---- 计算精灵位置（换算到 视觉 容器局部坐标） ----
			var parent_node := get_parent()
			var visual_pos: Vector2 = parent_node.position if parent_node is Node2D else Vector2.ZERO
			var sprite_pos: Vector2
			if last_bone == null:
				sprite_pos = -visual_pos
			else:
				sprite_pos = last_bone.position - last_offset - visual_pos

			self.position = sprite_pos
			return

	push_warning("VisualItemPart '%s': 在动画 '%s' 帧 %d 中未找到精灵 '%s' 的骨骼映射" % [part_name, anim_name, frame_index, part_name])


# ---- 骨骼查找辅助方法 ----

func _find_body_bone() -> Node2D:
	"""在场景树中定位 body 骨骼根节点

	VisualItemPart 位于 视觉 容器下，body 是 player_root 的直接子节点：
	PlayerRoot
	├── 视觉
	│   └── VisualItemPart（this）
	└── body
	"""
	var visual := get_parent()
	if visual == null:
		return null
	var player_root := visual.get_parent()
	if player_root == null:
		return null
	return player_root.get_node_or_null("body") as Node2D


func _find_or_create_bone(bone_name: String, body_bone: Node2D) -> Node2D:
	"""在 body 子树中查找骨骼节点，找不到则创建并挂到 body 下"""
	var bone_node := _find_bone_recursive(body_bone, bone_name)
	if bone_node == null:
		bone_node = Node2D.new()
		bone_node.name = bone_name
		body_bone.add_child(bone_node)
	return bone_node


func _find_bone_recursive(parent: Node2D, bone_name: String) -> Node2D:
	for child in parent.get_children():
		if child.name == bone_name:
			return child as Node2D
		if child is Node2D:
			var found := _find_bone_recursive(child as Node2D, bone_name)
			if found:
				return found
	return null
