extends	Unit
class_name	Enemy


# var facingDirection:String = "Down"
var animation2Play:String = "Idle"



@export var 群体运动推动力: float = 5.0 # 群体运动推动力

@onready var 视野区域: Area2D = $视野区域

var 禁止移动 :bool= false



# 敌人AI逻辑
func _process(delta: float) -> void:
	var move_direction = get_move_direction()
	facingDirection = move_direction if move_direction != Vector2.ZERO else facingDirection
	var player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	var distance_to_player = (player.global_position - global_position).length()
	# var distance_to_player = (get_tree().get_first_node_in_group("player").global_position - global_position).length()
	var player_collision_radius = get_player_collision_radius()
	# print("玩家碰撞半径: ", player_collision_radius)
	# 如果距离小于碰撞半径相关的一个值，则停止移动
	if distance_to_player < player_collision_radius:
		move_direction = Vector2.ZERO
	# velocity = move_direction * attribute_component.获取属性值("移动速度")


	if 当前状态 != 角色状态.死亡:
		if 当前状态 == 角色状态.释放技能:
			# 释放技能时允许移动
			pass
		elif move_direction != Vector2.ZERO:
			当前状态 = 角色状态.移动
		else:
			当前状态 = 角色状态.待机
		velocity = velocity.lerp(move_direction * attribute_component.获取属性值("移动速度"),acccelerate * delta)
		
	else:
		velocity = velocity.lerp(Vector2.ZERO,acccelerate * delta)
	move_and_slide()


	set_anim()


func set_anim() -> void:
	match 当前状态:
		角色状态.死亡:
			state_machine.travel("Dead")
		角色状态.释放技能:
			state_machine.travel("Skill")
			# animation_tree.set("parameters/Skill/blend_position", get_x_facing_direction())
		角色状态.待机:
			state_machine.travel("Idle")
			# animation_tree.set("parameters/Idle/blend_position", facingDirection)
		角色状态.移动:
			state_machine.travel("Run")
			animation_tree.set("parameters/Run/blend_position", facingDirection)



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
