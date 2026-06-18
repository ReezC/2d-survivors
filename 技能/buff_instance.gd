extends Node
class_name BuffInstance

## Buff 实例 — 已迁移到 ECS
## 此文件保留仅作为类型引用兼容（ExprCompiler 等仍引用 BuffInstance 类型名）
## 实际 Buff 逻辑由 ECSWorld.buff_system 管理，数据由 BuffComponentData 承载

var 施法者: Node
var buff_data: Dictionary
var parent_buff: BuffInstance
var 持续时间: float = 0.0

var 层数: int = 0
var 最大层数: float = INF
var 叠加计时类型: int = 0

var BlackBoard: Dictionary = {}
var 当前目标: Node2D = null

var skill_manager: Node

enum buff叠加计时类型枚举 {
	不改变计时,
	叠加时刷新计时,
	每层独立计时,
	延长计时,
}

signal buff开始
signal buff结束

func _init(_buff_data: Dictionary = {}, _施法者: Node = null, _parent_buff: BuffInstance = null) -> void:
	pass  ## 已迁移到 ECS，不再在此初始化

func _ready() -> void:
	pass  ## 已迁移到 ECS

func on_buff_start() -> void:
	pass

func on_buff_end() -> void:
	pass

func buff_excute(_buff_logic_data: Dictionary) -> void:
	pass

func skillAction_execute(_action: Dictionary) -> void:
	pass

func create_obj(_obj_instance, _obj_movement_config, _obj_duration_timer = null) -> 子物体:
	return null

func target_selector_result(_target_selector_config: Dictionary) -> Array:
	return []
