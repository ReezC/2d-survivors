extends Node2D
class_name CharacterBody
## 角色身体控制器 —— 负责构建纸娃娃视觉系统和骨骼树
##
## 挂载在角色根节点下，通过 @export 指定身体和头部配置
## 在 _ready 时自动构建视觉节点和骨骼树

@export_file("*.json") var 角色身体配置: String
@export_file("*.json") var 角色头部配置: String
@export_file("*.json") var 自定义视觉配置: Array[String] = [] 

var animator: PaperDollAnimator
var builder: PaperDollBuilder


func _ready() -> void:
	if 角色身体配置.is_empty():
		push_error("CharacterBody: 未指定角色身体配置")
		return

	# 创建纸娃娃动画控制器
	animator = PaperDollAnimator.new()
	animator.name = "PaperDollAnimator"
	add_child(animator)

	# 构建器（子节点渲染顺序由 视觉.gd 按 zmap 管理）
	builder = animator._builder
	builder.build(get_parent())

	# 加载身体配置
	builder.add_part_config(角色身体配置)

	# 加载头部配置（如果指定了）
	if not 角色头部配置.is_empty():
		builder.add_part_config(角色头部配置)

	# 加载自定义视觉配置（如武器、特效、披风等）
	for custom_config in 自定义视觉配置:
		if not custom_config.is_empty():
			builder.add_part_config(custom_config)

	animator.build_finish()

	# 初始动画
	animator.set_animation_by_state(0)  # 待机


func set_animation_state(state: int) -> void:
	if animator:
		animator.set_animation_by_state(state)


func set_face_direction(direction: int) -> void:
	"""设置角色朝向：1=右, -1=左"""
	if animator:
		animator.set_face_direction(direction)
