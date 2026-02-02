extends Area2D
class_name HitboxComponent

var 命中伤害: float = 2.0
var disable_on_source_die: bool = false
@export var source:Node2D = null # 源对象，可能不是owner


func _ready() -> void:
	if source != null and disable_on_source_die:
		if source.has_signal("死亡"):
			source.connect("死亡", Callable(self, "disable"))

signal 击中目标(target:HurtboxComponent)


func enable() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
func disable() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func 检查可用性() -> bool:
	if disable_on_source_die:
		if source == null:
			disable()
			return false
		if source.get("当前状态") == source.角色状态.死亡:
			disable()
			return false
	return true

func _on_area_entered(area: Area2D) -> void:
	if not 检查可用性():
		return
	if area is HurtboxComponent:
		emit_signal("击中目标", area as HurtboxComponent)
		# 仅打印玩家的击中信息
		if source.is_in_group("player"):
			print("%s 击中 %s" % [source.name, (area as HurtboxComponent).owner.name])
