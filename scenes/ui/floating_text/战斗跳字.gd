extends Node2D

class_name 战斗跳字

@onready var 跳字label: Label = $跳字Label

func 设置跳字内容(内容: String, 颜色: Color) -> void:
    跳字label.text = 内容
    modulate = 颜色
    