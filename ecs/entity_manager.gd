extends Node
class_name EntityManager

## ECS Entity 管理器
## 职责：分配/回收 Entity ID，存储 Component 数据，提供按 Component 类型查询 Entity 的接口

## 核心数据结构
var _next_entity_id: int = 1
var _components: Dictionary = {}  # { "SkillComponent": { entity_id: data }, ... }
var _entity_masks: Dictionary = {}  # { entity_id: int bitmask }
var _entity_to_unit: Dictionary = {}  # { entity_id: Node }  — 反向查找 Unit Node

## 待销毁的 entity 列表（延迟清理）
var _pending_destroy: Array[int] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 创建一个新 Entity，返回 entity_id
func create_entity(unit: Node = null) -> int:
	var eid = _next_entity_id
	_next_entity_id += 1
	_entity_masks[eid] = ECSComponentTypes.ComponentType.NONE
	if unit:
		_entity_to_unit[eid] = unit
	return eid

## 销毁 Entity，清理其所有 Component
func destroy_entity(entity_id: int) -> void:
	_pending_destroy.append(entity_id)

## 每帧清理
func _process(_delta: float) -> void:
	if _pending_destroy.is_empty():
		return
	for eid in _pending_destroy:
		var mask: int = _entity_masks.get(eid, 0)
		if mask == ECSComponentTypes.ComponentType.NONE:
			continue
		for comp_name in _components:
			if _components[comp_name].has(eid):
				_components[comp_name].erase(eid)
		_entity_masks.erase(eid)
		_entity_to_unit.erase(eid)
	_pending_destroy.clear()

## 为 Entity 添加一个 Component
func add_component(entity_id: int, component_type: int, data: Variant) -> void:
	var comp_name = ECSComponentTypes.get_component_name(component_type)
	if not _components.has(comp_name):
		_components[comp_name] = {}
	_components[comp_name][entity_id] = data
	var mask: int = _entity_masks.get(entity_id, 0)
	_entity_masks[entity_id] = mask | component_type

## 获取 Entity 的某个 Component
func get_component(entity_id: int, component_type: int) -> Variant:
	var comp_name = ECSComponentTypes.get_component_name(component_type)
	if not _components.has(comp_name):
		return null
	return _components[comp_name].get(entity_id, null)

## 移除 Entity 的某个 Component
func remove_component(entity_id: int, component_type: int) -> void:
	var comp_name = ECSComponentTypes.get_component_name(component_type)
	if _components.has(comp_name) and _components[comp_name].has(entity_id):
		_components[comp_name].erase(entity_id)
	var mask: int = _entity_masks.get(entity_id, 0)
	_entity_masks[entity_id] = mask & ~component_type

## 查询拥有指定 Component 类型的所有 Entity（按位掩码快速筛选）
func query_entities(with_components: Array[int]) -> Array[int]:
	var result: Array[int] = []
	var required_mask: int = 0
	for ct in with_components:
		required_mask |= ct
	if required_mask == 0:
		return result
	for eid in _entity_masks:
		var mask: int = _entity_masks[eid]
		if (mask & required_mask) == required_mask:
			result.append(eid)
	return result

## 获取 Entity 对应的 Unit Node
func get_unit(entity_id: int) -> Node:
	return _entity_to_unit.get(entity_id, null)

## 获取 Unit Node 对应的 Entity ID（通过反向查找）
func get_entity_id(unit: Node) -> int:
	for eid in _entity_to_unit:
		if _entity_to_unit[eid] == unit:
			return eid
	return -1

## 检查 Entity 是否存活
func is_alive(entity_id: int) -> bool:
	return _entity_masks.has(entity_id) and entity_id not in _pending_destroy

## 调试打印 Entity 信息
func debug_print_entity(entity_id: int) -> void:
	if not _entity_masks.has(entity_id):
		print("[EntityManager] Entity %d 不存在" % entity_id)
		return
	var mask: int = _entity_masks[entity_id]
	print("[EntityManager] Entity %d 掩码: %d" % [entity_id, mask])
	for comp_name in _components:
		if _components[comp_name].has(entity_id):
			print("  └─ %s: %s" % [comp_name, _components[comp_name][entity_id]])
