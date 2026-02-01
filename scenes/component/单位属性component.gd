class_name 单位属性Component extends Node

signal 生命值归零
signal 生命值变化(生命值属性: 单位属性)

@export var 属性集: 单位属性集

func _ready() -> void:
	属性集.初始化属性集()
	获取属性("生命值").属性变化.connect(_on_生命值属性变化)

## 角色出生时
func 初始化属性() -> void:
	获取属性("生命值").一次性修改属性(单位属性修改器.修改类型枚举.强行设置_软, 获取属性("生命上限").获取最终值())



#region 属性操作函数
func 获取属性值(属性名称: String) -> float:
	var 属性: 单位属性 = 属性集.获取属性(属性名称)
	return 属性.获取最终值()

func 获取属性(属性名称: String) -> 单位属性:
	return 属性集.获取属性(属性名称)
#endregion


## 属性对伤害的处理，包含死亡检测
## 传过来的伤害是计算完成后的最终值
## 		@param 伤害值:float
func 受到伤害(伤害值:float) -> void:
	var 当前生命值 = 获取属性值("生命值")
	if 当前生命值 <= 0:
		return
	获取属性("生命值").一次性修改属性(单位属性修改器.修改类型枚举.减, 伤害值)
	# 获取属性("生命值").生命值变化.emit(- 伤害值)

	var 剩余生命值 = 获取属性值("生命值")
	var 生命上限 = 获取属性值("生命上限")
	print("%s 受到 %d 点伤害，剩余生命： %s/%s" % [owner.name, 伤害值, 剩余生命值, 生命上限])
	
	Callable(检查死亡).call_deferred()

func 受到治疗(治疗值:float) -> void:
	var 当前生命值 = 获取属性值("生命值")
	if 当前生命值 <= 0:
		return
	获取属性("生命值").一次性修改属性(单位属性修改器.修改类型枚举.加, 治疗值)
	# 获取属性("生命值").生命值变化.emit(治疗值)

	var 剩余生命值 = 获取属性值("生命值")
	var 生命上限 = 获取属性值("生命上限")
	print("%s 受到 %d 点治疗，当前生命： %s/%s" % [owner.name, 治疗值, 剩余生命值, 生命上限])

func 检查死亡() -> bool:
	var 当前生命值 = 获取属性值("生命值")
	if 当前生命值 == 0:
		生命值归零.emit()
		owner.die()
		print("%s 生命值归零" % owner.name)
		return true
	return false

func _on_生命值属性变化(生命值属性:单位属性) -> void:
	生命值变化.emit(生命值属性)
