extends Area2D
class_name HitboxComponent

var 命中伤害: float = 23.0
@export var source:Node2D = null # 源对象，可能不是owner


signal 击中目标(target:HurtboxComponent)


func enable() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
func disable() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)




func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		emit_signal("击中目标", area as HurtboxComponent)
		# 仅打印玩家的击中信息
		if source.is_in_group("player"):
			print("%s 击中 %s" % [source.name, (area as HurtboxComponent).owner.name])