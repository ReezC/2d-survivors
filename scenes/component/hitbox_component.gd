extends Area2D
class_name HitboxComponent

var 命中伤害: float = 2.0
var disable_on_source_die: bool = false
@export var source:Node2D = null # 源对象，可能不是owner
@export var collide_reset_interval: float = 0.0 # 碰撞重置间隔，单位秒。若>0，则hitbox在碰撞后保持关闭此时间后才重新启用

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
		# 处理命中后逻辑
		if collide_reset_interval > 0.0:
			disable()
			var reset_timer = Timer.new()
			reset_timer.wait_time = collide_reset_interval
			reset_timer.one_shot = true
			reset_timer.timeout.connect(func():
				enable()
				reset_timer.queue_free()
			)
			add_child(reset_timer)
			reset_timer.start()
