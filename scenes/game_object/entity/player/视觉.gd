extends Node2D

@export var zmap_file: zmap

## JSON 配置缓存 {config_id: Dictionary(parsed json)}，用于 FrameLink 跨配置解析
var _config_cache: Dictionary = {}


func _ready() -> void:
	if zmap_file == null:
		push_warning("视觉节点缺少 zmap_file 引用")
		return
	# 按 zmap 层级排序子节点顺序（z_index = 0，不污染 actor 间排序）
	reorder_children_by_zmap()
	# 注意：不再自动触发管线设置，改为由 CharacterBody 统一驱动
	# character_body._ready() 执行 _apply_all_slot_rendering() → configure_part()


## 按 zmap 层级排序子节点：zmap 枚举中越靠前 → 子节点 index 越大 → 渲染在上层
## 不使用 z_index，保持所有子节点 z_index = 0，仅靠节点顺序控制部件间遮挡
func reorder_children_by_zmap() -> void:
	if zmap_file == null:
		return

	# 收集子节点及其 zmap 层级索引
	var child_layers: Array[Dictionary] = []
	for child in get_children():
		var layer: zmap.Layer
		if child is VisualItemPart:
			layer = child.z
		else:
			var idx := zmap_file.get_layer_index_by_name(child.name)
			if idx == -1:
				# push_warning("子节点 '%s' 未在 zmap.Layer 枚举中找到，且没有 z 属性" % child.name)
				continue
			layer = zmap.Layer.values()[idx]

		var layer_idx := zmap_file.get_layer_index(layer)
		child.z_index = 0  # 不使用 z_index，避免污染 actor 间排序
		child_layers.append({"node": child, "layer_idx": layer_idx})

	# 按 layer_idx 降序排列（layer_idx 大的在下层，layer_idx 小的在上层）
	child_layers.sort_custom(func(a, b): return a.layer_idx > b.layer_idx)

	# 按排序结果移动节点（index 0 在底层，index 最大在上层）
	for i in child_layers.size():
		var child: Node = child_layers[i].node
		move_child(child, i)


# ============================================================
#  公开接口 —— 由 CharacterBody 统一驱动
# ============================================================

## CharacterBody 调用：为单个部件配置 source_item 并构建 SpriteFrames
func configure_part(part: VisualItemPart, visual_item: VisualItem) -> void:
	if part == null or visual_item == null:
		return

	part.source_item = visual_item
	part.外部动画控制 = true

	# 补连信号
	if not part.frame_changed.is_connected(part._on_frame_changed):
		part.frame_changed.connect(part._on_frame_changed)
	if not part.animation_changed.is_connected(part._on_animation_changed):
		part.animation_changed.connect(part._on_animation_changed)

	_setup_part(part)


## CharacterBody 调用（Animation 模式）：仅为部件构建 SpriteFrames，不应用默认帧
func build_part_sprite_frames(part: VisualItemPart) -> void:
	if part == null or part.source_item == null:
		return
	if not part.frame_changed.is_connected(part._on_frame_changed):
		part.frame_changed.connect(part._on_frame_changed)
	if not part.animation_changed.is_connected(part._on_animation_changed):
		part.animation_changed.connect(part._on_animation_changed)
	part.外部动画控制 = true

	var config_path: String = part.source_item.get_anim_config_path()
	if config_path.is_empty():
		return

	var data := _load_json_config(config_path)
	if data.is_empty():
		return

	# 填充 part 的配置缓存
	if part._config_data.is_empty():
		part._config_data = data
		part._config_path = config_path

	_build_sprite_frames(part, data, part.part_name)


## CharacterBody 调用：从 JSON 配置提取所有 sprite 名到 z 层级字符串的映射
## 返回 {sprite_name: z_string}，如 {"head": "head", "body": "body"}
## 读取首个动画首帧的 spritecfg[]
func get_sprite_z_map(config_path: String) -> Dictionary:
	var data := _load_json_config(config_path)
	if data.is_empty():
		return {}

	var z_map: Dictionary = {}
	for anim_cfg in data.get("animCfg", []):
		var frames: Array = anim_cfg.get("frames", [])
		if frames.is_empty():
			continue
		for sprite_cfg in frames[0].get("spritecfg", []):
			var sname: String = sprite_cfg.get("name", "")
			if sname.is_empty() or z_map.has(sname):
				continue
			var z_str: String = sprite_cfg.get("z", "")
			if z_str.is_empty():
				continue
			z_map[sname] = z_str
		break

	return z_map


# ============================================================
#  SpriteFrames 构建管线
# ============================================================

func _setup_part(part: VisualItemPart, config_data_override: Dictionary = {}) -> void:
	"""为单个 VisualItemPart 构建 SpriteFrames 并应用默认动画首帧

	config_data_override：当 part 自身 _ready() 因 source_item 未就绪而未能加载配置时，
	由调用方传入已加载的 JSON 数据，注入到 part._config_data 以支持后续 set_origin/set_bone。
	"""
	if part.source_item == null:
		return

	var config_path: String = part.source_item.get_anim_config_path()
	if config_path.is_empty():
		return

	var data := config_data_override if not config_data_override.is_empty() else _load_json_config(config_path)
	if data.is_empty():
		return

	var part_name: String = part.part_name

	# 填充 part 的配置缓存（补丁：_ready() 时 source_item 可能尚未设置）
	if part._config_data.is_empty() and not data.is_empty():
		part._config_data = data
		part._config_path = config_path

	# 1. 从配置重建 SpriteFrames（含 FrameLink 纹理解析）
	_build_sprite_frames(part, data, part_name)

	# 2. 应用默认动画的首帧视觉效果
	var default_anim: String = part.source_item.default_action
	if not default_anim.is_empty():
		_apply_default_first_frame(part, data, part_name, default_anim)


# ---- JSON 配置加载与缓存 ----

func _load_json_config(path: String) -> Dictionary:
	"""加载 JSON 配置文件，带缓存"""
	if path.is_empty():
		return {}

	if _config_cache.has(path):
		return _config_cache[path]

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("视觉管线: 无法打开配置文件 %s" % path)
		_config_cache[path] = {}
		return {}

	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		push_error("视觉管线: JSON 解析失败 %s" % path)
		data = {}

	_config_cache[path] = data
	return data


## 按 config_id 加载目标配置（用于 FrameLink 解析）
func _load_json_config_by_id(config_id: String, base_path: String) -> Dictionary:
	if _config_cache.has(config_id):
		return _config_cache[config_id]

	var target_path := base_path.get_base_dir().path_join(config_id + ".json")
	var data := _load_json_config(target_path)
	_config_cache[config_id] = data
	return data


# ---- SpriteFrames 构建 ----

func _build_sprite_frames(part: VisualItemPart, data: Dictionary, part_name: String) -> void:
	"""从配置数据构建 SpriteFrames 资源

	遍历所有动画及其帧，提取本部件的纹理。
	- .Sprite：直接加载 spriteDir
	- .FrameLink：解析链接，从目标配置获取纹理
	"""
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")  # Godot 4 的 SpriteFrames.new() 自带 "default" 动画，先移除
	var config_path: String = part.source_item.get_anim_config_path()

	for anim_cfg in data.get("animCfg", []):
		var anim_name: String = anim_cfg.get("name", "")
		var frames: Array = anim_cfg.get("frames", [])

		var textures: Array[Texture2D] = []
		for frame_data in frames:
			var tex := _resolve_frame_texture(frame_data, part_name, config_path)
			textures.append(tex)

		# 跳过全为空帧的动画
		var valid_textures := textures.filter(func(t): return t != null)
		if valid_textures.is_empty():
			continue

		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		for tex in valid_textures:
			sf.add_frame(anim_name, tex, 1.0)

	part.sprite_frames = sf


func _resolve_frame_texture(frame_data: Dictionary, part_name: String, base_path: String) -> Texture2D:
	"""从帧的 spritecfg 中提取本部件的纹理。处理 .Sprite 和 .FrameLink 两种类型"""
	for sprite_cfg in frame_data.get("spritecfg", []):
		var stype: String = sprite_cfg.get("$type", "")
		if sprite_cfg.get("name", "") != part_name:
			continue

		if stype.ends_with(".Sprite"):
			var tex_path: String = sprite_cfg.get("spriteDir", "")
			if not tex_path.is_empty():
				var tex := load(tex_path) as Texture2D
				if tex == null:
					push_warning("视觉管线: 无法加载纹理 %s" % tex_path)
				return tex

		elif stype.ends_with(".FrameLink"):
			return _resolve_framelink_texture(sprite_cfg, base_path)

	return null


# ---- FrameLink 纹理解析 ----

func _resolve_framelink_texture(link_cfg: Dictionary, base_path: String) -> Texture2D:
	"""解析 FrameLink，获取目标 Sprite 的实际纹理

	FrameLink 结构：{ name, id, animName, frameIndex, spriteName }
	"""
	var link_id: String = link_cfg.get("id", "")
	var link_anim: String = link_cfg.get("animName", "")
	var link_frame: int = link_cfg.get("frameIndex", 0)
	var link_sprite: String = link_cfg.get("spriteName", link_cfg.get("name", ""))

	if link_id.is_empty() or link_anim.is_empty():
		return null

	var target_config := _load_json_config_by_id(link_id, base_path)
	if target_config.is_empty():
		return null

	# 查找目标动画
	var target_anim: Dictionary = {}
	for anim_cfg in target_config.get("animCfg", []):
		if anim_cfg.get("name") == link_anim:
			target_anim = anim_cfg
			break
	if target_anim.is_empty():
		return null

	# 查找目标帧
	var target_frames: Array = target_anim.get("frames", [])
	if link_frame >= target_frames.size():
		return null

	# 在目标帧中查找 spriteName 匹配的 .Sprite
	for sprite_cfg in target_frames[link_frame].get("spritecfg", []):
		if sprite_cfg.get("$type", "").ends_with(".Sprite") and sprite_cfg.get("name", "") == link_sprite:
			var tex_path: String = sprite_cfg.get("spriteDir", "")
			if not tex_path.is_empty():
				var tex := load(tex_path) as Texture2D
				if tex == null:
					push_warning("视觉管线: FrameLink 无法加载纹理 %s" % tex_path)
				return tex

	return null


# ---- 默认动画首帧应用 ----

func _apply_default_first_frame(part: VisualItemPart, data: Dictionary, part_name: String, anim_name: String) -> void:
	"""应用默认动画的首帧：设置 animation 和 frame，并触发一次 set_origin/set_bone"""
	# 确保 SpriteFrames 中有此动画
	if part.sprite_frames == null or not part.sprite_frames.has_animation(anim_name):
		return

	# 先设 animation，再设 frame=0 —— frame_changed 信号会触发 set_origin+set_bone
	part.animation = anim_name
	part.frame = 0
