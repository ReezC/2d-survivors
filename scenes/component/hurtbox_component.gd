extends Area2D
class_name HurtboxComponent

@export var health_component:Node
@onready var 单位属性component:Node

signal 被击中(hitbox:HitboxComponent)

#func _ready() :
	#area_entered.connect(on_area_entered)
	#
#
#func on_area_entered(area:Area2D) -> void:
	#if not area is HitboxComponent:
		#return
	#if health_component == null:
		#return
	#var hitbox_component = area as HitboxComponent
	#health_component.damage(hitbox_component.damage_amount)
	#print("%s受到 %d 点伤害，剩余生命： %s/%s" % [owner.name, hitbox_component.damage_amount, health_component.max_health - health_component.current_health, health_component.max_health])
	#单位属性component = owner.get_node("单位属性Component")
	#print("%d / %d" % [单位属性component.获取属性值("生命"),单位属性component.获取属性值("最大生命值")])

## 当前Area2D触发时调用
func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		emit_signal("被击中", area as HitboxComponent)
		# 仅打印玩家的被击中信息
		if owner.is_in_group("player"):
			print("%s 被 %s 击中" % [owner.name, (area as HitboxComponent).owner.name])
