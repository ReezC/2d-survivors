extends Node
class_name SkillManager

## ECS 桥接层
## 保留此节点以兼容现有 .tscn 引用，但实际逻辑委托给 ECSWorld

@export_dir var 子物体场景路径

enum AI类型枚举 {
	无,
	Player技能AI,
	Enemy技能AI,
}

@export var skill_ai: AI类型枚举
@export var 初始技能: Array[技能数据] = []

# 预编译表达式已迁移至 ECS SkillSystem（SkillSystem._compiled_*_cache 管理）


func _ready() -> void:
	# 确保 ECSWorld 存在
	if not ECSWorld or not is_instance_valid(ECSWorld):
		push_error("[SkillManager] ECSWorld 未注册为 Autoload！")
		return

func 初始化() -> void:
	# 配置 ECS 的 AI 类型（只有非零时才设置，避免被后续的敌人 SkillManager 覆盖）
	if skill_ai != 0:
		ECSWorld.skill_system.skill_ai = skill_ai
	if 子物体场景路径 != "":
		ECSWorld.skill_system.子物体场景路径 = 子物体场景路径

	# 读取初始技能数据并注册到 ECS
	if 初始技能.size() > 0:
		ECSWorld.register_unit_skills(owner, 初始技能)
	
	# 激活已注册的被动技能
	ECSWorld.skill_system.初始化技能()

# 拥有者死亡时，销毁 buff 实例
func _on_单位_死亡() -> void:
	var eid = ECSWorld.entity_manager.get_entity_id(owner)
	if eid != -1:
		ECSWorld.destroy_entity(eid)
	GMLogger.log_skill("[%s] 技能管理器检测到拥有者死亡" % owner.name)


## 释放技能（委托给 ECS）
func 释放技能(技能ID: int) -> void:
	var eid = ECSWorld.entity_manager.get_entity_id(owner)
	if eid != -1:
		ECSWorld.skill_system.释放技能(eid, 技能ID)


## 播放技能动画（静态方法，保留兼容）
static func 播放技能动画(who: Node2D, 动画名称: String, 技能动画持续时间: float) -> void:
	SkillSystem._播放技能动画(who, 动画名称, 技能动画持续时间)


#region 目标扫描（委托给 ECS SkillSystem）
func get_target_in_circle_area(
	center_position: Vector2,
	direction: Vector2,
	radius: float,
	angle_deg: float,
	target_collision_layer: int
) -> Array:
	return ECSWorld.skill_system._get_target_in_circle_area(
		center_position, direction, radius, angle_deg, target_collision_layer
	)
#endregion

# 表达式编译已委托给 SkillSystem._编译数值() / _编译条件()
