extends Node


const 受击闪白material = preload("uid://c0gikbxr2hvpe")
# const 战斗跳字场景 = preload("res://scenes/ui/floating_text/战斗跳字.tscn")

signal experience_vial_collected(exp_amount: int)
signal ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary)

## 品质枚举，不光是物品
enum 品质枚举{
	普通,
	稀有,
	史诗,
	传说
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
