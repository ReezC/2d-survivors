extends RefCounted
class_name ECSSystemBase

## ECS System 基类
var entity_manager: EntityManager

func _init(em: EntityManager) -> void:
	entity_manager = em

func update(_delta: float) -> void:
	pass
