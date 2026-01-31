extends Node

@onready var 跳字池: 跳字对象池 = preload("res://scenes/managers/跳字对象池.tscn").instantiate()
@export_enum("普通跳字","暴击跳字") var 跳字类型: String

func _ready() -> void:
	# 添加对象池到场景
	add_child(跳字池)
	
	# 显示跳字
	跳字池.显示跳字(Vector2(100, 100), "Hello World", Color.RED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 点击时显示随机伤害数字
			var 随机伤害 = randi_range(10, 100)
			var 是否暴击 = randf() < 0.2
			显示伤害数字(event.position, 随机伤害, 是否暴击)
			# 显示伤害数字(event.position, 随机伤害, 是否暴击)
			# 显示伤害数字(event.position, 随机伤害, 是否暴击)
			
			# 显示状态
			print("对象池状态: ", 跳字池.获取对象池状态())
			print(str(跳字类型))
			print(typeof(跳字类型))


func 显示伤害数字(目标位置: Vector2, 伤害值: int, 是否暴击: bool):
	var 颜色: Color
	var 内容: String
	
	if 是否暴击:
		颜色 = Color.GOLD
		内容 = "暴击！%d" % 伤害值
	else:
		if 伤害值 > 0:
			颜色 = Color.RED
			内容 = "-%d" % 伤害值
		else:
			颜色 = Color.GREEN
			内容 = "+%d" % abs(伤害值)
	
	return 跳字池.显示跳字(目标位置, 内容, 颜色,1 if 是否暴击 else 0)
