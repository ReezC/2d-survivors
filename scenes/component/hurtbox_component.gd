extends Area2D
class_name HurtboxComponent

#@export var health_component:Node
# @onready var 单位属性component:Node

signal 被击中(hitbox:HitboxComponent)

## 当前Area2D触发时调用
func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		emit_signal("被击中", area as HitboxComponent)
		# 仅打印玩家的被击中信息
		if owner.is_in_group("player"):
			print("%s 被 %s 击中" % [owner.name, (area as HitboxComponent).owner.name])
