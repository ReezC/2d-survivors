class_name 单位属性Component extends Node



@export var 属性集: 单位属性集

func 获取属性值(属性名称: String) -> float:
	var 属性: 单位属性 = 属性集.获取属性(属性名称)
	return 属性.获取最终值()

func 获取属性(属性名称: String) -> 单位属性:
	return 属性集.获取属性(属性名称)
