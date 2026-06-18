extends Node
class_name 技能实例

## 技能实例 — 已迁移到 ECS
## 此文件保留仅作为场景数据桥接，用于在 .tscn 中引用 技能数据 Resource
## 实际技能逻辑由 ECSWorld.skill_system 管理
## 此节点仅作为数据载体，在 SkillManager.初始化() 中读取后注册到 ECS

@export var 技能本体数据: 技能数据

## 以下属性保留兼容性，但不再由本节点管理
var id: int = 0
var 技能名称: String = "未命名"
var 技能类型: int = 0
var 冷却时间: float = 0.0
var 技能触发范围: float = 0.0
var 动画名称: String = ""
var 当前状态: int = 0  ## SkillComponentData.技能状态

enum 技能状态 {
	准备就绪,
	冷却中,
}

## 兼容旧代码调用 — 委托给 ECS
func 初始化() -> void:
	pass  ## 实际初始化由 SkillSystem.register_entity 完成

func cast() -> void:
	pass  ## 实际释放由 SkillSystem._cast_skill_internal 完成

func 预编译表达式() -> void:
	pass  ## 实际编译由 SkillSystem._create_skill_component 完成

func 获取技能触发范围() -> float:
	return 技能触发范围

func 获取冷却时间() -> float:
	return 冷却时间
