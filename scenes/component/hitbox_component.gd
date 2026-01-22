extends Area2D
class_name HitboxComponent

var 命中伤害: float = 1.0
var source:Node2D # 源对象

@export var 战斗事件判定 = {
	'暴击':false,
	'格挡':false
}

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
		if owner.is_in_group("player"):
			print("%s 击中 %s" % [owner.name, (area as HurtboxComponent).owner.name])
