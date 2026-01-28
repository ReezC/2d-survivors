extends Resource



## 为了方便乘区管理，所有的单位属性运算都只有加和减，没有乘除
class_name 单位属性

signal 属性变化(属性:单位属性, 修改值: float)

@export var 属性名称: String
@export var 图标: Texture2D
@export_multiline var 属性描述: String
@export var 最小值: float
@export var 最大值: float

## 属性的原始数值
@export var 初始值:= 0.0 : set = 设置_初始值
@export var 最小单位: float = 0.001
@export_enum("线性叠加","收敛叠加","连乘叠加") var 叠加方式: int = 0


## 属性的当前状态
var 值: float : set = 设置_当前值
var 属性修改器列表: Array[单位属性修改器] = []
var 属于属性集: 单位属性集 = null



func 设置_初始值(value: float) -> void:
	self.初始值 = value
	self.值 = value

func 设置_当前值(value: float) -> void:
	值 = clamp(value, 最小值, 最大值)
	emit_signal("属性变化", self, 值)

func _计算最终值() -> float:
	var 最终值 = 0.0
	
	# 先计算内联依赖
	var 依赖的属性们: Array[单位属性] = []
	for 依赖属性名称 in 获取依赖的属性列表():
		var 依赖属性: 单位属性 = 属于属性集.获取属性(依赖属性名称)
		依赖的属性们.append(依赖属性)
	最终值 = 属性依赖计算(依赖的属性们)

	# 再应用修改器
	for 修改器 in 属性修改器列表:
		最终值 = 修改器.应用修改(最终值)

	return 最终值


## 不同属性间内置的关联，例如生命上限依赖于生命上限加成，攻击力依赖于力量值等
## 这里用可重写的方法储存，而不是用列表，是为了实现可能存在的复杂依赖逻辑
func 获取依赖的属性列表() -> Array[String]:
	return []

## 计算属性内联的依赖，例如 生命上限最终值 = 生命上限 * (1 + 生命上限加成最终值)

func 属性依赖计算(_计算参数:Array[单位属性]) -> float:
	return 值
