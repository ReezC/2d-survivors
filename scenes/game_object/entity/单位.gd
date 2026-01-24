extends CharacterBody2D
class_name Unit


@onready var 视觉: Node2D = %视觉
@onready var animated_sprite_2d: AnimatedSprite2D = $视觉/AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: HealthBar = $HealthBar
@onready var 受击闪白效果timer: Timer = $受击闪白效果Timer

@export var 单位属性: UnitStats

func _ready() -> void:
	health_component.setup(单位属性)

func 设置受击闪白material(闪白material:ShaderMaterial) -> void:
	animated_sprite_2d.material = 闪白material
	if 受击闪白效果timer.is_stopped():
		受击闪白效果timer.start()
	

## 被击中事件处理
## 
## 暴击、闪避等战斗事件的判定在此处进行
## 采用归一圆桌算法：
## 	分子 = 当前判定的战斗事件概率
## 	分母 = min(各时间概率之和, 1.0)
## 
## @param hitbox: HitboxComponent
func _on_hurtbox_component_被击中(hitbox: HitboxComponent) -> void:
	if hitbox.命中伤害 > 0:
		# 判定伤害事件
		var 格挡率 = 单位属性.格挡率
		var 闪避率 = 单位属性.闪避率



		health_component.受到伤害(hitbox.命中伤害)
		设置受击闪白material(GameEvents.受击闪白material)


func _on_受击闪白效果timer_timeout() -> void:
	animated_sprite_2d.material = null
