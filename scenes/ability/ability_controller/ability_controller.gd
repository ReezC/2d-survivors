extends Node
const TARGET_RANGE = 50
@export var ability: PackedScene

var damage_amount = 5
var base_wait_time


func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
	

# 技能核心逻辑
func on_timer_timeout():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy:Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) < pow(TARGET_RANGE,2))
	
	# 过滤出在目标范围内的敌人
	if enemies.size() == 0:   
		return
	enemies.sort_custom(
		func(a:Node2D,b:Node2D):
			var a_distance = a.global_position.distance_squared_to(player.global_position)
			var b_distance = b.global_position.distance_squared_to(player.global_position)
			return a_distance < b_distance
	)
	
	# 实例化能力并添加到场景中
	var ability_instance = ability.instantiate() as Node2D
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	foreground_layer.add_child(ability_instance)
	ability_instance.hitbox_component.damage_amount = damage_amount
	ability_instance.global_position = enemies[0].global_position
	#ability_instance.global_position = player.global_position

	# 判断是否需要水平翻转
	var enemy_direction = (enemies[0].global_position - player.global_position).normalized()
	# ability_instance.rotation = enemy_direction.angle()
	if enemy_direction.x < 0:
		ability_instance.scale.x = -abs(ability_instance.scale.x)
	else:
		ability_instance.scale.x = abs(ability_instance.scale.x)


# 升级效果
func on_ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary) -> void:
	if upgrade.id != "小刀冷却时间":
		return
	
	var wait_time_reduction = current_upgrades["小刀冷却时间"]["quantity"] * 0.5
	$Timer.wait_time = max(0.1, base_wait_time / (1.0 + wait_time_reduction))
	$Timer.start() # timer.wait_time修改后，重新启动计时器才能生效
	# print("升级小刀冷却时间 = %.2f当前时间：%.2f" % [wait_time_reduction,$Timer.wait_time])
	print_rich("[color=cyan]小刀冷却时间减少！当前冷却时间：%.2f 秒[/color]" % $Timer.wait_time)
	