extends Unit
class_name Player


var inputDirection:Vector2 = Vector2.ZERO
var facingDirection_x: float = 0.0
var 平滑移速:Vector2 = Vector2.ZERO


# var 已死亡: bool = false






func _ready() -> void:
	super._ready()

func _physics_process(delta: float) -> void:
	pass
	# move_and_slide() 
	

func _process(delta: float) -> void:


	# 获取输入方向
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")
	if 当前状态 != 角色状态.死亡:
		if 当前状态 == 角色状态.释放技能:
			# 释放技能时允许移动
			pass
		elif inputDirection != Vector2.ZERO:
			当前状态 = 角色状态.移动
		else:
			当前状态 = 角色状态.待机
		velocity = velocity.lerp(inputDirection * attribute_component.获取属性值("移动速度"),acccelerate * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO,acccelerate * delta)
	
	# 平滑碰撞
	set_anim()
	move_and_slide() 
	
	# # 根据左右移动翻转精灵
	# if inputDirection.x >.1:
	# 	animated_sprite_2d.flip_h = false
	# elif inputDirection.x<-.1:
	# 	animated_sprite_2d.flip_h = true





func set_anim() -> void:
	match 当前状态:
		角色状态.死亡:
			state_machine.travel("Dead")
		角色状态.释放技能:
			state_machine.travel("Skill")
			animation_tree.set("parameters/Skill/blend_position", get_x_facing_direction())
		角色状态.待机:
			state_machine.travel("Idle")
			animation_tree.set("parameters/Idle/blend_position", get_facing_direction())
		角色状态.移动:
			state_machine.travel("Run")
			animation_tree.set("parameters/Run/blend_position", get_facing_direction())

		



func get_x_facing_direction() -> float:
	var x_input = inputDirection.x
	if x_input == 0:
		return facingDirection_x
	return x_input

func get_facing_direction() -> Vector2:
	if inputDirection == Vector2.ZERO:
		return facingDirection
		
	if inputDirection.y > .1 and abs(inputDirection.y) >= abs(inputDirection.x):
		facingDirection = Vector2.DOWN
	elif inputDirection.y < -.1 and abs(inputDirection.y) >= abs(inputDirection.x):
		facingDirection = Vector2.UP
	else:
		if inputDirection.x >.1:
			facingDirection = Vector2.RIGHT
		elif inputDirection.x<-.1:
			facingDirection = Vector2.LEFT
	
	return facingDirection
	
