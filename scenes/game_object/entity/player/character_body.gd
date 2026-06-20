extends Node2D
class_name CharacterBody
## 角色身体控制器 —— 统一管理纸娃娃/Animation 双模式渲染数据
##
## 挂载在角色根节点下。通过 装备槽位 配置各个 slot 对应的 VisualItem，
## 每个 islot 通过 @export 数组直接绑定 视觉 下的预制 VisualItemPart 节点。
## 当装备变更时自动检测部件是否匹配并驱动 视觉.gd 重构 SpriteFrames。

## 装备槽位配置，将 islot（Bd/Hd/Wp/...）与 VisualItem 配对
@export var 装备槽位: EquipSlotConfig

## 测试开关：禁用纸娃娃渲染，回退到旧版精灵动画系统
@export var 禁用纸娃娃渲染: bool = false

# ============================================================
#  部件绑定 —— 手动将 视觉 下的预制 VisualItemPart 拖入对应槽位
#  部件叫什么名字无所谓，只要绑定到对应 islot 即可
# ============================================================

@export var Bd_身体部件列表: Array[Node]	# 对应 islot_enum.Bd
@export var Hd_头部部件列表: Array[Node]	# 对应 islot_enum.Hd
@export var Hr_发型部件列表: Array[Node]	# 对应 islot_enum.Hr
@export var Fc_脸型部件列表: Array[Node]	# 对应 islot_enum.Fc
@export var Af_脸饰部件列表: Array[Node]	# 对应 islot_enum.Af
@export var Ae_耳环部件列表: Array[Node]	# 对应 islot_enum.Ae
@export var Ay_眼饰部件列表: Array[Node]	# 对应 islot_enum.Ay
@export var Cp_帽子部件列表: Array[Node]	# 对应 islot_enum.Cp
@export var Ri_戒指部件列表: Array[Node]	# 对应 islot_enum.Ri
@export var Gv_手套部件列表: Array[Node]	# 对应 islot_enum.Gv
@export var Wp_武器部件列表: Array[Node]	# 对应 islot_enum.Wp
@export var Si_盾牌部件列表: Array[Node]	# 对应 islot_enum.Si
@export var So_鞋子部件列表: Array[Node]	# 对应 islot_enum.So
@export var Pn_下装部件列表: Array[Node]	# 对应 islot_enum.Pn
@export var Ma_上衣部件列表: Array[Node]	# 对应 islot_enum.Ma
@export var Sr_披风部件列表: Array[Node]	# 对应 islot_enum.Sr
@export var Tm_坐骑部件列表: Array[Node]	# 对应 islot_enum.Tm
@export var Sd_鞍子部件列表: Array[Node]	# 对应 islot_enum.Sd
@export var Sh_肩饰部件列表: Array[Node]	# 对应 islot_enum.Sh
@export var Bi_拼图部件列表: Array[Node]	# 对应 islot_enum.Bi
@export var Ba_徽章部件列表: Array[Node]	# 对应 islot_enum.Ba
@export var Me_勋章部件列表: Array[Node]	# 对应 islot_enum.Me
@export var Pe_坠子部件列表: Array[Node]	# 对应 islot_enum.Pe
@export var Po_口袋部件列表: Array[Node]	# 对应 islot_enum.Po
@export var Ss_技能皮肤部件列表: Array[Node]	# 对应 islot_enum.Ss

var animator: PaperDollAnimator
var builder: PaperDollBuilder

## 视觉容器节点引用
var _visual_node: Node2D

## islot_enum → Array[Node] 快速查询映射（_ready() 时构建）
var _slot_part_map: Dictionary = {}

## 记录每个槽位上一次使用的配置路径，用于变更检测
var _slot_config_paths: Dictionary = {}  # islot_enum → String


func _ready() -> void:
	if 装备槽位 == null:
		push_error("CharacterBody: 未配置装备槽位")
		return

	var player_root := get_parent()
	_visual_node = _find_visual()

	# 构建 islot_enum → Array[Node] 映射表
	_build_slot_part_map()

	if 禁用纸娃娃渲染:
		_build_animation_rendering(player_root)
	else:
		_enable_paper_doll_rendering(player_root)
		_apply_all_slot_rendering()


# ============================================================
#  Animation 渲染模式 —— 六步构建流程
# ============================================================

## 步进时间常量（每帧时长，秒）
const _STEP_TIME := 0.15

var _zmap_ref: zmap = null  # zmap 引用缓存


func _build_animation_rendering(player_root: Node) -> void:
	"""Animation 渲染模式主流程：

	1. 清空视觉下旧部件
	2. 按 EquipSlotConfig 创建新部件
	3. 按 zmap 排序
	4. 为每个部件构建 SpriteFrames
	5. 按 islot 顺序初始化默认动画首帧（构建骨骼）
	6. 重建 AnimationPlayer（stand1 乒乓循环处理）
	"""
	if _visual_node == null:
		return

	_clear_visual_parts()
	var parts := _create_parts_from_config()
	_sort_parts_by_zmap(parts)

	# 确保 body 骨骼根节点存在（Animation 模式下纸娃娃系统不会创建它）
	if player_root.get_node_or_null("body") == null:
		var body_bone := Node2D.new()
		body_bone.name = "body"
		player_root.add_child(body_bone)

	_init_all_parts(parts)
	_rebuild_animation_player(player_root, parts)


func _get_zmap() -> zmap:
	if _zmap_ref == null and _visual_node and "zmap_file" in _visual_node:
		_zmap_ref = _visual_node.zmap_file as zmap
	return _zmap_ref


func _z_string_to_layer(z_str: String) -> int:
	"""将 sprite 配置中的 z 字符串（如 'head', 'body'）转为 zmap.Layer 索引值"""
	var keys := zmap.Layer.keys()
	var idx := keys.find(z_str)
	if idx >= 0:
		return zmap.Layer.values()[idx]
	return -1  # 未找到


func _z_layer_index(z_str: String) -> int:
	"""获取 z 字符串对应的 zmap 排序索引（数字越大越在上层）"""
	var zmap_ref := _get_zmap()
	if zmap_ref == null:
		return -1
	var keys := zmap.Layer.keys()
	var idx := keys.find(z_str)
	if idx >= 0:
		return zmap_ref.get_layer_index(zmap.Layer.values()[idx])
	return -1


# ---------------- 步骤 1：清空旧部件 ----------------

func _clear_visual_parts() -> void:
	if _visual_node == null:
		return
	for child in _visual_node.get_children():
		child.queue_free()


# ---------------- 步骤 2：按 EquipSlotConfig 创建新部件 ----------------

func _create_parts_from_config() -> Array[VisualItemPart]:
	"""遍历 EquipSlotConfig，为每个 islot 的 VisualItem 创建对应部件

	从 JSON 配置中提取 sprite 名和 z 层级，创建 VisualItemPart 节点挂在 视觉 下。
	返回创建的所有部件列表。
	"""
	var created: Array[VisualItemPart] = []
	var _seen: Dictionary = {}  # part_name → true 去重（多个 islot 可能引用同一部件名）

	for slot_name in EquipSlotConfig.islot_enum:
		var slot_key: int = EquipSlotConfig.islot_enum[slot_name]
		var visual_item: VisualItem = 装备槽位.islot.get(slot_key)
		if visual_item == null:
			continue

		var config_path: String = visual_item.动画帧配置文件
		if config_path.is_empty():
			continue

		var z_map: Dictionary
		if _visual_node and _visual_node.has_method(&"get_sprite_z_map"):
			z_map = _visual_node.get_sprite_z_map(config_path)
		if z_map.is_empty():
			continue

		for sprite_name in z_map:
			if _seen.has(sprite_name):
				continue
			_seen[sprite_name] = true

			var part := VisualItemPart.new()
			part.name = sprite_name + "_" + visual_item.item_name + "_" + visual_item.id
			part.part_name = sprite_name
			part.source_item = visual_item
			part.外部动画控制 = true

			# 从 z 字符串映射到 zmap.Layer
			var z_str: String = z_map[sprite_name]
			var layer_val: int = _z_string_to_layer(z_str)
			if layer_val >= 0:
				part.z = layer_val as zmap.Layer

			_visual_node.add_child(part)
			created.append(part)

	return created


# ---------------- 步骤 3：按 zmap 排序部件 ----------------

func _sort_parts_by_zmap(parts: Array[VisualItemPart]) -> void:
	"""按每个部件的 z（zmap.Layer）排序：layer 索引大的在下层，小的在上层"""
	var zmap_ref := _get_zmap()
	if zmap_ref == null:
		return

	# layer_idx 大的排在底层（子节点 index 小），小的排在上层（index 大）
	parts.sort_custom(func(a: VisualItemPart, b: VisualItemPart):
		return zmap_ref.get_layer_index(a.z) > zmap_ref.get_layer_index(b.z)
	)

	for i in parts.size():
		_visual_node.move_child(parts[i], i)


# ---------------- 步骤 4 + 5：构建 SpriteFrames + 初始化 ----------------

func _init_all_parts(parts: Array[VisualItemPart]) -> void:
	"""先为所有部件构建 SpriteFrames，再按 islot 顺序初始化默认动画首帧"""
	# 4. 为每个部件构建 SpriteFrames
	for part in parts:
		if _visual_node and _visual_node.has_method(&"build_part_sprite_frames"):
			_visual_node.build_part_sprite_frames(part)

	# 5. 按 islot 声明顺序初始化（构建骨骼）
	for slot_name in EquipSlotConfig.islot_enum:
		var slot_key: int = EquipSlotConfig.islot_enum[slot_name]
		var visual_item: VisualItem = 装备槽位.islot.get(slot_key)
		if visual_item == null:
			continue
		var default_anim: String = visual_item.默认动画名称
		if default_anim.is_empty():
			continue
		for part in parts:
			if part.source_item == visual_item:
				if part.sprite_frames and part.sprite_frames.has_animation(default_anim):
					part.animation = default_anim
					part.frame = 0


# ---------------- 步骤 6：重建 AnimationPlayer ----------------

func _rebuild_animation_player(player_root: Node, parts: Array[VisualItemPart]) -> void:
	"""自下而上遍历 视觉 下的部件，收集所有动画名，为 AnimationPlayer 重建轨道

	stand1 动画默认乒乓循环：loop_mode=1，帧序列后追加倒序（不含首帧）
	例：0,1,2 → 轨道顺序 0,1,2,1
	"""
	if player_root == null:
		return

	var ap := player_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		push_warning("CharacterBody: 未找到 AnimationPlayer")
		return

	# 收集所有动画名 → 哪些部件参与此动画
	var anim_to_parts: Dictionary = {}  # String → Array[VisualItemPart]
	for part in parts:
		if part.sprite_frames == null:
			continue
		for anim_name in part.sprite_frames.get_animation_names():
			if not anim_to_parts.has(anim_name):
				anim_to_parts[anim_name] = []
			anim_to_parts[anim_name].append(part)

	# 获取或创建默认动画库（Godot 4 要求通过 AnimationLibrary 管理动画）
	# 清理旧动画数据，避免 tscn 残留的轨道（如 RESET）报 unresolved track 警告
	var lib: AnimationLibrary
	if ap.has_animation_library(&""):
		lib = ap.get_animation_library(&"")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library(&"", lib)
	# 清除库中所有旧动画，完全重建
	for old_anim_name in lib.get_animation_list():
		lib.remove_animation(old_anim_name)

	# 自下而上：视觉下 index 小的在下层（先创建轨道），大的在上层（后覆盖排序）
	# 按部件在 视觉 中的子节点顺序（已按 zmap 排好序）遍历
	for anim_name in anim_to_parts:
		var anim: Animation
		if ap.has_animation(anim_name):
			anim = ap.get_animation(anim_name)
			# 清空旧轨道
			for i in range(anim.get_track_count() - 1, -1, -1):
				anim.remove_track(i)
		else:
			anim = Animation.new()
			anim.length = 0.0
			lib.add_animation(anim_name, anim)

		var is_stand1: bool = (anim_name == "stand1")

		# 计算最大帧数
		var max_frames: int = 0
		for part in anim_to_parts[anim_name]:
			var fc: int = part.sprite_frames.get_frame_count(anim_name)
			if fc > max_frames:
				max_frames = fc

		if max_frames == 0:
			continue

		# 设置动画长度和循环模式
		if is_stand1:
			# 乒乓：帧数 * 2 - 1 个步进（不含首帧重复）
			anim.length = (max_frames * 2 - 2) * _STEP_TIME
			anim.loop_mode = Animation.LOOP_PINGPONG
		else:
			anim.length = (max_frames - 1) * _STEP_TIME
			anim.loop_mode = Animation.LOOP_LINEAR

		# 为每个参与部件添加轨道
		for part in anim_to_parts[anim_name]:
			var node_path_str: String = "视觉/" + part.name

			# animation 属性轨道（用 METHOD 轨道调用 apply_animation，避免字符串 blend 警告）
			var anim_track: int = anim.add_track(Animation.TYPE_METHOD)
			anim.track_set_path(anim_track, NodePath(node_path_str + ":apply_animation"))
			anim.track_insert_key(anim_track, 0.0, {&"method": &"apply_animation", &"args": [anim_name]})

			# frame 属性轨道（整数——离散值，不参与 blend）
			var frame_track: int = anim.add_track(Animation.TYPE_VALUE)
			anim.track_set_path(frame_track, NodePath(node_path_str + ":frame"))
			anim.track_set_interpolation_type(frame_track, Animation.INTERPOLATION_NEAREST)

			var part_frame_count: int = part.sprite_frames.get_frame_count(anim_name)

			for f in part_frame_count:
				anim.track_insert_key(frame_track, f * _STEP_TIME, f)

			# stand1 乒乓：追加倒序帧（不含首帧和末帧再重复）
			if is_stand1:
				for f in range(part_frame_count - 2, 0, -1):
					var t: float = (max_frames + (part_frame_count - 2 - f)) * _STEP_TIME
					anim.track_insert_key(frame_track, t, f)

	# 启用 AnimationTree
	var at: AnimationTree = player_root.get_node_or_null("AnimationTree") as AnimationTree
	if at:
		at.active = true

	# 确保动画已开始播放（否则 get_current_animation_length 等调用会报错）
	if ap.has_animation("stand1"):
		ap.play("stand1")


func _enable_animation_rendering(player_root: Node) -> void:
	"""旧版入口（已废弃，由 _build_animation_rendering 替代）"""
	_build_animation_rendering(player_root)


func _enable_paper_doll_rendering(player_root: Node) -> void:
	"""纸娃娃渲染模式：清空视觉旧部件，创建 PaperDollAnimator 由 builder 动态创建部件，禁用 Animation"""
	# 0. 先禁用并清除 AnimationPlayer，避免 _update_caches 解析已不存在的节点轨道
	if player_root:
		var ap := player_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			ap.active = false
			ap.stop()
			if ap.has_animation_library(&""):
				var lib := ap.get_animation_library(&"")
				for old_anim in lib.get_animation_list():
					lib.remove_animation(old_anim)

	# 1. 清空视觉下的旧部件（避免 Animation 模式遗留）
	if _visual_node:
		for child in _visual_node.get_children():
			child.queue_free()

	# 2. 创建纸娃娃系统
	animator = PaperDollAnimator.new()
	animator.name = "PaperDollAnimator"
	add_child(animator)

	builder = animator._builder
	builder.build(player_root)

	for visual_item in 装备槽位.islot.values():
		if visual_item == null:
			continue
		builder.add_part_config(visual_item.动画帧配置文件, visual_item)

	animator.build_finish()

	# 3. 禁用 AnimationTree（AnimationPlayer 已在步骤 0 禁用，纸娃娃自行驱动帧切换）
	if player_root:
		var at := player_root.get_node_or_null("AnimationTree") as AnimationTree
		if at:
			at.active = false

	animator.set_animation_by_state(0)


# ============================================================
#  槽位 → 部件 映射（直接使用 @export 数组，不依赖 JSON 匹配）
# ============================================================

func _find_visual() -> Node2D:
	var player_root := get_parent()
	if player_root == null:
		return null
	return player_root.get_node_or_null("视觉") as Node2D


func _build_slot_part_map() -> void:
	"""将 @export 数组按 islot_enum 建立快速查询映射"""
	_slot_part_map = {
		EquipSlotConfig.islot_enum.Bd: Bd_身体部件列表,
		EquipSlotConfig.islot_enum.Hd: Hd_头部部件列表,
		EquipSlotConfig.islot_enum.Hr: Hr_发型部件列表,
		EquipSlotConfig.islot_enum.Fc: Fc_脸型部件列表,
		EquipSlotConfig.islot_enum.Af: Af_脸饰部件列表,
		EquipSlotConfig.islot_enum.Ae: Ae_耳环部件列表,
		EquipSlotConfig.islot_enum.Ay: Ay_眼饰部件列表,
		EquipSlotConfig.islot_enum.Cp: Cp_帽子部件列表,
		EquipSlotConfig.islot_enum.Ri: Ri_戒指部件列表,
		EquipSlotConfig.islot_enum.Gv: Gv_手套部件列表,
		EquipSlotConfig.islot_enum.Wp: Wp_武器部件列表,
		EquipSlotConfig.islot_enum.Si: Si_盾牌部件列表,
		EquipSlotConfig.islot_enum.So: So_鞋子部件列表,
		EquipSlotConfig.islot_enum.Pn: Pn_下装部件列表,
		EquipSlotConfig.islot_enum.Ma: Ma_上衣部件列表,
		EquipSlotConfig.islot_enum.Sr: Sr_披风部件列表,
		EquipSlotConfig.islot_enum.Tm: Tm_坐骑部件列表,
		EquipSlotConfig.islot_enum.Sd: Sd_鞍子部件列表,
		EquipSlotConfig.islot_enum.Sh: Sh_肩饰部件列表,
		EquipSlotConfig.islot_enum.Bi: Bi_拼图部件列表,
		EquipSlotConfig.islot_enum.Ba: Ba_徽章部件列表,
		EquipSlotConfig.islot_enum.Me: Me_勋章部件列表,
		EquipSlotConfig.islot_enum.Pe: Pe_坠子部件列表,
		EquipSlotConfig.islot_enum.Po: Po_口袋部件列表,
		EquipSlotConfig.islot_enum.Ss: Ss_技能皮肤部件列表,
	}


# ============================================================
#  渲染应用
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
	var visual_item: VisualItem = 装备槽位.islot.get(slot_key)
	if visual_item == null:
		return
	var parts: Array = _slot_part_map.get(slot_key, [])
	if parts.is_empty():
		return
	for part in parts:
		if part != null and part is VisualItemPart:
			_visual_node.configure_part(part as VisualItemPart, visual_item)

	# 记录配置路径用于变更检测
	_slot_config_paths[slot_key] = visual_item.动画帧配置文件


# ============================================================
#  运行时装备更换 API
# ============================================================

## 运行时更换装备：更新 islot 字典，检测部件是否匹配，不匹配则按配置重构
func set_slot_item(slot_key: EquipSlotConfig.islot_enum, new_item: VisualItem) -> void:
	if 装备槽位 == null:
		return

	var old_item: VisualItem = 装备槽位.islot.get(slot_key)
	if old_item == new_item:
		return

	装备槽位.islot[slot_key] = new_item

	if new_item == null:
		_slot_config_paths.erase(slot_key)
		return

	_refresh_slot(slot_key)


func _refresh_slot(slot_key) -> void:
	"""检测槽位配置是否变化，变化时重构渲染"""
	var visual_item: VisualItem = 装备槽位.islot.get(slot_key)
	if visual_item == null or _visual_node == null:
		return

	var parts: Array = _slot_part_map.get(slot_key, [])
	if parts.is_empty():
		return

	# 检测配置路径是否变化
	var last_path: String = _slot_config_paths.get(slot_key, "")
	var config_path: String = visual_item.动画帧配置文件

	if config_path != last_path:
		_slot_config_paths[slot_key] = config_path
		if _visual_node.has_method(&"configure_part"):
			for part in parts:
				if part != null and part is VisualItemPart:
					_visual_node.configure_part(part as VisualItemPart, visual_item)


# ============================================================
#  公共查询接口
# ============================================================

func set_animation_state(state: int) -> void:
	if animator:
		animator.set_animation_by_state(state)


## 根据 islot_enum 获取对应槽位的 VisualItem（找不到返回 null）
func get_slot(slot_key: EquipSlotConfig.islot_enum) -> VisualItem:
	if 装备槽位 == null:
		return null
	return 装备槽位.islot.get(slot_key, null)


## 获取某个槽位当前绑定的 VisualItemPart 列表（供外部查询）
func get_slot_parts(slot_key: EquipSlotConfig.islot_enum) -> Array:
	return _slot_part_map.get(slot_key, [])


# 存储碰撞形状的原始位置（首次记录后不再改变），用于翻转时计算新位置
var _original_collision_positions: Dictionary = {}


func set_face_direction(direction: int) -> void:
	"""设置角色朝向：1=右, -1=左"""
	if animator:
		animator.set_face_direction(direction)
	_flip_collision_shapes(direction)


func _flip_collision_shapes(direction: int) -> void:
	"""同步翻转碰撞形状的 x 位置，匹配视觉镜像翻转
	由于视觉通过 scale.x=-1 以 x=0 为轴镜像，碰撞形状也需要将 x 位置镜像
	"""
	var player_root := get_parent()
	if player_root == null:
		return

	# 翻转移动碰撞
	_flip_one_collision(player_root.get_node_or_null("移动碰撞"), direction)

	# 翻转 HurtboxComponent 内的 CollisionShape2D
	var hurtbox := player_root.get_node_or_null("HurtboxComponent")
	if hurtbox:
		_flip_one_collision(hurtbox.get_node_or_null("CollisionShape2D"), direction)


func _flip_one_collision(shape: CollisionShape2D, direction: int) -> void:
	if shape == null:
		return
	var key := str(shape.get_path())
	# 首次记录原始位置，后续取反计算
	if key not in _original_collision_positions:
		_original_collision_positions[key] = shape.position
	var orig := _original_collision_positions[key] as Vector2
	shape.position.x = abs(orig.x) * direction
