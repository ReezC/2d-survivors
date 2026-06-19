extends Area2D
class_name HitboxComponent

var 命中伤害: float = 0.0
var disable_on_source_die: bool = false
## 施法者 entity ID（替代原来的 source Node2D 引用）
var source_entity: int = -1
## EntityManager 引用（由 SubObjectSystem 注入）
var _entity_manager: EntityManager = null
## 碰撞重置间隔，单位秒。若>0，则hitbox在碰撞后保持关闭此时间后才重新启用
@export var collide_reset_interval: float = 0.0
## 碰撞后执行的动作配置（由技能配置决定）
## 当不为空时，碰撞后不再默认走伤害流程，而是执行配置的动作
## 例如: {"$type": "skillconfig.SkillAction.Damage"}
var collide_action: Dictionary = {} 

## 获取施法者 Node（仅在需要访问场景树时使用）
func get_source_node() -> Node2D:
	if _entity_manager and source_entity > 0:
		return _entity_manager.get_unit(source_entity) as Node2D
	return null

func _ready() -> void:
	if disable_on_source_die:
		var src = get_source_node()
		if src and src.has_signal("死亡"):
			src.connect("死亡", Callable(self, "disable"))

signal 击中目标(target:HurtboxComponent)


func enable() -> void:
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
func disable() -> void:
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func 检查可用性() -> bool:
	if disable_on_source_die:
		var src = get_source_node()
		if src == null:
			disable()
			return false
		if src.has_method("get") and "当前状态" in src and "角色状态" in src:
			if src.当前状态 == src.角色状态.死亡:
				disable()
				return false
	
	# 通过 entity 读取攻击力属性
	# TODO当前伤害只取攻击力属性，后续可扩展为技能伤害、元素伤害等多种类型
	if _entity_manager and source_entity > 0:
		var attr_comp = _entity_manager.get_component(source_entity, ECSComponentTypes.ComponentType.ATTRIBUTE)
		if attr_comp and attr_comp.has_method("获取属性值"):
			命中伤害 = attr_comp.获取属性值("攻击力")
		else:
			var src_node = get_source_node()
			if src_node and "attribute_component" in src_node:
				命中伤害 = src_node.attribute_component.获取属性值("攻击力")
	else:
		var src_node = get_source_node()
		if src_node and "attribute_component" in src_node:
			命中伤害 = src_node.attribute_component.获取属性值("攻击力")
	
	return true

func _on_area_entered(area: Area2D) -> void:
	if not 检查可用性():
		return
	if area is HurtboxComponent:
		emit_signal("击中目标", area as HurtboxComponent)
		var src = get_source_node()
		if src and src.is_in_group("player"):
			GMLogger.log_damage("%s 击中 %s" % [src.name, (area as HurtboxComponent).owner.name])
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
