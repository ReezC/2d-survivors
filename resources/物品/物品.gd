extends Resource

class_name 物品

enum 物品类型枚举 {
	消耗品,
	装备,
	材料,
	任务物品
}

@export var 物品名称: String = "无名之物"
@export var 物品图标: Texture2D
@export_multiline var 物品描述: String = "暂时没什么用。"
@export var 物品品质 : GameEvents.品质枚举
@export var 物品类型 : 物品类型枚举
