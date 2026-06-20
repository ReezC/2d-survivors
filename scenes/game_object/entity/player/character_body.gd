extends Node2D
class_name CharacterBody
## 角色身体控制器 —— 负责构建纸娃娃视觉系统和骨骼树
##
## 挂载在角色根节点下，通过 @export 指定身体和头部配置
## 在 _ready 时自动构建视觉节点和骨骼树

@export var 角色身体: VisualItem
@export var 角色头部: VisualItem
@export_file("*.json") var 自定义视觉配置: Array[String] = []

## 测试开关：禁用纸娃娃渲染，回退到旧版精灵动画系统
@export var 禁用纸娃娃渲染: bool = false

var animator: PaperDollAnimator
var builder: PaperDollBuilder


func _ready() -> void:
	if 角色身体 == null:
		push_error("CharacterBody: 未指定角色身体")
		return

	if 禁用纸娃娃渲染:
		return

	# 创建纸娃娃动画控制器
	animator = PaperDollAnimator.new()
	animator.name = "PaperDollAnimator"
	add_child(animator)

	# 构建器（子节点渲染顺序由 视觉.gd 按 zmap 管理）
	builder = animator._builder
	builder.build(get_parent())

	# 加载身体配置
	builder.add_part_config(角色身体.动画帧配置文件)

	# 加载头部配置（如果指定了）
	if 角色头部 != null:
		builder.add_part_config(角色头部.动画帧配置文件)

	# 加载自定义视觉配置（如武器、特效、披风等）
	for custom_config in 自定义视觉配置:
		if not custom_config.is_empty():
			builder.add_part_config(custom_config)

	animator.build_finish()

	# 纸娃娃系统已完全接管动画，禁用旧版 AnimationTree/AnimationPlayer
	var player_root := get_parent()
	if player_root:
		var at := player_root.get_node_or_null("AnimationTree") as AnimationTree
		if at:
			at.active = false
		var ap := player_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if ap:
			ap.stop()

	# 初始动画
	animator.set_animation_by_state(0)  # 待机


func set_animation_state(state: int) -> void:
	if animator:
		animator.set_animation_by_state(state)


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
