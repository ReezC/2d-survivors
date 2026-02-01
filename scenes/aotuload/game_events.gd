extends Node


const 受击闪白material = preload("uid://c0gikbxr2hvpe")
# const 战斗跳字场景 = preload("res://scenes/ui/floating_text/战斗跳字.tscn")

signal experience_vial_collected(exp_amount: int)
signal ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary)
signal 创建跳字(位置: Vector2, 内容: String, 颜色: Color)


## 品质枚举，不光是物品
enum 品质枚举{
	普通,
	稀有,
	史诗,
	传说
}

enum collision_layer_enum {
	地形 = 1,
	玩家移动碰撞 = 2,
	敌人移动碰撞 = 4,
	掉落物 = 8,
	玩家hurtbox = 16,
	玩家hitbox = 32,
	敌人hurtbox = 64,
	敌人hitbox = 128,
}

func emit_experience_vial_collected(exp_amount: int) -> void:
	experience_vial_collected.emit(exp_amount)

func emit_ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary) -> void:
	ability_upgrade_added.emit(upgrade, current_upgrades)





## 获取随机结果，概率范围
##
## @param 概率: float 概率值，范围[0,1]
func 获取随机结果(概率: float) -> bool:
	var 随机值: float = randf()
	return 随机值 <= 概率
