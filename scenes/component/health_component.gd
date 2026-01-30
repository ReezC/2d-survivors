extends Node
class_name HealthComponent


signal 死亡
signal 生命值变化(变化值: float)

var 生命上限: int = 1
var 当前生命值: int = 1

func setup(单位的属性:UnitStats) -> void:
	生命上限 = 单位的属性.生命
	当前生命值 = 生命上限
	生命值变化.emit(0)

## 生命组件对伤害的处理，包含死亡检测
## 
## @param 伤害值:float
func 受到伤害(伤害值:float) -> void:
	if 当前生命值 <= 0:
		return
	当前生命值 = max(当前生命值 - 伤害值, 0)
	生命值变化.emit(- 伤害值)
	print("%s 受到 %d 点伤害，剩余生命： %s/%s" % [owner.name, 伤害值, 当前生命值, 生命上限])
	
	var 单位属性component = owner.get_node("单位属性component")
	单位属性component.获取属性("生命").一次性修改属性(单位属性修改器.修改类型枚举.减, 伤害值)
	print("%d / %d" % [单位属性component.获取属性值("生命"),单位属性component.获取属性值("最大生命值")])
	
	Callable(检查死亡).call_deferred()

func 受到治疗(治疗值:float) -> void:
	if 当前生命值 <= 0:
		return
	当前生命值 = min(当前生命值 + 治疗值, 生命上限)
	生命值变化.emit(治疗值)

func 检查死亡() -> void:
	if 当前生命值 == 0:
		死亡.emit()
		owner.die()
		print("%s 死亡" % owner.name)
