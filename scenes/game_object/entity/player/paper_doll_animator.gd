class_name PaperDollAnimator extends Node
## 纸娃娃动画控制器 —— 驱动帧切换和骨骼位置更新
##
## 挂载在 character_body 节点下，由 player.gd 驱动

# ---- 运行时状态 ----
var _builder: PaperDollBuilder
var _current_anim: String = ""
var _current_frame: int = 0
var _frame_timer_ms: float = 0.0
var _face_direction: int = -1  # 默认朝左（精灵默认方向）, 1=右（翻转）
var _pingpong: bool = false        # 是否乒乓循环（待机动画）
var _pingpong_forward: bool = true # 乒乓方向：true=正向, false=反向

# ---- 每帧缓存：避免 _process 中重复 _find_anim_data 遍历 ----
var _cached_anim_data: Dictionary = {}  # {config_id: anim_data_dict}

# ---- face blink 状态机 ----
var _blink_timer_ms: float = 0.0       # 距离下次眨眼的倒计时
var _blink_interval_ms: float = 3000.0 # 下次眨眼的随机间隔
var _blink_active: bool = false         # 是否正在播放 blink 动画
var _blink_frame: int = 0               # 当前 blink 帧
var _blink_frame_timer_ms: float = 0.0  # blink 帧内计时器
var _blink_saved_anim: String = ""      # blink 前保存的动画名，用于恢复
var _blink_saved_frame: int = 0         # blink 前保存的帧号，用于恢复
const BLINK_FRAME_DELAY_MS := 60        # 每帧 60ms
const BLINK_MIN_INTERVAL_MS := 2000.0   # 最小间隔 2 秒
const BLINK_MAX_INTERVAL_MS := 6000.0   # 最大间隔 6 秒

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
	"""完成构建后调用：一次性排序子节点 + 初始化 anim_data 缓存"""
	_builder.finish_children_sort()


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
	_current_anim = anim_name
	_current_frame = 0
	_frame_timer_ms = 0.0
	# 待机动画（stand1）使用乒乓循环，其他使用单向循环
	_pingpong = anim_name.begins_with("stand")
	_pingpong_forward = true
	# 预缓存所有配置的 anim_data，避免 _process 中重复 _find_anim_data 遍历
	_refresh_anim_data_cache()
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

	# 5. face blink 独立逻辑（与主循环并行，不干扰主帧推进）
	_update_blink(delta)


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
	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if anim_data.is_empty():
			continue
		var frames: Array = anim_data.get("frames", [])
		if _current_frame < frames.size():
			var delay: int = frames[_current_frame].get("delay", 500)
			if delay > 0 and delay < min_delay:
				min_delay = delay
	return min_delay if min_delay < 999999 else 500


func _has_force_refresh_frame() -> bool:
	"""检查是否有任何部件当前帧的 delay < 0（需要每帧强制刷新）"""
	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if anim_data.is_empty():
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
	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if not anim_data.is_empty():
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


func _refresh_anim_data_cache() -> void:
	"""动画切换时预计算所有 config 的 anim_data，避免 _process 中重复遍历"""
	_cached_anim_data.clear()
	for config_id in _builder.get_all_configs():
		var config_data: Dictionary = _builder.get_all_configs()[config_id]
		var anim_data := _find_anim_data(config_data, _current_anim)
		_cached_anim_data[config_id] = anim_data


func _apply_current_frame() -> void:
	"""将当前帧应用到所有部件"""
	for config_id in _cached_anim_data:
		_apply_frame_for_config(config_id)


func _apply_frame_for_config(config_id: String) -> void:
	var anim_data: Dictionary = _cached_anim_data.get(config_id, {})
	if anim_data.is_empty():
		return

	var frames: Array = anim_data.get("frames", [])
	if frames.is_empty():
		return

	# 帧索引可能超出此配置的帧数，做 wrapping
	var frame_idx: int = _current_frame % frames.size()
	var frame: Dictionary = frames[frame_idx]

	var anim_name: String = anim_data.get("name", "")

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
	sprite_node.position = _builder.compute_sprite_position(sprite_cfg)

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
	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if anim_data.is_empty():
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
	var sprite_pos := _builder.compute_sprite_position(sprite_cfg)

	for bone_map in sprite_cfg.get("map", []):
		var bone_name: String = bone_map.get("bone", "")
		var offset_x: float = bone_map.get("offset_x", 0.0)
		var offset_y: float = bone_map.get("offset_y", 0.0)
		var bone_offset := Vector2(offset_x, offset_y)
		var new_pos := sprite_pos + bone_offset

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


# ============================================================
# Face Blink 眨眼系统
# ============================================================

func _update_blink(delta: float) -> void:
	"""驱动 face 部件的眨眼动画，独立于主循环

	规则：
	- 随机间隔 2-6 秒触发一次眨眼
	- 眨眼时播放 blink 动画（3 帧，每帧 60ms）
	- 播放完后回到主循环当前动画（default）
	- 不干扰 _process 中的主帧推进逻辑
	"""
	var face_node := _builder.get_sprite_nodes().get("face") as VisualItemPart
	if face_node == null:
		return
	var sf := face_node.sprite_frames
	if sf == null or not sf.has_animation("blink"):
		return

	if _blink_active:
		# 正在播放 blink 动画
		_blink_frame_timer_ms += delta * 1000.0
		if _blink_frame_timer_ms >= BLINK_FRAME_DELAY_MS:
			_blink_frame_timer_ms = 0.0
			_blink_frame += 1
			var blink_max := sf.get_frame_count("blink")
			if _blink_frame >= blink_max:
				# blink 播放完毕，恢复到之前保存的动画和帧
				_blink_active = false
				_blink_frame = 0
				_reset_blink_interval()
				face_node.animation = _blink_saved_anim
				face_node.frame = _blink_saved_frame
			else:
				# 下一帧
				face_node.animation = "blink"
				face_node.frame = _blink_frame
	else:
		# 等待下次眨眼
		_blink_timer_ms += delta * 1000.0
		if _blink_timer_ms >= _blink_interval_ms:
			_blink_timer_ms = 0.0
			# 保存当前 face 状态，用于 blink 结束后恢复
			_blink_saved_anim = face_node.animation
			_blink_saved_frame = face_node.frame
			_blink_active = true
			_blink_frame = 0
			_blink_frame_timer_ms = 0.0
			face_node.animation = "blink"
			face_node.frame = 0


func _reset_blink_interval() -> void:
	"""随机生成下次眨眼间隔（2-6 秒）"""
	_blink_interval_ms = randf_range(BLINK_MIN_INTERVAL_MS, BLINK_MAX_INTERVAL_MS)
