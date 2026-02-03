class_name 单位属性 extends Resource

signal 属性变化(属性:单位属性)


@export var 属性类型: 单位属性集.单位属性枚举
@export var 图标: Texture2D = preload("uid://blbd4dn0qfryy")
@export_multiline var 属性描述: String




## 不受任何影响的初始值，单位初始化后只读
@export var 初始值:= 0.0 : set = 设置_初始值
## 属性的当前状态
var 值: float : set = 设置_当前值 #每次修改都会调用setter

var id: int = -1
var 属性名称: String
var 最小值: float
var 最大值: float = INF
var 最小单位: float = 0.001
var 叠加方式: 单位属性集.单位属性叠加方式枚举


var 属性修改器列表: Array[单位属性修改器] = []
var 属于属性集: 单位属性集 = null

func 初始化单位属性() -> void:
	属性名称 = 单位属性集.单位属性定义表.get(属性类型).get("属性名称", "未命名属性")
	最小值 = 单位属性集.单位属性定义表.get(属性类型).get("最小值", -INF)
	最大值 = 单位属性集.单位属性定义表.get(属性类型).get("最大值", INF)
	最小单位 = 单位属性集.单位属性定义表.get(属性类型).get("最小单位", 0.0001)
	resource_name = 属性名称

	

## 初始值在export设置后为只读
func 设置_初始值(value: float):
	初始值 = 后处理(value)
	值 = 后处理(初始值)

func 设置_当前值(value: float):
	值 = 后处理(value)
	属性变化.emit(self)
	
	

func _计算最终值() -> float:
	var 最终值 = 0.0
	
	# 先计算内联依赖
	var 依赖的属性们: Array[单位属性] = []
	for 依赖属性类型 in 获取依赖的属性列表():
		var 依赖属性的名称 = 单位属性集.单位属性定义表.get(依赖属性类型).get("属性名称", "未命名属性")
		var 依赖属性: 单位属性 = 属于属性集.获取属性(依赖属性的名称)
		依赖的属性们.append(依赖属性)
	最终值 = 属性依赖计算(依赖的属性们)

	# 再应用修改器
	for 修改器 in 属性修改器列表:
		最终值 = 单位属性修改器.应用修改(修改器.修改类型, 最终值, 修改器.修正值)
		if 修改器.修改类型 == 单位属性修改器.修改类型枚举.强行设置_硬:
			return 最终值
		elif 修改器.修改类型 == 单位属性修改器.修改类型枚举.强行设置_软:
			break
	
	# 属性后处理
	最终值 = 后处理(最终值)

	return 最终值

func 获取最终值() -> float:
	return _计算最终值()

#region 一次性修改属性
func 一次性修改属性(修改类型: 单位属性修改器.修改类型枚举, 修正值: float) -> void:
	var 新值: float = 单位属性修改器.应用修改(修改类型, 值, 修正值)
	值 = 新值
	# print("属性 %s 发生变化，修改类型：%s，修正值：%f，当前值：%f" % [属性名称, str(修改类型), 修正值, 值])
	
	
#endregion

#region 修改器操作
func 添加属性修改器(修改器: 单位属性修改器) -> void:
	属性修改器列表.append(修改器)
	
func 移除属性修改器(修改器: 单位属性修改器) -> void:
	属性修改器列表.erase(修改器)
#endregion


## 不同属性间内置的关联，例如生命上限依赖于生命上限加成，攻击力依赖于力量值等
## 这里用可重写的方法储存，而不是用列表，是为了实现可能存在的复杂依赖逻辑
func 获取依赖的属性列表() -> Array[单位属性集.单位属性枚举]:
	return []

## 计算属性内联的依赖，例如 生命上限最终值 = 生命上限 * (1 + 生命上限加成最终值)

func 属性依赖计算(_计算参数:Array[单位属性]) -> float:
	return self.值

## 默认实现：应用上下限和步长
func 后处理(value: float) -> float:
	value = clamp(value, 最小值, 最大值)
	# 应用最小单位
	if abs(value) < 最小单位:
		value = 0.0
	else:
		value = round(value / 最小单位) * 最小单位
	return value

func _to_string() -> String:
	if 属性名称 == null:
		return "未命名属性"
	return "%s: %f" % [属性名称, 值]
