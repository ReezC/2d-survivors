extends Node

const SPAWN_RADIUS = 375

@export var basic_enemy_scene: PackedScene
@export var arena_time_manager: Node

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.timeout.connect(on_timer_timeout)
	arena_time_manager.arena_difficulty_changed.connect(on_arena_difficulty_changed)

# 计算生成位置()
func get_spawn_position(direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0,TAU))) -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	# 获取随机方向
	var random_direction = direction.normalized()
	# 获取生成位置 = 玩家位置 + 随机方向 * 生成半径
	var spawn_position = player.global_position + random_direction * SPAWN_RADIUS
	# 判断位置有效性
	var query_param = PhysicsRayQueryParameters2D.create(player.global_position, spawn_position,1) # 输入起点和终点，查询两点之间的某mask(bit))碰撞，返回PhysicsRayQueryParameters2D对象
	var check_position = get_tree().root.world_2d.direct_space_state.intersect_ray(query_param)
	if check_position.is_empty() == false:
		# 有碰撞，说明位置无效，重新计算生成位置
		return get_spawn_position(direction.rotated(PI / 2)) # 旋转90度后重新计算
		# return player.global_position

	return spawn_position


func on_timer_timeout():
	timer.start() # 获取最新的计时
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	
	
	var enemy_instance = basic_enemy_scene.instantiate() as Node2D
	# enemy_instance.name = "Monster_%d" % enemy_instance.get_instance_id()
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	enemy_instance.global_position = get_spawn_position()
	entities_layer.add_child(enemy_instance)

	# print(enemy_instance.get_script())
	# print(enemy_instance.get_class())

	

func on_arena_difficulty_changed(now_difficulty: int) -> void:
	# 根据难度变化调整生成速率
	var last_wait_time = timer.wait_time
	timer.wait_time = last_wait_time / (1.0 + now_difficulty * 0.2)
	print_rich("[color=red]怪物变强了！当前难度：%d ：怪物生成速率：%.2f[/color]" % [now_difficulty, timer.wait_time])
