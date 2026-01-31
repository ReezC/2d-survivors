extends Unit
class_name Player

var acccelerate = 10
var inputDirection:Vector2 = Vector2.ZERO
var facingDirection:Vector2 = Vector2.DOWN
var 平滑移速:Vector2 = Vector2.ZERO

# var 已死亡: bool = false

enum 角色状态{
	待机,
	移动,
	死亡,
	释放技能,
}

var 当前状态: 角色状态 = 角色状态.待机 :set = 修改角色状态
var 上一个状态: 角色状态 = 角色状态.待机

func _ready() -> void:
	super._ready()

func _physics_process(delta: float) -> void:
	pass
	# move_and_slide() 
	

func _process(delta: float) -> void:


	# 获取输入方向
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")
	if 当前状态 != 角色状态.死亡:
		if inputDirection != Vector2.ZERO:
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

func die() -> void:
	当前状态 = 角色状态.死亡
	死亡.emit()
	print("%s 死亡" % name)
	# 添加死亡倒计时，3秒后删除节点
	await get_tree().create_timer(3.0).timeout
	self.queue_free()

func 修改角色状态(新状态: 角色状态) -> void:
	_on_角色状态退出(当前状态)
	_on_角色状态进入(新状态)
	上一个状态 = 当前状态
	当前状态 = 新状态

func set_anim() -> void:
	match 当前状态:
		角色状态.死亡:
			state_machine.travel("dead")
		角色状态.释放技能:
			state_machine.travel("skill")
			# 暂定释放技能时可以移动
		角色状态.待机:
			state_machine.travel("Idle")
			animation_tree.set("parameters/Idle/blend_position", get_facing_direction())
		角色状态.移动:
			state_machine.travel("Run")
			animation_tree.set("parameters/Run/blend_position", get_facing_direction())

		
func _on_角色状态进入(新状态: 角色状态) -> void:
	pass

func _on_角色状态退出(旧状态: 角色状态) -> void:
	pass




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
	
