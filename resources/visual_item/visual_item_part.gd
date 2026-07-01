class_name VisualItemPart extends AnimatedSprite2D
@export var part_name: String = "未命名部件"
@export var z: zmap.Layer = zmap.Layer.body
@export var source_item: VisualItem
#@export var 默认动画名称: String = "stand1"

## 当为 true 时，PaperDollAnimator 不会覆盖此节点的 frame/animation 属性，
## 改为由场景中的 AnimationPlayer 控制帧切换。
@export var 外部动画控制: bool = false

## 缓存的 JSON 配置数据，由 _ready() 加载
var _config_data: Dictionary = {}
## 缓存配置文件路径，用于报错信息
var _config_path: String = ""
## FrameLink 解析缓存：{config_id: Dictionary(parsed json)}，避免每帧重复加载
static var _framelink_cache: Dictionary = {}

# ---- 骨骼绑定 ----

## 父骨骼引用（bone_map 中第一个骨骼），用于监听位置变化
var _parent_bone: CharacterBone = null
## 父骨骼的偏移量（bone_map[0].offset），用于重新计算自身位置
var _parent_bone_offset: Vector2 = Vector2.ZERO


func _on_parent_bone_position_changed(new_pos: Vector2) -> void:
	"""当父骨骼位置变化时，同步更新自身位置"""
	self.position = new_pos - _parent_bone_offset - _get_visual_pos()


func _bind_to_bone(bone: CharacterBone, bone_offset: Vector2) -> void:
	"""绑定到指定的 CharacterBone，当骨骼移动时自动同步位置"""
	# 断开旧绑定
	if _parent_bone and _parent_bone != bone:
		if _parent_bone.bone_position_changed.is_connected(_on_parent_bone_position_changed):
			_parent_bone.bone_position_changed.disconnect(_on_parent_bone_position_changed)

	_parent_bone = bone
	_parent_bone_offset = bone_offset

	if _parent_bone:
		if not _parent_bone.bone_position_changed.is_connected(_on_parent_bone_position_changed):
			_parent_bone.bone_position_changed.connect(_on_parent_bone_position_changed)


func _ready() -> void:
	if source_item == null:
		push_warning("VisualItemPart '%s' 未指定 source_item" % part_name)
		return

	_config_path = source_item.get_anim_config_path()
	if _config_path.is_empty():
		push_warning("VisualItemPart '%s' anim config 路径为空" % part_name)
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

	# 外部动画控制时，用 frame_changed 信号驱动 set_origin / set_bone
	# 替代 AnimationPlayer 的方法调用轨道，避免 loop 回第 0 帧时 call track 不触发的问题
	if 外部动画控制:
		if not frame_changed.is_connected(_on_frame_changed):
			frame_changed.connect(_on_frame_changed)
		if not animation_changed.is_connected(_on_animation_changed):
			animation_changed.connect(_on_animation_changed)

# ---- 动画属性设置（供 AnimationPlayer METHOD track 调用） ----

func apply_animation(anim_name: StringName) -> void:
	"""供 AnimationPlayer METHOD 轨道调用，设置当前动画名称"""
	animation = anim_name


# ---- 信号处理方法 ----

func _on_frame_changed() -> void:
	if animation.is_empty():
		return
	set_origin(animation, frame)
	set_bone(animation, frame)


func _on_animation_changed() -> void:
	# 动画切换时推迟到第 0 帧就绪后再刷新，确保 frame 已更新
	call_deferred(&"_on_frame_changed")


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

			elif stype.ends_with(".FrameLink") and sprite_cfg.get("name") == part_name:
				var resolved := _resolve_framelink_sprite(sprite_cfg)
				if not resolved.is_empty():
					var origin_x: float = resolved.get("origin_x", 0.0)
					var origin_y: float = resolved.get("origin_y", 0.0)
					self.offset = Vector2(-origin_x, -origin_y)
					return

		push_warning("VisualItemPart '%s': 在动画 '%s' 帧 %d 中未找到精灵 '%s'" % [part_name, anim_name, frame_index, part_name])
		return

	push_warning("VisualItemPart '%s': 未找到动画 '%s'" % [part_name, anim_name])


func set_bone(anim_name: String, frame_index: int) -> void:
	"""从配置的 bone map 计算骨骼位置，并设置此精灵的 position 和 offset。

	本帧跨部件去重规则：
	- 对于每个部件，默认父骨骼是 body（position = 0,0）
	- 遍历 bone_map：
	  1. 本帧任何部件未处理过该骨骼 → 创建 CharacterBone，通过 change_bone_position 设置位置
	  2. 本帧已有部件处理过该骨骼 + 本次是本部件 bone_map 首次遍历
	     → 设置 self.position = 骨骼.position - offset - visual_pos，绑定骨骼信号
	  3. 本帧已有部件处理过该骨骼 + 非首次遍历 → 忽略
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
			var sprite_data: Dictionary

			if stype.ends_with(".Sprite") and sprite_cfg.get("name") == part_name:
				sprite_data = sprite_cfg
			elif stype.ends_with(".FrameLink") and sprite_cfg.get("name") == part_name:
				sprite_data = _resolve_framelink_sprite(sprite_cfg)
			else:
				continue

			if sprite_data.is_empty():
				continue

			# ---- 找到匹配的 sprite 配置 ----

			# 设置纹理绘制锚点
			var origin_x: float = sprite_data.get("origin_x", 0.0)
			var origin_y: float = sprite_data.get("origin_y", 0.0)
			self.offset = Vector2(-origin_x, -origin_y)

			var bone_maps_raw = sprite_data.get("map", [])
			var bone_maps: Array
			if bone_maps_raw is Dictionary:
				bone_maps = [bone_maps_raw]
			else:
				bone_maps = bone_maps_raw as Array
			if bone_maps.is_empty():
				self.position = Vector2.ZERO
				_bind_to_bone(null, Vector2.ZERO)
				return

			var body_bone := _find_body_bone()
			if body_bone == null:
				self.position = Vector2.ZERO
				_bind_to_bone(null, Vector2.ZERO)
				return

			# ---- 每帧跨部件骨骼去重 ----
			var current_frame := Engine.get_process_frames()
			var track_meta: Dictionary = body_bone.get_meta(&"_bone_frame_track", {})
			if track_meta.get("_frame", -1) != current_frame:
				track_meta = {"_frame": current_frame}
				body_bone.set_meta(&"_bone_frame_track", track_meta)

			var is_body_part: bool = (part_name == "body")
			var first_bone_node: CharacterBone = null
			var first_bone_offset := Vector2.ZERO

			for i in bone_maps.size():
				var bone_map = bone_maps[i]
				var bone_name: String = bone_map.get("bone", "")
				if bone_name.is_empty():
					continue
				var off_x: float = bone_map.get("offset_x", 0.0)
				var off_y: float = bone_map.get("offset_y", 0.0)
				var bone_offset := Vector2(off_x, off_y)

				if i == 0:
					first_bone_offset = bone_offset

				var bone_node: Node2D

				if bone_name == body_bone.name:
					# body 是根骨骼（普通 Node2D），直接使用
					bone_node = body_bone
					# body_bone 的 position 始终由外部维护为 (0,0)，不在此修改
				else:
					var processed_bone: Node2D = track_meta.get(bone_name)
					if processed_bone == null:
						# 规则 1：本帧未处理过 → 查找已有骨骼，否则创建 CharacterBone
						bone_node = _find_bone_recursive(body_bone, bone_name)
						if bone_node == null:
							bone_node = CharacterBone.new()
							bone_node.name = bone_name
							body_bone.add_child(bone_node)
						if bone_node is CharacterBone:
							bone_node.change_bone_position(bone_offset)
						else:
							bone_node.position = bone_offset
						bone_node.set_meta(&"_external_control", true)
						track_meta[bone_name] = bone_node
					else:
						# 已处理过
						if i != 0:
							continue  # 规则 3：非首次遍历 → 忽略
						bone_node = processed_bone

				if i == 0:
					# 首个骨骼 → 计算自身位置
					if is_body_part:
						# body 是根视觉，位置恒为 body_bone.position - visual_pos（body_bone 始终 0,0）
						self.position = body_bone.position - _get_visual_pos()
					else:
						self.position = bone_node.position - bone_offset - _get_visual_pos()
						if bone_node is CharacterBone:
							first_bone_node = bone_node

			# 绑定到首个骨骼（body 部件不绑定父骨骼，offset 用 (0,0)）
			_bind_to_bone(first_bone_node, first_bone_offset if first_bone_node else Vector2.ZERO)
			return

	push_warning("VisualItemPart '%s': 在动画 '%s' 帧 %d 中未找到精灵 '%s' 的骨骼映射" % [part_name, anim_name, frame_index, part_name])


# ---- FrameLink 解析 ----

func _resolve_framelink_sprite(link_cfg: Dictionary) -> Dictionary:
	"""解析 FrameLink 引用，返回目标帧中匹配本部件的 Sprite 配置。

	FrameLink 结构：{ name:"weapon", id:"01302000", animName:"stand1", frameIndex:0, spriteName:"weapon" }
	返回目标 Sprite 的完整配置字典（含 origin_x/origin_y, map 等），找不到返回 {}。
	"""
	var link_id: String = link_cfg.get("id", "")
	if link_id.is_empty():
		return {}

	# 缓存命中的目标配置（每个 id 只读一次文件）
	if not _framelink_cache.has(link_id):
		# 从 _config_path 同目录构造目标文件路径
		var base_dir := _config_path.get_base_dir()
		var target_path := base_dir.path_join(link_id + ".json")
		var file := FileAccess.open(target_path, FileAccess.READ)
		if file == null:
			push_warning("VisualItemPart '%s': FrameLink 无法打开目标配置 %s" % [part_name, target_path])
			_framelink_cache[link_id] = null  # 标记为已尝试但失败
			return {}
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if data == null:
			push_warning("VisualItemPart '%s': FrameLink 目标配置 JSON 解析失败 %s" % [part_name, target_path])
			_framelink_cache[link_id] = null
			return {}
		_framelink_cache[link_id] = data

	var target_config: Dictionary = _framelink_cache[link_id]
	if target_config == null or target_config.is_empty():
		return {}

	# 查找目标动画
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)
	var link_sprite: String = link_cfg.get("spriteName", part_name)

	var target_anim_cfg: Dictionary = {}
	for anim_cfg in target_config.get("animCfg", []):
		if anim_cfg.get("name") == link_anim:
			target_anim_cfg = anim_cfg
			break
	if target_anim_cfg.is_empty():
		return {}

	# 查找目标帧
	var target_frames: Array = target_anim_cfg.get("frames", [])
	if link_frame >= target_frames.size():
		return {}

	# 在目标帧中查找 spriteName 匹配的 Sprite
	var target_frame: Dictionary = target_frames[link_frame]
	for sprite_cfg in target_frame.get("spritecfg", []):
		var stype: String = sprite_cfg.get("$type", "")
		if stype.ends_with(".Sprite") and sprite_cfg.get("name", "") == link_sprite:
			return sprite_cfg

	return {}


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


func _get_visual_pos() -> Vector2:
	var p := get_parent()
	return p.position if p is Node2D else Vector2.ZERO


func _find_bone_recursive(parent: Node2D, bone_name: String) -> Node2D:
	for child in parent.get_children():
		if child.name == bone_name:
			return child as Node2D
		if child is Node2D:
			var found := _find_bone_recursive(child as Node2D, bone_name)
			if found:
				return found
	return null
