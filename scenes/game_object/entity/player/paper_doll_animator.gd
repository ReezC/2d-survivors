class_name PaperDollAnimator extends Node
## 纸娃娃动画控制器 —— 自主读取 CharacterBody 数据并驱动帧切换、骨骼更新
##
## 挂载在角色根节点下（与 body/CharacterBody 同级）。
## 无需外部初始化，_ready() 自动从 CharacterBody 读取 VisualItem 数据并构建。

## Sequence 类型的 buff 动画播放完整个列表时发出（非循环类型专用）
signal buff_animation_finished()

# ---- 数据源 ----
var _character_body: CharacterBody
var _visual_node: Node2D

# ---- 运行时状态 ----
var _builder: PaperDollBuilder = PaperDollBuilder.new()
var _current_anim: String = ""
var _current_frame: int = 0
var _frame_timer_ms: float = 0.0
var _face_direction: int = -1  # 默认朝左（精灵默认方向）, 1=右（翻转）
var _pingpong: bool = false        # 是否乒乓循环（待机动画）
var _pingpong_forward: bool = true # 乒乓方向：true=正向, false=反向

# ---- 每帧缓存：避免 _process 中重复 _find_anim_data 遍历 ----
var _cached_anim_data: Dictionary = {}  # {config_id: anim_data_dict}

# ---- 动画切换时的部件管理 ----
var _removed_sprites: Dictionary = {}  # {sprite_name: true} 已从场景树移除的部件

# ---- 槽位配置变更检测 ----
var _slot_config_paths: Dictionary = {}  # islot_enum → String

# 角色状态到动画名的映射
const STATE_ANIM_MAP := {
	0: "stand1",     # 待机
	1: "walk1",      # 移动
	2: "dead",       # 死亡
}

# ---- Buff 动画系统 ----
var _buff_anim_active: bool = false
var _buff_anim_list: Array[String] = []   # 展开后的动画名列表
var _buff_anim_index: int = 0             # 当前播放到的索引
var _buff_anim_loop: bool = false         # 是否循环播放列表


func _ready() -> void:
	"""自主从 CharacterBody 读取数据并构建纸娃娃系统"""
	var player_root := get_parent()
	if player_root == null:
		return

	_character_body = player_root.get_node_or_null("body") as CharacterBody
	if _character_body == null:
		return

	_visual_node = player_root.get_node_or_null("视觉") as Node2D

	# 1. 禁用并清除 AnimationPlayer
	_disable_animation_player(player_root)

	# 2. 清空视觉下的旧部件
	if _visual_node:
		for child in _visual_node.get_children():
			child.queue_free()

	# 3. 委托 Builder 构建纸娃娃系统
	_builder.build(player_root)

	# 4. 从 CharacterBody 读取 VisualItem 数据
	if _character_body.装备槽位:
		for visual_item in _character_body.装备槽位.islot.values():
			if visual_item == null:
				continue
			_builder.add_part_config(visual_item.动画帧配置文件, visual_item)

	_builder.finish_children_sort()

	# 5. 按槽位应用首次渲染配置
	_apply_all_slot_rendering()

	# 6. 禁用 AnimationTree（纸娃娃自行驱动帧切换）
	_disable_animation_tree(player_root)

	set_animation_by_state(0)


func add_part_config(json_path: String, source_visual_item: VisualItem = null) -> void:
	"""添加一个部件配置（可附带 VisualItem 用于获取默认动画等属性）"""
	_builder.add_part_config(json_path, source_visual_item)


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
	# 同步部件在场景树中的存在性：当前动画中没有帧数据的部件应移除（如 dead 无 arm）
	_sync_parts_in_scene()
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
		var was_at_end := _current_frame >= max_frames - 1
		_current_frame = (_current_frame + 1) % max_frames
		if _buff_anim_active and was_at_end:
			_advance_buff_animation()


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


func _get_active_sprite_names() -> Array:
	"""收集当前动画所有帧中实际使用的 sprite 名称集合。
	
	遍历所有已缓存 anim_data 的每一帧 spritecfg，
	同时处理 .Sprite 和 .FrameLink 两种类型。
	"""
	var active: Dictionary = {}
	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if anim_data.is_empty():
			continue
		var frames: Array = anim_data.get("frames", [])
		for frame in frames:
			for sprite_cfg in frame.get("spritecfg", []):
				var sname: String = sprite_cfg.get("name", "")
				if not sname.is_empty():
					active[sname] = true
	return active.keys()


func _sync_parts_in_scene() -> void:
	"""动画切换后同步部件在场景树中的存在性。
	
	判定规则：
	- 所属配置「有」当前动画 & sprite 在帧数据中 → 保留在场景
	- 所属配置「有」当前动画 & sprite 不在帧数据中 → 从场景树移除
	  （例如 body/arm 共享 00002000，dead 只有 body 的帧 → arm 移除）
	- 所属配置「没有」当前动画 → 保持原样，不处理
	  （例如 head 属于 00012000，该配置没有 dead → head 保持在场景中）
	"""
	var sprite_nodes: Dictionary = _builder.get_sprite_nodes()
	if sprite_nodes.is_empty():
		return
	
	var active_names := _get_active_sprite_names()
	var active_set: Dictionary = {}
	for n in active_names:
		active_set[n] = true
	
	# 收集没有当前动画的配置 ID（其 sprites 不应被移除）
	var unmanaged_configs: Dictionary = {}
	for config_id in _cached_anim_data:
		if _cached_anim_data[config_id].is_empty():
			unmanaged_configs[config_id] = true
	
	var needs_sort := false
	
	for sname in sprite_nodes:
		var sprite_node: Node = sprite_nodes[sname]
		var part := sprite_node as VisualItemPart
		var config_id: String = part.source_item.id if (part and part.source_item) else ""
		
		if active_set.has(sname):
			# 所属配置有此动画且 sprite 出现在帧数据中 → 应在场景中
			if _removed_sprites.has(sname):
				_visual_node.add_child(sprite_node)
				@warning_ignore("confusable_identifier")
				_removed_sprites.erase(sname)
				needs_sort = true
		elif unmanaged_configs.has(config_id):
			# 所属配置没有此动画 → 保持原样，不操作
			if _removed_sprites.has(sname):
				_visual_node.add_child(sprite_node)
				@warning_ignore("confusable_identifier")
				_removed_sprites.erase(sname)
				needs_sort = true
		else:
			# 所属配置有此动画但 sprite 不在帧数据中 → 移除
			if not _removed_sprites.has(sname):
				_visual_node.remove_child(sprite_node)
				_removed_sprites[sname] = true
	
	# 如果有部件重新加入，需要重新排序子节点
	if needs_sort and _visual_node and _visual_node.has_method("reorder_children_by_zmap"):
		_visual_node.reorder_children_by_zmap()


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
		if sprite_cfg.get("name", "") == "face":
			continue  # face 由 player.gd 状态机独立管理
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
	"""更新骨骼位置：重置本帧骨骼运算状态，重新遍历当前帧所有 Sprite 更新位置
	对于没有当前动画数据的配置，使用 "front" 动画的帧 0 作为骨骼结构 fallback，
	确保 brow 等骨骼在任意动画下都能跟随 body 的 neck/navel 等骨骼链更新位置。
	"""
	var body_bone := _builder.get_body_bone()
	if body_bone == null:
		return

	# 重置骨骼运算字典（本帧"已计入"的骨骼），但不删除节点树上的骨骼节点
	_reset_bone_nodes()

	# 收集当前帧所有 Sprite 的骨骼映射（包括 FrameLink 引用的目标 Sprite）
	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if anim_data.is_empty():
			_update_skeleton_from_fallback(config_id)
			continue

		var frames: Array = anim_data.get("frames", [])
		if frames.is_empty():
			_update_skeleton_from_fallback(config_id)
			continue

		var frame_idx: int = _current_frame % frames.size()
		var frame: Dictionary = frames[frame_idx]

		for sprite_cfg in frame.get("spritecfg", []):
			var stype = sprite_cfg.get("$type", "")
			if stype.ends_with(".Sprite"):
				_process_skeleton_maps(sprite_cfg)
			elif stype.ends_with(".FrameLink"):
				_process_framelink_skeleton(sprite_cfg)


func _update_skeleton_from_fallback(config_id: String) -> void:
	"""当前动画无数据时，使用 "front" 动画的帧 0 更新骨骼位置和精灵 position/offset。
	确保 brow、hand 等辅助骨骼在新动画下仍能跟随 body 骨骼链更新位置，
	同时精灵节点也基于最新的骨骼位置重新计算自身坐标。
	"""
	var all_configs := _builder.get_all_configs()
	var config_data: Dictionary = all_configs.get(config_id, {})
	if config_data.is_empty():
		return

	# 优先查找 "front" 动画，找不到则用第一个动画
	var fallback_anim: Dictionary = {}
	for anim_cfg in config_data.get("animCfg", []):
		if anim_cfg.get("name") == "front":
			fallback_anim = anim_cfg
			break
	if fallback_anim.is_empty():
		var anim_cfgs: Array = config_data.get("animCfg", [])
		if anim_cfgs.size() > 0:
			fallback_anim = anim_cfgs[0]

	if fallback_anim.is_empty():
		return

	var frames: Array = fallback_anim.get("frames", [])
	if frames.is_empty():
		return

	var frame: Dictionary = frames[0]
	for sprite_cfg in frame.get("spritecfg", []):
		var stype = sprite_cfg.get("$type", "")
		if stype.ends_with(".Sprite"):
			_process_skeleton_maps(sprite_cfg)
			_apply_sprite_position(sprite_cfg)
		elif stype.ends_with(".FrameLink"):
			_process_framelink_skeleton(sprite_cfg)
			var resolved: Dictionary = _builder._resolve_framelink_to_sprite_cfg(sprite_cfg)
			if not resolved.is_empty():
				_apply_sprite_position(resolved)


## 仅更新精灵节点的 position 和 offset（不切换动画/帧）
func _apply_sprite_position(sprite_cfg: Dictionary) -> void:
	var sname: String = sprite_cfg.get("name", "")
	var origin_x: float = sprite_cfg.get("origin_x", 0.0)
	var origin_y: float = sprite_cfg.get("origin_y", 0.0)
	var sprite_node := _builder.get_sprite_nodes().get(sname) as VisualItemPart
	if sprite_node == null:
		return
	sprite_node.offset = Vector2(-origin_x, -origin_y)
	sprite_node.position = _builder.compute_sprite_position(sprite_cfg)


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
# Buff 动画系统（施法状态专用）
# ============================================================

## 播放 Buff 动画（结构对应 cfg 中 BuffAnimation 接口）
## @param config: BuffAnimation 配置字典
func play_buff_animation(config: Dictionary) -> void:
	if config.is_empty():
		_buff_anim_active = false
		return

	var type_name: String = _buff_anim_type(config)

	if type_name == "None":
		_buff_anim_active = false
		return

	# 将 BuffAnimation 树展开为平铺动画名列表
	_resolve_buff_anim_list(config)

	if _buff_anim_list.is_empty():
		_buff_anim_active = false
		return

	_buff_anim_index = 0
	_buff_anim_active = true
	_change_animation(_buff_anim_list[0])


## 停止 Buff 动画模式，恢复正常动画
## 注意：stop_buff_animation 不会发出 buff_animation_finished 信号
## 该信号仅在 Sequence 类型动画自然播完时由 _advance_buff_animation 发出
func stop_buff_animation() -> void:
	_buff_anim_active = false
	_buff_anim_list.clear()
	_buff_anim_index = 0


## 展开 BuffAnimation 配置为平铺动画名列表并设置循环模式
func _resolve_buff_anim_list(config: Dictionary) -> void:
	_buff_anim_list.clear()
	var type_name: String = _buff_anim_type(config)

	match type_name:
		"Single":
			_buff_anim_list.append(config.get("animationName", ""))
			_buff_anim_loop = true
		"Random":
			var names: Array = config.get("animationNames", [])
			var picked := _pick_weighted_random(names)
			if picked:
				_buff_anim_list.append(picked)
			_buff_anim_loop = true
		"Loop":
			_resolve_anim_list_items(config.get("animList", []))
			_buff_anim_loop = true
		"Sequence":
			_resolve_anim_list_items(config.get("animList", []))
			_buff_anim_loop = false


## 递归展开 animList 中的每个 BuffAnimation 节点
func _resolve_anim_list_items(anim_list: Array) -> void:
	for item in anim_list:
		var type_name: String = _buff_anim_type(item)
		match type_name:
			"Single":
				_buff_anim_list.append(item.get("animationName", ""))
			"Random":
				var names: Array = item.get("animationNames", [])
				var picked := _pick_weighted_random(names)
				if picked:
					_buff_anim_list.append(picked)
			"Loop", "Sequence":
				_resolve_anim_list_items(item.get("animList", []))


## 从加权列表中随机选取一个 name
func _pick_weighted_random(name_list: Array) -> String:
	if name_list.is_empty():
		return ""
	# 计算总权重
	var total: float = 0.0
	for entry in name_list:
		total += float(entry.get("value", 1))
	if total <= 0.0:
		return name_list[0].get("name", "")
	# 按权重随机
	var roll := randf() * total
	var acc: float = 0.0
	for entry in name_list:
		acc += float(entry.get("value", 1))
		if roll < acc:
			return entry.get("name", "")
	return name_list[-1].get("name", "")


## 推进到列表中的下一段动画
func _advance_buff_animation() -> void:
	_buff_anim_index += 1
	if _buff_anim_index >= _buff_anim_list.size():
		if _buff_anim_loop:
			_buff_anim_index = 0
		else:
			# Sequence 播完，发出信号通知外部
			buff_animation_finished.emit()
			return
	_change_animation(_buff_anim_list[_buff_anim_index])


## 提取 $type 的短类型名（如 "Single", "Random"）
func _buff_anim_type(config: Dictionary) -> String:
	var full: String = config.get("$type", "")
	return full.split(".")[-1]


# ============================================================
# Face 渲染接口（供 player.gd 的 face 状态机调用）
# ============================================================

## 返回 face 精灵节点，不存在时返回 null
func get_face_node() -> VisualItemPart:
	return _builder.get_sprite_nodes().get("face") as VisualItemPart


## 将 face 精灵的动画和帧同步到当前主循环动画的对应帧
func apply_face_to_current_frame() -> void:
	var face_node := get_face_node()
	if face_node == null:
		return

	for config_id in _cached_anim_data:
		var anim_data: Dictionary = _cached_anim_data[config_id]
		if anim_data.is_empty():
			continue
		var frames: Array = anim_data.get("frames", [])
		if frames.is_empty():
			continue
		var frame_idx: int = _current_frame % frames.size()
		var frame: Dictionary = frames[frame_idx]
		var anim_name: String = anim_data.get("name", "")

		for sprite_cfg in frame.get("spritecfg", []):
			if sprite_cfg.get("name", "") != "face":
				continue
			var stype = sprite_cfg.get("$type", "")
			if stype.ends_with(".Sprite"):
				_apply_sprite(sprite_cfg, anim_name, frame_idx)
			elif stype.ends_with(".FrameLink"):
				_apply_framelink(sprite_cfg, anim_name, frame_idx)
			return  # face 只处理一次


## 直接设置 face 精灵的动画名和帧号（用于 blink 等独立表情）
func set_face_frame(anim_name: String, frame_idx: int) -> void:
	var face_node := get_face_node()
	if face_node == null:
		return
	# 先同步 position/offset，防止身体动画挂点移动导致 face 脱离
	apply_face_to_current_frame()
	if face_node.sprite_frames and face_node.sprite_frames.has_animation(anim_name):
		face_node.animation = anim_name
	face_node.frame = frame_idx


## 检查 face 精灵是否拥有指定动画
func face_has_animation(anim_name: String) -> bool:
	var face_node := get_face_node()
	if face_node == null or face_node.sprite_frames == null:
		return false
	return face_node.sprite_frames.has_animation(anim_name)


## 获取 face 指定动画的帧数
func face_get_frame_count(anim_name: String) -> int:
	var face_node := get_face_node()
	if face_node == null or face_node.sprite_frames == null:
		return 0
	return face_node.sprite_frames.get_frame_count(anim_name)


# ============================================================
#  初始化辅助
# ============================================================

func _disable_animation_player(player_root: Node) -> void:
	var ap := player_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	ap.active = false
	ap.stop()
	if ap.has_animation_library(&""):
		var lib := ap.get_animation_library(&"")
		for old_anim in lib.get_animation_list():
			lib.remove_animation(old_anim)


func _disable_animation_tree(player_root: Node) -> void:
	var at := player_root.get_node_or_null("AnimationTree") as AnimationTree
	if at:
		at.active = false


# ============================================================
#  槽位渲染应用（从 CharacterBody 移入）
# ============================================================

func _apply_all_slot_rendering() -> void:
	"""对所有有数据（部件非空且 VisualItem 存在）的槽位，调用 视觉 进行渲染配置"""
	if _visual_node == null:
		return
	if not _visual_node.has_method(&"configure_part"):
		return
	for slot_name in EquipSlotConfig.islot_enum:
		_apply_slot_rendering(EquipSlotConfig.islot_enum[slot_name])


func _apply_slot_rendering(slot_key: int) -> void:
	"""将某个槽位的 VisualItem 应用到其绑定的预制部件"""
	if _character_body == null:
		return
	var visual_item: VisualItem = _character_body.装备槽位.islot.get(slot_key)
	if visual_item == null:
		return
	var parts: Array = _character_body.get_slot_parts(slot_key)
	if parts.is_empty():
		return
	for part in parts:
		if part != null and part is VisualItemPart:
			_visual_node.configure_part(part as VisualItemPart, visual_item)

	_slot_config_paths[slot_key] = visual_item.动画帧配置文件


# ============================================================
#  死亡重建
# ============================================================

## 死亡时按基础槽位（Bd, Hd, Hr, Fc）重建纸娃娃
func rebuild_for_death() -> void:
	"""清空当前纸娃娃，只使用 Bd/Hd/Hr/Fc 槽位的 VisualItem 重新构建"""
	if _character_body == null:
		return

	# 停止 Buff 动画
	stop_buff_animation()

	# 清空内部缓存
	_cached_anim_data.clear()
	_removed_sprites.clear()
	_slot_config_paths.clear()

	# 委托 Builder 清空所有节点
	_builder.clear_all()

	# 死亡时仅保留四个基础外观槽位
	var death_slots := [
		EquipSlotConfig.islot_enum.Bd,
		EquipSlotConfig.islot_enum.Hd,
		EquipSlotConfig.islot_enum.Hr,
		EquipSlotConfig.islot_enum.Fc,
	]

	for slot_key in death_slots:
		var visual_item: VisualItem = _character_body.装备槽位.islot.get(slot_key)
		if visual_item == null:
			continue
		_builder.add_part_config(visual_item.动画帧配置文件, visual_item)

	_builder.finish_children_sort()

	# 强制切换到 dead 动画
	_current_anim = ""
	set_animation_by_state(2)


# ============================================================
#  运行时装备更换 API（从 CharacterBody 移入）
# ============================================================

## 运行时更换装备：更新 islot 字典，检测部件是否匹配，不匹配则按配置重构
func set_slot_item(slot_key: EquipSlotConfig.islot_enum, new_item: VisualItem) -> void:
	if _character_body == null or _character_body.装备槽位 == null:
		return

	var old_item: VisualItem = _character_body.装备槽位.islot.get(slot_key)
	if old_item == new_item:
		return

	_character_body.装备槽位.islot[slot_key] = new_item

	if new_item == null:
		_slot_config_paths.erase(slot_key)
		return

	_refresh_slot(slot_key)


func _refresh_slot(slot_key) -> void:
	"""检测槽位配置是否变化，变化时重构渲染"""
	if _character_body == null:
		return
	var visual_item: VisualItem = _character_body.装备槽位.islot.get(slot_key)
	if visual_item == null or _visual_node == null:
		return

	var parts: Array = _character_body.get_slot_parts(slot_key)
	if parts.is_empty():
		return

	var last_path: String = _slot_config_paths.get(slot_key, "")
	var config_path: String = visual_item.动画帧配置文件

	if config_path != last_path:
		_slot_config_paths[slot_key] = config_path
		if _visual_node.has_method(&"configure_part"):
			for part in parts:
				if part != null and part is VisualItemPart:
					_visual_node.configure_part(part as VisualItemPart, visual_item)


## 根据 islot_enum 获取对应槽位的 VisualItem
func get_slot(slot_key: EquipSlotConfig.islot_enum) -> VisualItem:
	if _character_body == null or _character_body.装备槽位 == null:
		return null
	return _character_body.装备槽位.islot.get(slot_key, null)
