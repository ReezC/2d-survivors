# DamageText.gd
extends Node2D
class_name	新跳字方案
enum DamageType {
	PLAYER_NORMAL,      # 玩家普通伤害
	PLAYER_CRITICAL,    # 玩家暴击伤害
	ENEMY_NORMAL,       # 怪物普通伤害
	DODGE,              # 闪避
	BLOCK               # 格挡
}


@export var text: String = "0"
@export var damage_type: DamageType = DamageType.PLAYER_NORMAL
@export var font_size: int = 24
@export var duration: float = 1.0
@export var float_height: float = 50.0

@onready var label: Label = $Label
@onready var tween: Tween = create_tween()

# 颜色配置
const COLOR_PLAYER_NORMAL = Color("#FFD700")  # 明黄色
const COLOR_PLAYER_CRITICAL = Color("#FF4500")  # 炽红色
const COLOR_ENEMY_NORMAL = Color("#8A2BE2")  # 暗紫色
const COLOR_DODGE_BLOCK = Color("#708090")  # 灰蓝色，半透明

func _ready():
	setup_damage_text()
	start_animation()

func setup_damage_text():
	# 设置文本
	label.text = text
	
	# 根据伤害类型设置样式
	match damage_type:
		DamageType.PLAYER_NORMAL:
			label.add_theme_color_override("font_color", COLOR_PLAYER_NORMAL)
			label.add_theme_color_override("font_outline_color", Color.WHITE)
			label.add_theme_constant_override("outline_size", 2)
			
		DamageType.PLAYER_CRITICAL:
			label.add_theme_color_override("font_color", COLOR_PLAYER_CRITICAL)
			label.add_theme_color_override("font_outline_color", Color.ORANGE_RED)
			label.add_theme_constant_override("outline_size", 3)
			label.add_theme_font_size_override("font_size", font_size + 8)
			add_shake_effect()
			
		DamageType.ENEMY_NORMAL:
			label.add_theme_color_override("font_color", COLOR_ENEMY_NORMAL)
			label.add_theme_constant_override("outline_size", 1)
			
		DamageType.DODGE, DamageType.BLOCK:
			label.add_theme_color_override("font_color", COLOR_DODGE_BLOCK)
			label.add_theme_constant_override("outline_size", 1)
			label.modulate.a = 0.7
			text = "闪避" if damage_type == DamageType.DODGE else "格挡"

func start_animation():
	# 向上浮动动画
	tween.tween_property(self, "position:y", 
		position.y - float_height, duration)
	
	# 淡出动画
	tween.parallel().tween_property(label, "modulate:a", 0, duration)
	
	# 暴击特效的缩放动画
	if damage_type == DamageType.PLAYER_CRITICAL:
		tween.parallel().tween_property(label, "scale", 
			Vector2(1.5, 1.5), 0.1)
		tween.parallel().tween_property(label, "scale", 
			Vector2.ONE, 0.2).set_delay(0.1)
	
	# 闪避/格挡的碎裂效果
	if damage_type == DamageType.DODGE or damage_type == DamageType.BLOCK:
		tween.parallel().tween_property(label, "rotation", 
			randf_range(-0.2, 0.2), duration)
	
	# 动画完成后销毁
	tween.tween_callback(queue_free)

func add_shake_effect():
	# 暴击的震动效果
	var original_pos = position
	for i in range(4):
		tween.parallel().tween_property(self, "position:x", 
			original_pos.x + randf_range(-3, 3), 0.05).set_delay(i * 0.05)
