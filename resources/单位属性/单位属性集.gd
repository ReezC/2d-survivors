extends Resource

class_name 单位属性集

@export var 属性们: Array[单位属性] :set = 初始化属性集


## 运行时数据
var 属性字典: Dictionary[String, 单位属性] = {}

func 初始化属性集(v):
	属性们 = v
	属性字典.clear()
	for 属性 in 属性们:
		if 属性字典.has(属性.属性名称):
			push_error("单位属性集初始化错误：存在重复的属性名称：" + 属性.属性名称)
			continue
		var 复制的属性 = 属性.duplicate() as 单位属性
		复制的属性.属于属性集 = self
		属性字典[属性.属性名称] = 复制的属性
		复制的属性.属性变化.connect(_on_属性变化)

func _on_属性变化(属性: 单位属性, 修改值: float) -> void:
	# 这里可以处理属性变化时的逻辑，例如更新UI等
	pass


func 获取属性(属性名称: String) -> 单位属性:
	if 属性字典.has(属性名称):
		return 属性字典[属性名称]
	push_error("单位属性集获取属性错误：不存在的属性名称：" + 属性名称)
	return null
