extends Resource
class_name UnitStats

enum UnitType {
	PLAYER,
	ENEMY,
}

@export var 名称: String = "Unit"
@export var 单位类型: UnitType 
@export var 图标: Texture2D
@export var 生命: int = 1
@export var 移动速度: float = 50
@export var 幸运: int = 0
@export var 暴击率: float = 0.05
@export var 暴击时额外伤害: float = 0.5
@export var 护甲: int = 0
@export var 闪避率: float = 0.0
