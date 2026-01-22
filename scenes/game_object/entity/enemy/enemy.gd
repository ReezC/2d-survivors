extends	Unit
class_name	Enemy


var facingDirection:String = "Down"
var animation2Play:String = "Idle"

@export var 群体运动推动力: float = 5.0 # 群体运动推动力

@onready var 视野区域: Area2D = $视野区域

var 禁止移动 :bool= false



# 敌人AI逻辑
func _process(delta: float) -> void:
	if 禁止移动:
		return
	var direction = get_move_direction()
	var player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	var distance_to_player = (player.global_position - global_position).length()
	# var distance_to_player = (get_tree().get_first_node_in_group("player").global_position - global_position).length()
	var player_collision_radius = get_player_collision_radius()
	# print("玩家碰撞半径: ", player_collision_radius)
	# 如果距离小于碰撞半径相关的一个值，则停止移动
	if distance_to_player < player_collision_radius:
		direction = Vector2.ZERO
	velocity = direction * 单位属性.移动速度
	move_and_slide()

	# 更新动画状态
	if velocity.length() >10:
		animation2Play = "Run_" + get_direction_name()
	else :
		animation2Play = "Idle"
	animated_sprite_2d.play(animation2Play)

# 获取移动方向
func get_move_direction():
	var player_nodes = get_tree().get_first_node_in_group("player") as Node2D
	if player_nodes != null:
		var desired_direction = (player_nodes.global_position - global_position).normalized()
		
		# 群体运动调整
		for other_area in 视野区域.get_overlapping_bodies():
			if other_area != self and 视野区域.is_inside_tree():
				var to_other = global_position - other_area.global_position
				var distance = to_other.length()
				if distance > 0:
					# print(群体运动推动力)
					desired_direction += 群体运动推动力 * to_other.normalized() / distance
		return desired_direction.normalized() 
	return Vector2.ZERO


# 获取玩家碰撞半径
func get_player_collision_radius() -> float:
	var player_node = get_tree().get_first_node_in_group("player") as Node2D
	if player_node != null:
		var collision_shape = player_node.get_node("移动碰撞") as CollisionShape2D
		if collision_shape != null and collision_shape.shape is CircleShape2D:
			return (collision_shape.shape as CircleShape2D).radius
	return 0.0

# 获取朝向名称
func get_direction_name() -> String:
	if velocity == Vector2.ZERO:
		return facingDirection
		
	facingDirection = 'Down' if abs(velocity.y) >= abs(velocity.x) and velocity.y > .1 else facingDirection
	facingDirection = 'Up' if abs(velocity.y) >= abs(velocity.x) and velocity.y < -.1 else facingDirection
	facingDirection = 'Right' if abs(velocity.x) > abs(velocity.y) and velocity.x > .1 else facingDirection
	facingDirection = 'Left' if abs(velocity.x) > abs(velocity.y) and velocity.x < -.1 else facingDirection
	return facingDirection
