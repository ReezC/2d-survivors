extends Unit
class_name Player

var move_speed = 0
var acccelerate = 10
var inputDirection:Vector2 = Vector2.ZERO

var facingDirection:String = "Down"
var animation2Play:String = "Idle_" + facingDirection 

var 已死亡: bool = false

func _ready() -> void:
	super._ready()
	move_speed = 单位属性.移动速度

func _process(delta: float) -> void:
	
	# 获取输入方向
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")
	# 平滑加速
	velocity = velocity.lerp(inputDirection * move_speed,acccelerate * delta) if not 已死亡 else Vector2.ZERO
	# 平滑碰撞
	move_and_slide() 
	set_anim()
	
	# # 根据左右移动翻转精灵
	# if inputDirection.x >.1:
	# 	animated_sprite_2d.flip_h = false
	# elif inputDirection.x<-.1:
	# 	animated_sprite_2d.flip_h = true

func die() -> void:
	已死亡 = true
	# 添加死亡倒计时，3秒后删除节点
	await get_tree().create_timer(3.0).timeout
	self.queue_free()


func set_anim() -> void:
	if 已死亡:
		animation2Play = "dead"
	elif velocity.length() >10:
		animation2Play = "Run_" + get_direction_name()
	else :
		animation2Play = "Idle_" + get_direction_name()
	animated_sprite_2d.play(animation2Play)


func get_direction_name() -> String:
	if inputDirection == Vector2.ZERO:
		return facingDirection
		
	if inputDirection.y > .1 and abs(inputDirection.y) >= abs(inputDirection.x):
		facingDirection = "Down"
	elif inputDirection.y < -.1 and abs(inputDirection.y) >= abs(inputDirection.x):
		facingDirection = "Up"
	else:
		if inputDirection.x >.1:
			facingDirection = "Right"
		elif inputDirection.x<-.1:
			facingDirection = "Left"
	
	return facingDirection
