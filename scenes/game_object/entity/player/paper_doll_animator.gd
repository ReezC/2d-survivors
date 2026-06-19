class_name PaperDollAnimator extends Node
## 纸娃娃动画控制器 —— 驱动帧切换和骨骼位置更新
##
## 挂载在 character_body 节点下，由 player.gd 驱动

const VisualItemPart := preload("res://scenes/game_object/visual_item/visual_item_part.gd")

# ---- 运行时状态 ----
var _builder: PaperDollBuilder
var _current_anim: String = ""
var _current_frame: int = 0
var _frame_timer_ms: float = 0.0
var _face_direction: int = -1  # 默认朝左（精灵默认方向）, 1=右（翻转）
var _pingpong: bool = false        # 是否乒乓循环（待机动画）
var _pingpong_forward: bool = true # 乒乓方向：true=正向, false=反向

# 动画状态映射
const ANIM_MAP := {
	"stand1": "stand1",
	"walk1": "walk1",
	"front": "front",
}

# 角色状态到动画名的映射
const STATE_ANIM_MAP := {
	0: "stand1",  # 待机
	1: "walk1",   # 移动
}


func _ready() -> void:
	_builder = PaperDollBuilder.new()


func add_part_config(json_path: String) -> void:
	"""添加一个部件配置"""
	_builder.add_part_config(json_path)


func build_finish() -> void:
	"""完成构建后调用，确保一切就绪"""
	pass


func set_animation_by_state(state: int) -> void:
	"""根据角色状态设置动画"""
	var anim_name: String = STATE_ANIM_MAP.get(state, "stand1")
	if anim_name != _current_anim:
		_change_animation(anim_name)


func set_face_direction(direction: int) -> void:
	"""设置角色朝向并翻转所有精灵：1=右, -1=左"""
	if direction == _face_direction:
		return
	_face_direction = direction
	_apply_flip()


func _apply_flip() -> void:
	"""翻转整个视觉容器
	精灵默认朝左(_face_direction = -1)，此时 scale.x = 1（不翻转）
	向右走(_face_direction = 1)时 scale.x = -1（镜像翻转）
	"""
	if _builder._visual_parent:
		_builder._visual_parent.scale.x = float(-_face_direction)


func _change_animation(anim_name: String) -> void:
	# print("[Animator] 切换动画: %s → %s" % [_current_anim, anim_name])
	_current_anim = anim_name
	_current_frame = 0
	_frame_timer_ms = 0.0
	# 待机动画（stand1）使用乒乓循环，其他使用单向循环
	_pingpong = anim_name.begins_with("stand")
	_pingpong_forward = true
	# 立即应用第 0 帧，避免等待 delay 才显示
	_update_skeleton_positions()
	_apply_current_frame()
	# print("[Animator] 切换动画完成, sprite_nodes: %d, bone_nodes: %d" % [_builder.get_sprite_nodes().size(), _builder.get_bone_nodes().size()])


func _process(delta: float) -> void:
	if _current_anim.is_empty():
		return
	if _builder == null:
		return

	# 1. 找到主导帧的 delay（取所有部件当前动画的最小 delay，排除负数）
	var lead_delay := _get_lead_delay()

	# 2. 检查是否有任何部件当前帧 delay < 0（每帧强制刷新）
	var has_force_refresh := _has_force_refresh_frame()

	# 3. 帧计时器推进（delay <= 0 时不依赖计时器，每帧都触发）
	if lead_delay > 0:
		_frame_timer_ms += delta * 1000.0
		if _frame_timer_ms >= lead_delay:
			_frame_timer_ms = fmod(_frame_timer_ms, lead_delay)
			_advance_frame()
			has_force_refresh = true  # 帧切换时必然需要渲染

	# 4. 需要渲染时：更新骨骼 + 应用帧
	if has_force_refresh:
		_update_skeleton_positions()
		_apply_current_frame()


func _advance_frame() -> void:
	"""推进一帧，根据乒乓/单向模式处理帧索引"""
	var max_frames := _get_max_frame_count()
	if max_frames <= 0:
		return

	if _pingpong:
		if _pingpong_forward:
			_current_frame += 1
			if _current_frame >= max_frames:
				_current_frame = max_frames - 2
				_pingpong_forward = false
		else:
			_current_frame -= 1
			if _current_frame < 0:
				_current_frame = 1
				_pingpong_forward = true
	else:
		_current_frame = (_current_frame + 1) % max_frames


func _get_lead_delay() -> int:
	"""获取主导延迟（取所有部件当前动画帧的最小 delay，排除 <=0 的值）"""
	var min_delay := 999999
	for config_data in _builder.get_all_configs().values():
		var anim_data := _find_anim_data(config_data, _current_anim)
		if anim_data == null:
			continue
		var frames: Array = anim_data.get("frames", [])
		if _current_frame < frames.size():
			var delay: int = frames[_current_frame].get("delay", 500)
			if delay > 0 and delay < min_delay:
				min_delay = delay
	return min_delay if min_delay < 999999 else 500


func _has_force_refresh_frame() -> bool:
	"""检查是否有任何部件当前帧的 delay < 0（需要每帧强制刷新）"""
	for config_data in _builder.get_all_configs().values():
		var anim_data := _find_anim_data(config_data, _current_anim)
		if anim_data == null:
			continue
		var frames: Array = anim_data.get("frames", [])
		if _current_frame < frames.size():
			var delay: int = frames[_current_frame].get("delay", 500)
			if delay < 0:
				return true
	return false


func _get_max_frame_count() -> int:
	"""获取所有部件中当前动画的最大帧数"""
	var max_count := 0
	for config_data in _builder.get_all_configs().values():
		var anim_data := _find_anim_data(config_data, _current_anim)
		if anim_data != null:
			var count: int = anim_data.get("frames", []).size()
			if count > max_count:
				max_count = count
	return max_count


func _find_anim_data(config_data: Dictionary, anim_name: String) -> Dictionary:
	"""查找动画配置，找不到时 fallback 到 "default" 动画"""
	for anim_cfg in config_data.get("animCfg", []):
		if anim_cfg.get("name") == anim_name:
			return anim_cfg
	# fallback: 查找名为 "default" 的动画
	if anim_name != "default":
		for anim_cfg in config_data.get("animCfg", []):
			if anim_cfg.get("name") == "default":
				return anim_cfg
	return {}


func _apply_current_frame() -> void:
	"""将当前帧应用到所有部件"""
	for config_data in _builder.get_all_configs().values():
		_apply_frame_for_config(config_data)


func _apply_frame_for_config(config_data: Dictionary) -> void:
	var anim_data := _find_anim_data(config_data, _current_anim)
	if anim_data == null:
		# print("[Animator] 配置 id=%s 找不到动画 '%s'" % [config_data.get("id", "?"), _current_anim])
		return

	var frames: Array = anim_data.get("frames", [])
	if frames.is_empty():
		return

	# 帧索引可能超出此配置的帧数，做 wrapping
	var frame_idx: int = _current_frame % frames.size()
	var frame: Dictionary = frames[frame_idx]

	var anim_name: String = anim_data.get("name", "")
	var config_id: String = config_data.get("id", "?")

	for sprite_cfg in frame.get("spritecfg", []):
		var stype = sprite_cfg.get("$type", "")
		if stype.ends_with(".Sprite"):
			_apply_sprite(sprite_cfg, anim_name, frame_idx)
		elif stype.ends_with(".FrameLink"):
			_apply_framelink(sprite_cfg, anim_name, frame_idx)


func _apply_sprite(sprite_cfg: Dictionary, anim_name: String, frame_idx: int) -> void:
	var sname: String = sprite_cfg.get("name", "")
	var origin_x: float = sprite_cfg.get("origin_x", 0.0)
	var origin_y: float = sprite_cfg.get("origin_y", 0.0)

	var sprite_node := _builder.get_sprite_nodes().get(sname) as VisualItemPart
	if sprite_node == null:
		# print("[Animator] _apply_sprite: sprite '%s' 不在 _sprite_nodes 中!" % sname)
		return

	# offset = -(origin_x, origin_y)：纹理绘制锚点
	sprite_node.offset = Vector2(-origin_x, -origin_y)

	# position = 骨骼链末端的全局位置（从 body 累加所有 bone offset）
	sprite_node.position = _compute_sprite_position(sprite_cfg)

	# 切换动画和帧
	if sprite_node.sprite_frames and sprite_node.sprite_frames.has_animation(anim_name):
		sprite_node.animation = anim_name
	else:
		if sprite_node.sprite_frames == null:
			pass  # print("[Animator] _apply_sprite: sprite '%s' 没有 sprite_frames!" % sname)
		else:
			var avail := []
			for a in sprite_node.sprite_frames.get_animation_names():
				avail.append(a)
			# print("[Animator] _apply_sprite: sprite '%s' 没有动画 '%s', 可用: %s" % [sname, anim_name, str(avail)])
	sprite_node.frame = frame_idx


func _compute_sprite_position(sprite_cfg: Dictionary) -> Vector2:
	"""计算精灵节点在 视觉 容器下的 position
	
	规则：精灵 position = 最后一个已存在骨骼的全局位置 - 该骨骼在当前 sprite map 中的 offset
	如果 map 中所有骨骼都不存在 → position = (0,0)（绑定到 body）
	"""
	var bone_maps: Array = sprite_cfg.get("map", [])
	if bone_maps.is_empty():
		return Vector2.ZERO
	
	var bone_nodes := _builder.get_bone_nodes()
	var last_exist_bone: Node2D = null
	var last_exist_offset := Vector2.ZERO
	
	for bone_map in bone_maps:
		var bone_name: String = bone_map.get("bone", "")
		var off_x: float = bone_map.get("offset_x", 0.0)
		var off_y: float = bone_map.get("offset_y", 0.0)
		var offset := Vector2(off_x, off_y)
		
		var bone_node := bone_nodes.get(bone_name) as Node2D
		if bone_node != null:
			last_exist_bone = bone_node
			last_exist_offset = offset
	
	var result: Vector2
	if last_exist_bone == null:
		result = Vector2.ZERO
	else:
		result = last_exist_bone.position - last_exist_offset
	
	var visual := _builder._visual_parent as Node2D
	if visual:
		return result - visual.position
	return result


func _apply_framelink(link_cfg: Dictionary, _current_anim_name: String, _frame_idx: int) -> void:
	"""处理 FrameLink：引用另一个配置的帧"""
	var link_id: String = link_cfg.get("id", "")
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)
	var link_sprite: String = link_cfg.get("spriteName", "")

	var target_config: Dictionary = _builder.get_all_configs().get(link_id)
	if target_config == null:
		push_warning("PaperDollAnimator: FrameLink 引用不存在的配置 id=%s" % link_id)
		return

	var target_anim := _find_anim_data(target_config, link_anim)
	if target_anim == null:
		push_warning("PaperDollAnimator: FrameLink 引用不存在的动画 %s.%s" % [link_id, link_anim])
		return

	var target_frames: Array = target_anim.get("frames", [])
	if link_frame >= target_frames.size():
		return

	var target_frame: Dictionary = target_frames[link_frame]
	for sprite_cfg in target_frame.get("spritecfg", []):
		if sprite_cfg.get("$type", "").ends_with(".Sprite") and sprite_cfg.get("name") == link_sprite:
			_apply_sprite(sprite_cfg, link_anim, link_frame)
			return


func _update_skeleton_positions() -> void:
	"""更新骨骼位置：重置本帧骨骼运算状态，重新遍历当前帧所有 Sprite 更新位置"""
	var body_bone := _builder.get_body_bone()
	if body_bone == null:
		return

	# 重置骨骼运算字典（本帧"已计入"的骨骼），但不删除节点树上的骨骼节点
	_reset_bone_nodes()

	# 收集当前帧所有 Sprite 的骨骼映射（包括 FrameLink 引用的目标 Sprite）
	for config_data in _builder.get_all_configs().values():
		var anim_data := _find_anim_data(config_data, _current_anim)
		if anim_data == null:
			continue

		var frames: Array = anim_data.get("frames", [])
		if frames.is_empty():
			continue

		var frame_idx: int = _current_frame % frames.size()
		var frame: Dictionary = frames[frame_idx]

		for sprite_cfg in frame.get("spritecfg", []):
			var stype = sprite_cfg.get("$type", "")
			if stype.ends_with(".Sprite"):
				_process_skeleton_maps(sprite_cfg)
			elif stype.ends_with(".FrameLink"):
				_process_framelink_skeleton(sprite_cfg)


func _process_framelink_skeleton(link_cfg: Dictionary) -> void:
	"""解析 FrameLink 的目标帧，提取其中的 Sprite 并处理骨骼映射"""
	var link_id: String = link_cfg.get("id", "")
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)

	var target_config: Dictionary = _builder.get_all_configs().get(link_id)
	if target_config == null:
		return

	var target_anim := _find_anim_data(target_config, link_anim)
	if target_anim == null:
		return

	var target_frames: Array = target_anim.get("frames", [])
	if link_frame >= target_frames.size():
		return

	var target_frame: Dictionary = target_frames[link_frame]
	for sprite_cfg in target_frame.get("spritecfg", []):
		if sprite_cfg.get("$type", "").ends_with(".Sprite"):
			_process_skeleton_maps(sprite_cfg)

func _reset_bone_nodes() -> void:
	"""重置骨骼运算字典（清空本帧"已计入"的骨骼），但不删除节点树上的骨骼节点"""
	var bone_nodes := _builder.get_bone_nodes()
	bone_nodes.clear()
	bone_nodes["body"] = _builder.get_body_bone()


func _process_skeleton_maps(sprite_cfg: Dictionary) -> void:
	"""更新骨骼位置：已存在的更新 position，不存在的在节点树上创建并记录"""
	var body_bone := _builder.get_body_bone()
	var bone_nodes := _builder.get_bone_nodes()
	
	# 计算精灵 position（基于当前 bone_nodes 字典中本帧已处理的骨骼链）
	var sprite_pos := _compute_sprite_position(sprite_cfg)

	for bone_map in sprite_cfg.get("map", []):
		var bone_name: String = bone_map.get("bone", "")
		var offset_x: float = bone_map.get("offset_x", 0.0)
		var offset_y: float = bone_map.get("offset_y", 0.0)
		var offset := Vector2(offset_x, offset_y)
		var new_pos := sprite_pos + offset

		var bone_node := bone_nodes.get(bone_name) as Node2D

		if bone_node == null:
			# 骨骼不在本帧运算字典中 → 在节点树上查找或创建
			bone_node = _builder._find_bone_in_tree(bone_name)
			if bone_node == null:
				bone_node = Node2D.new()
				bone_node.name = bone_name
				body_bone.add_child(bone_node)
			bone_node.position = new_pos
			bone_nodes[bone_name] = bone_node
		else:
			# 骨骼已存在 → 只更新位置
			bone_node.position = new_pos
