# DamageManager.gd
extends Node

# 预加载伤害数字场景
@onready var damage_text_scene = preload("res://scenes/ui/floating_text/新跳字方案.tscn")


func spawn_damage_text(
	world_position: Vector2, 
	value: int, 
	damage_type: 新跳字方案.DamageType,
	is_critical: bool = false
):
	var instance = damage_text_scene.instantiate()
	
	# 设置属性
	instance.position = world_position
	instance.text = str(value)
	
	# 如果是暴击，显示暴击类型
	if is_critical and damage_type == 新跳字方案.DamageType.PLAYER_NORMAL:
		instance.damage_type = 新跳字方案.DamageType.PLAYER_CRITICAL
		instance.text = str(value) + "!"
	else:
		instance.damage_type = damage_type
	
	# 添加到场景
	get_tree().current_scene.add_child(instance)
	
	# 添加随机偏移，避免完全重叠
	instance.position.x += randf_range(-10, 10)
	
	return instance

# 测试函数
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 点击时显示随机伤害数字
			var 随机伤害 = randi_range(10, 100)
			# var 是否暴击 = randf() < 0.2
			spawn_damage_text(event.position, 随机伤害, 新跳字方案.DamageType.BLOCK)
			
			# 显示状态
			
