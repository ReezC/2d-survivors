extends Unit
class_name Player


var inputDirection:Vector2 = Vector2.ZERO
var 平滑移速:Vector2 = Vector2.ZERO
var _last_horizontal_sign: int = -1  # 默认朝左（与精灵默认方向一致）

@onready var character_body: CharacterBody = $body


func _ready() -> void:
	super._ready()
	animated_sprite_2d.visible = false

func _process(delta: float) -> void:
	# 输入映射到移动
	player_move(delta)
	set_anim()
	move_and_slide()


func player_move(delta: float) -> void:
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")
	if 当前状态 != 角色状态.死亡:
		if inputDirection != Vector2.ZERO:
			当前状态 = 角色状态.移动
		else:
			当前状态 = 角色状态.待机
		velocity = velocity.lerp(inputDirection * attribute_component.获取属性值("移动速度"),acccelerate * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO,acccelerate * delta)
	
	# 检测水平方向变化，驱动纸娃娃翻转
	var h_sign := _get_horizontal_sign()
	if h_sign != 0 and h_sign != _last_horizontal_sign:
		_last_horizontal_sign = h_sign
		if character_body:
			character_body.set_face_direction(h_sign)


func set_anim() -> void:
	# ---- 纸娃娃动画驱动 ----
	if character_body and character_body.animator:
		match 当前状态:
			角色状态.待机:
				character_body.set_animation_state(0)
			角色状态.移动:
				character_body.set_animation_state(1)

	# # ---- 旧 AnimationTree（待纸娃娃完全接管后移除） ----
	# match 当前状态:
	# 	角色状态.死亡:
	# 		state_machine.travel("Dead")
	# 	角色状态.释放技能:
	# 		state_machine.travel("Skill")
	# 		animation_tree.set("parameters/Skill/blend_position", get_x_facing_direction())
	# 	角色状态.待机:
	# 		state_machine.travel("Idle")
	# 		animation_tree.set("parameters/Idle/blend_position", get_facing_direction())
	# 	角色状态.移动:
	# 		state_machine.travel("Run")
	# 		animation_tree.set("parameters/Run/blend_position", get_facing_direction())

		


func get_x_facing_direction() -> float:
	var x_input = inputDirection.x
	if x_input == 0:
		return facingDirection.x
	return x_input

func _get_horizontal_sign() -> int:
	"""获取当前水平方向符号：1=右, -1=左, 0=无输入"""
	if inputDirection.x > 0.1:
		return 1
	elif inputDirection.x < -0.1:
		return -1
	return 0

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
	
