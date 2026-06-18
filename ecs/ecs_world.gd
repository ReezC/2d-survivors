extends Node

## ECS 世界管理器
## Autoload 单例，统一管理 EntityManager 和所有 System
## 注意：不声明 class_name，因为此脚本作为 Autoload 注册（名称 ECSWorld），
## class_name 会与 Autoload 单例冲突导致 LSP 警告。

var entity_manager: EntityManager
var skill_system: SkillSystem
var buff_system: BuffSystem
var subobject_system: SubObjectSystem

func _ready() -> void:
	entity_manager = EntityManager.new()
	entity_manager.name = "EntityManager"
	add_child(entity_manager)
	
	# 创建所有 System
	skill_system = SkillSystem.new(entity_manager)
	buff_system = BuffSystem.new(entity_manager)
	subobject_system = SubObjectSystem.new(entity_manager)
	
	# 建立 System 之间的引用
	skill_system.buff_system = buff_system
	skill_system.subobject_system = subobject_system
	buff_system.skill_system = skill_system
	buff_system.subobject_system = subobject_system
	subobject_system.skill_system = skill_system

func _process(delta: float) -> void:
	if skill_system:
		skill_system.update(delta)
	if buff_system:
		buff_system.update(delta)
	if subobject_system:
		subobject_system.update(delta)

## 为 Unit 注册技能
func register_unit_skills(unit: Node, skill_data_list: Array) -> void:
	if skill_system:
		skill_system.register_entity(unit, skill_data_list)

## 销毁 Entity（Unit 死亡时调用）
func destroy_entity(entity_id: int) -> void:
	var unit_name = _get_entity_name(entity_id)
	if subobject_system:
		var cleaned = subobject_system.cleanup_entity_objects(entity_id)
		if cleaned > 0:
			GMLogger.log_ecs("[%s] 清理 %d 个子物体" % [unit_name, cleaned])
	if entity_manager:
		entity_manager.destroy_entity(entity_id)
	GMLogger.log_ecs("[%s] 实体已加入销毁队列" % unit_name)

func _get_entity_name(entity_id: int) -> String:
	var unit = entity_manager.get_unit(entity_id)
	if unit == null:
		return "entity=%d" % entity_id
	if unit.has_method("get") and "unit_name" in unit:
		return "%s (entity=%d)" % [unit.unit_name, entity_id]
	return "%s (entity=%d)" % [unit.name, entity_id]
