extends Node

@onready var 跳字池: 跳字对象池 = preload("res://scenes/managers/floating_text_manager.tscn").instantiate()

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
			跳字池.显示伤害数字(event.position, 随机伤害, 是否暴击)
			
			# 显示状态
			print("对象池状态: ", 跳字池.获取对象池状态())
