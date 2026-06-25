class_name PaperDollBuilder extends RefCounted
## 纸娃娃构建器 —— 根据 JSON 配置动态创建视觉节点和骨骼树
##
## 使用方式：
##   var builder = PaperDollBuilder.new()
##   builder.build(character_body_node, zmap_resource)
##   builder.add_part_config("res://config/_animconfig_animconfig/00002000.json")
##   builder.add_part_config("res://config/_animconfig_animconfig/00012000.json")

const VISUAL_ITEM_PART_SCRIPT := preload("res://resources/visual_item/visual_item_part.gd")

# ---- 内部状态 ----
var _character: Node2D           # character_body 节点
var _visual_parent: Node2D       # "视觉" 容器节点
var _body_bone: Node2D           # "body" 骨骼根节点
var _zmap: zmap

## 已加载的部件配置 {animconfig_id: Dictionary(parsed json)}
var _part_configs: Dictionary = {}

## VisualItem 资源引用 {animconfig_id: VisualItem}，用于获取 默认动画名称 等
var _visual_items: Dictionary = {}

## 精灵节点映射 {sprite_name: VisualItemPart}
var _sprite_nodes: Dictionary = {}

## 骨骼节点映射 {bone_name: Node2D}
var _bone_nodes: Dictionary = {}

## 脏标记：是否有新的子节点加入，需要重新排序
var _children_dirty: bool = false


func build(character: Node2D) -> void:
	_character = character

	# 1. 查找预制的 "视觉" 容器节点
	_visual_parent = _character.get_node_or_null("视觉") as Node2D
	if _visual_parent == null:
		push_error("PaperDollBuilder: 未找到预制的 视觉 节点")
		return

	# zmap 引用从 视觉 节点获取
	_acquire_zmap_from_visual()

	# 2. 查找预制的 body 骨骼根节点
	_body_bone = _character.get_node_or_null("body") as Node2D
	if _body_bone == null:
		push_error("PaperDollBuilder: 未找到预制的 body 骨骼根节点")
		return
	_bone_nodes["body"] = _body_bone


func add_part_config(json_path: String, source_visual_item: VisualItem = null) -> void:
	"""加载一个部件的 animconfig JSON 配置并构建其视觉节点
	
	source_visual_item: 创建该部件的 VisualItem 资源引用，用于获取 默认动画名称 等属性
	"""
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
	var _config_name: String = data.get("name", "")
	_part_configs[config_id] = data
	if source_visual_item:
		_visual_items[config_id] = source_visual_item
	# print("[Builder] 加载配置: id=%s, name=%s" % [config_id, config_name])

	# 3. 收集所有帧中出现的 sprite 名称和 z 层级，为每个创建 VisualItemPart
	var sprite_info := _collect_sprite_info(data)  # {sprite_name: z_layer}
	# print("[Builder]   收集到 sprite: %s" % str(sprite_info.keys()))
	for sname in sprite_info:
		if _sprite_nodes.has(sname):
			# print("[Builder]   sprite '%s' 已存在，跳过创建" % sname)
			continue  # 同名 sprite 只创建一次（多个部件可能引用同一骨骼）

		var node_name: String = sname + "_" + data.get("name", "") + "_" + data.get("id", "") 
		var sprite_node := AnimatedSprite2D.new()
		sprite_node.name = node_name
		sprite_node.centered = false
		sprite_node.script = VISUAL_ITEM_PART_SCRIPT
		# 设置 VisualItemPart 属性
		sprite_node.part_name = sname
		sprite_node.z = sprite_info[sname]
		# 创建 VisualItem 数据资源
		var vi := VisualItem.new()
		vi.id = data["id"]
		vi.item_name = data.get("name", "")
		vi.动画帧配置文件 = json_path
		sprite_node.source_item = vi
		_visual_parent.add_child(sprite_node)
		_sprite_nodes[sname] = sprite_node
		# print("[Builder]   创建 sprite 节点: %s (name=%s)" % [sname, node_name])

	# 4. 构建此部件的 SpriteFrames（收集所有动画的所有帧的纹理，含 FrameLink 解析）
	_build_sprite_frames_for_config(data)

	# 5. 从默认动画的第一帧构建初始骨骼树并应用首帧视觉效果
	var default_anim: String = source_visual_item.默认动画名称 if source_visual_item else ""
	_build_initial_skeleton(data, default_anim)

	# 6. 标记需要重新排序（延迟到 build_finish 一次性执行）
	_children_dirty = true


func _acquire_zmap_from_visual() -> void:
	"""从 视觉 节点获取 zmap 引用（zmap 归 视觉.gd 管理）"""
	if _visual_parent and "zmap_file" in _visual_parent:
		_zmap = _visual_parent.zmap_file


func _reorder_visual_children() -> void:
	"""触发 视觉 节点按 zmap 重新排序子节点顺序"""
	if _visual_parent and _visual_parent.has_method("reorder_children_by_zmap"):
		_visual_parent.reorder_children_by_zmap()


func finish_children_sort() -> void:
	"""在所有配置加载完毕后，一次性排序子节点（由 Animator.build_finish 调用）"""
	if _children_dirty:
		_children_dirty = false
		_reorder_visual_children()


func _collect_sprite_info(data: Dictionary) -> Dictionary:
	"""一次遍历收集所有 sprite name → z_layer 映射"""
	var info: Dictionary = {}
	for anim_cfg in data.get("animCfg", []):
		for frame in anim_cfg.get("frames", []):
			for sprite_cfg in frame.get("spritecfg", []):
				var stype = sprite_cfg.get("$type", "")
				if stype.ends_with(".Sprite"):
					var sname: String = sprite_cfg.get("name", "")
					if not info.has(sname):
						var z_name: String = sprite_cfg.get("z", "")
						var layer: zmap.Layer = zmap.Layer.body
						if _zmap:
							var idx: int = _zmap.get_layer_index_by_name(z_name)
							if idx >= 0:
								layer = zmap.Layer.values()[idx]
						info[sname] = layer
	return info


func _build_sprite_frames_for_config(data: Dictionary) -> void:
	"""为此配置中每个 sprite 构建 SpriteFrames 资源
	
	处理两种精灵类型：
	- .Sprite：直接从 spriteDir 加载纹理
	- .FrameLink：解析链接，从目标配置的 Sprite 中获取纹理
	"""
	var _config_id: String = data.get("id", "?")
	for anim_cfg in data.get("animCfg", []):
		var anim_name: String = anim_cfg.get("name", "")
		var frames_array: Array = anim_cfg.get("frames", [])

		# 收集此动画中每个 sprite 的帧纹理
		var sprite_textures: Dictionary = {}  # {sprite_name: [texture, ...]}
		for frame in frames_array:
			for sprite_cfg in frame.get("spritecfg", []):
				var stype = sprite_cfg.get("$type", "")
				var tex: Texture2D = null

				if stype.ends_with(".Sprite"):
					var tex_path: String = sprite_cfg.get("spriteDir", "")
					tex = load(tex_path) as Texture2D
					if tex == null:
						push_warning("PaperDollBuilder: 无法加载纹理 %s" % tex_path)
						continue
				elif stype.ends_with(".FrameLink"):
					tex = _resolve_framelink_texture(sprite_cfg)
					if tex == null:
						continue
				else:
					continue

				var sname: String = sprite_cfg.get("name", "")
				if not sprite_textures.has(sname):
					sprite_textures[sname] = []
				sprite_textures[sname].append(tex)

		if sprite_textures.is_empty():
			continue  # 此动画全是无纹理的 FrameLink 或空，跳过

		# 为每个 sprite 的 SpriteFrames 添加此动画
		for sname in sprite_textures:
			var sprite_node := _sprite_nodes.get(sname) as VisualItemPart
			if sprite_node == null:
				push_warning("PaperDollBuilder: sprite '%s' 不在 _sprite_nodes 中" % sname)
				continue

			var sf := sprite_node.sprite_frames
			if sf == null:
				sf = SpriteFrames.new()

			# 如果动画已存在：
			# - 帧数为 0 → AnimatedSprite2D 进入场景树时自动生成的幽灵动画，删除并重建
			# - 帧数 > 0 → 由先加载的配置创建的有效动画，跳过以避免覆盖
			if sf.has_animation(anim_name):
				if sf.get_frame_count(anim_name) == 0:
					sf.remove_animation(anim_name)
				else:
					continue

			sf.add_animation(anim_name)
			sf.set_animation_loop(anim_name, true)
			for tex in sprite_textures[sname]:
				sf.add_frame(anim_name, tex, 1.0)

			sprite_node.sprite_frames = sf


func _build_initial_skeleton(data: Dictionary, default_anim_name: String = "") -> void:
	"""根据默认动画的第一帧创建初始骨骼树，并设置精灵 position
	
	优先使用 default_anim_name 指定的动画，找不到则回退到第一个动画。
	遍历指定动画首帧中的 .Sprite 或 .FrameLink 来构建骨骼。
	如果当前动画全是 FrameLink，会递归解析目标帧。
	"""
	var anim_cfgs: Array = data.get("animCfg", [])
	if anim_cfgs.is_empty():
		return

	# 根据默认动画名称查找目标动画在 anim_cfgs 中的索引
	var target_anim_index := 0
	var _target_anim_name: String = anim_cfgs[0].get("name", "")
	if not default_anim_name.is_empty():
		for i in anim_cfgs.size():
			if anim_cfgs[i].get("name", "") == default_anim_name:
				target_anim_index = i
				_target_anim_name = default_anim_name
				break

	var frames: Array = anim_cfgs[target_anim_index].get("frames", [])
	if frames.is_empty():
		return

	for sprite_cfg in frames[0].get("spritecfg", []):
		var stype = sprite_cfg.get("$type", "")
		if stype.ends_with(".Sprite"):
			_create_bones_from_sprite_cfg(sprite_cfg)
		elif stype.ends_with(".FrameLink"):
			_create_bones_from_framelink(sprite_cfg)

	# 初始帧就应用一帧（设置 offset 和动画）
	_apply_frame_visuals(data, target_anim_index, 0)


func _create_bones_from_sprite_cfg(sprite_cfg: Dictionary) -> void:
	"""从单个 Sprite 配置创建其 map 中不存在的骨骼"""
	var sprite_pos := compute_sprite_position(sprite_cfg)

	for bone_map in sprite_cfg.get("map", []):
		var bone_name: String = bone_map.get("bone", "")
		var off_x: float = bone_map.get("offset_x", 0.0)
		var off_y: float = bone_map.get("offset_y", 0.0)
		var bone_offset := Vector2(off_x, off_y)

		var bone_node := _bone_nodes.get(bone_name) as Node2D

		if bone_node == null:
			bone_node = Node2D.new()
			bone_node.name = bone_name
			_body_bone.add_child(bone_node)
			bone_node.position = sprite_pos + bone_offset
			_bone_nodes[bone_name] = bone_node


func _create_bones_from_framelink(link_cfg: Dictionary) -> void:
	"""解析 FrameLink 引用的目标帧中的 Sprite，创建骨骼"""
	var link_id: String = link_cfg.get("id", "")
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)

	var target_config: Dictionary = _part_configs.get(link_id)
	if target_config == null:
		return

	# 查找目标动画
	var target_anim_cfg := _find_anim_cfg(target_config, link_anim)
	if target_anim_cfg.is_empty():
		return

	var target_frames: Array = target_anim_cfg.get("frames", [])
	if link_frame >= target_frames.size():
		return

	var target_frame: Dictionary = target_frames[link_frame]
	for sprite_cfg in target_frame.get("spritecfg", []):
		if sprite_cfg.get("$type", "").ends_with(".Sprite"):
			_create_bones_from_sprite_cfg(sprite_cfg)


## 解析 FrameLink 引用，返回目标 Sprite 的纹理
## 用于构建 SpriteFrames 时加载 FrameLink 帧的纹理
func _resolve_framelink_texture(link_cfg: Dictionary) -> Texture2D:
	var link_id: String = link_cfg.get("id", "")
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)
	var link_sprite: String = link_cfg.get("spriteName", link_cfg.get("name", ""))

	if link_id.is_empty() or link_anim.is_empty():
		return null

	var target_config: Dictionary = _part_configs.get(link_id)
	if target_config == null:
		return null

	var target_anim_cfg := _find_anim_cfg(target_config, link_anim)
	if target_anim_cfg.is_empty():
		return null

	var target_frames: Array = target_anim_cfg.get("frames", [])
	if link_frame >= target_frames.size():
		return null

	var target_frame: Dictionary = target_frames[link_frame]
	for sprite_cfg in target_frame.get("spritecfg", []):
		if sprite_cfg.get("$type", "").ends_with(".Sprite") and sprite_cfg.get("name", "") == link_sprite:
			var tex_path: String = sprite_cfg.get("spriteDir", "")
			if not tex_path.is_empty():
				var tex := load(tex_path) as Texture2D
				if tex == null:
					push_warning("PaperDollBuilder: FrameLink 无法加载纹理 %s" % tex_path)
				return tex

	return null


## 解析 FrameLink 引用，返回目标 Sprite 的完整配置字典（含 origin_x/origin_y, map 等）
func _resolve_framelink_to_sprite_cfg(link_cfg: Dictionary) -> Dictionary:
	var link_id: String = link_cfg.get("id", "")
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)
	var link_sprite: String = link_cfg.get("spriteName", link_cfg.get("name", ""))

	if link_id.is_empty() or link_anim.is_empty():
		return {}

	var target_config: Dictionary = _part_configs.get(link_id)
	if target_config == null:
		return {}

	var target_anim_cfg := _find_anim_cfg(target_config, link_anim)
	if target_anim_cfg.is_empty():
		return {}

	var target_frames: Array = target_anim_cfg.get("frames", [])
	if link_frame >= target_frames.size():
		return {}

	var target_frame: Dictionary = target_frames[link_frame]
	for sprite_cfg in target_frame.get("spritecfg", []):
		if sprite_cfg.get("$type", "").ends_with(".Sprite") and sprite_cfg.get("name", "") == link_sprite:
			return sprite_cfg

	return {}


## 在配置的 animCfg 数组中按 name 查找动画
func _find_anim_cfg(data: Dictionary, anim_name: String) -> Dictionary:
	for anim_cfg in data.get("animCfg", []):
		if anim_cfg.get("name") == anim_name:
			return anim_cfg
	return {}


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


## 清空所有内部状态，用于死亡时按指定槽位重建纸娃娃
func clear_all() -> void:
	# 移除所有精灵节点
	for sname in _sprite_nodes:
		var node = _sprite_nodes[sname]
		if node and is_instance_valid(node):
			_visual_parent.remove_child(node)
			node.queue_free()
	_sprite_nodes.clear()

	# 移除所有骨骼节点（保留 body 根）
	for bname in _bone_nodes:
		if bname != "body":
			var node = _bone_nodes[bname]
			if node and is_instance_valid(node):
				_body_bone.remove_child(node)
				node.queue_free()
	_bone_nodes.clear()
	_bone_nodes["body"] = _body_bone

	_part_configs.clear()
	_visual_items.clear()
	_children_dirty = false


func compute_sprite_position(sprite_cfg: Dictionary) -> Vector2:
	"""计算精灵节点在 视觉 容器下的 position（公开方法，供 Animator 调用）
	
	规则：精灵 position = 最后一个已存在骨骼的全局位置 - 该骨骼在当前 sprite map 中的 offset
	如果 map 中所有骨骼都不存在 → position = (0,0)（绑定到 body）
	"""
	var bone_maps: Array = sprite_cfg.get("map", [])
	if bone_maps.is_empty():
		return _body_bone.position - _visual_parent.position if _visual_parent else _body_bone.position
	
	# 找最后一个已存在的骨骼及其 offset
	var last_exist_bone: Node2D = null
	var last_exist_offset := Vector2.ZERO
	
	for bone_map in bone_maps:
		var bone_name: String = bone_map.get("bone", "")
		var off_x: float = bone_map.get("offset_x", 0.0)
		var off_y: float = bone_map.get("offset_y", 0.0)
		var bone_offset := Vector2(off_x, off_y)
		
		var bone_node := _bone_nodes.get(bone_name) as Node2D
		if bone_node != null:
			last_exist_bone = bone_node
			last_exist_offset = bone_offset
	
	var result: Vector2
	if last_exist_bone == null:
		# 全部骨骼都不存在 → 绑定到 body，跟随 body 骨骼位置
		result = _body_bone.position
	else:
		# 最后一个已存在骨骼的局部位置 - 该骨骼在当前 sprite map 中的 offset
		result = last_exist_bone.position - last_exist_offset
	
	# 换算到 视觉 容器的局部坐标
	if _visual_parent:
		return result - _visual_parent.position
	return result


## 重写指定 VisualItem 对应部件的首帧视觉效果
## 使用 VisualItem.默认动画名称 查找对应动画的首帧，应用到其下的所有 VisualItemPart
func rewrite_initial_frame(visual_item: VisualItem) -> void:
	if visual_item == null:
		return

	var config_id: String = visual_item.id
	var default_anim: String = visual_item.默认动画名称
	if config_id.is_empty() or default_anim.is_empty():
		return

	var data: Dictionary = _part_configs.get(config_id, {})
	if data.is_empty():
		return

	# 查找默认动画在 animCfg 中的索引
	var target_anim_index := -1
	var anim_cfgs: Array = data.get("animCfg", [])
	for i in anim_cfgs.size():
		if anim_cfgs[i].get("name", "") == default_anim:
			target_anim_index = i
			break
	if target_anim_index < 0:
		return

	# 对该配置拥有的所有 sprite 应用首帧视觉效果
	_apply_frame_visuals(data, target_anim_index, 0)


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
		var resolved_cfg: Dictionary  # 最终使用的 sprite 配置（FrameLink 会被解析）

		if stype.ends_with(".Sprite"):
			resolved_cfg = sprite_cfg
		elif stype.ends_with(".FrameLink"):
			resolved_cfg = _resolve_framelink_to_sprite_cfg(sprite_cfg)
		else:
			continue

		if resolved_cfg.is_empty():
			continue

		var sname: String = resolved_cfg.get("name", "")
		var origin_x: float = resolved_cfg.get("origin_x", 0.0)
		var origin_y: float = resolved_cfg.get("origin_y", 0.0)

		var sprite_node := _sprite_nodes.get(sname) as VisualItemPart
		if sprite_node == null:
			continue

		# offset = -(origin_x, origin_y)：纹理绘制锚点
		sprite_node.offset = Vector2(-origin_x, -origin_y)

		# position = 骨骼链末端的全局位置
		sprite_node.position = compute_sprite_position(resolved_cfg)

		# 切换动画
		if sprite_node.sprite_frames and sprite_node.sprite_frames.has_animation(anim_name):
			sprite_node.animation = anim_name
		sprite_node.frame = frame_index


## 获取某个配置的动画帧数
func get_animation_frame_count(config_data: Dictionary, anim_name: String) -> int:
	for anim_cfg in config_data.get("animCfg", []):
		if anim_cfg.get("name") == anim_name:
			return anim_cfg.get("frames", []).size()
	return 0
