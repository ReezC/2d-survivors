extends CharacterBody2D

var inputDirection:Vector2 = Vector2.ZERO
const SPEED = 70
const ACCELERATE = 10
var facingDirection:String = "Down"

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var health_bar: ProgressBar = $HealthBar

@onready var damage_cd_timer: Timer = $DamageCdTimer
@onready var collision_area_2d: Area2D = $CollisionArea2D
@onready var abilities: Node = $Abilities

var animation2Play:String
var number_colliding_enemies: int = 0 # 记录碰撞的敌人数量
var collision_enemies: Array = []




func _ready() -> void: # 所有子节点先ready后 父节点才会ready 
	collision_area_2d.body_entered.connect(on_body_entered)
	collision_area_2d.body_exited.connect(on_body_exited)
	damage_cd_timer.timeout.connect(on_damage_cdtimer_timeout)
	health_component.health_changed.connect(on_health_changed)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)

	# 初始化血条
	update_health_display(health_component.max_health)


func _process(delta: float) -> void:
	# 获取输入方向
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")
	# 平滑加速
	velocity = velocity.lerp(inputDirection * SPEED,ACCELERATE * delta)
	# 平滑碰撞
	move_and_slide() 
	
	# 播放动画
	if velocity.length() >10:
		animation2Play = "Run_" + get_direction_name()
	else :
		animation2Play = "Idle_" + get_direction_name()
	animated_sprite_2d.play(animation2Play)
	# 根据左右移动翻转精灵
	if inputDirection.x >.1:
		animated_sprite_2d.flip_h = false
	elif inputDirection.x<-.1:
		animated_sprite_2d.flip_h = true

	
	
	
func get_direction_name() -> String:
	if inputDirection == Vector2.ZERO:
		return facingDirection
		
	if inputDirection.y > .1:
		facingDirection = "Down"
	elif inputDirection.y < -.1:
		facingDirection = "Up"
	else:
		if inputDirection.x >.1:
			facingDirection = "Right"
		elif inputDirection.x<-.1:
			facingDirection = "Left"
	return facingDirection
	



# 伤害处理逻辑
func deal_under_attack(from_who: Node2D) -> void:
	if collision_enemies.size() == 0 or !damage_cd_timer.is_stopped():
		return
	health_component.damage(1)
	damage_cd_timer.start()
	print("受到来自", from_who, "的 1 伤害，当前血量：", health_component.current_health)
	return

func on_body_entered(body: Node2D) -> void:
	collision_enemies.append(body)
	# number_colliding_enemies += 1
	deal_under_attack(body)

func on_body_exited(body: Node2D) -> void:
	# number_colliding_enemies -= 1
	collision_enemies.erase(body)

func on_damage_cdtimer_timeout() -> void:
	for enemy in collision_enemies:
		deal_under_attack(enemy)

# 受伤处理逻辑
# 更新血条显示
func update_health_display(changed_value: float) -> void:
	health_bar.value = health_component.get_health_percentage()
# 响应血量变化信号
func on_health_changed(changed_value: float) -> void:
	update_health_display(changed_value)

# 升级逻辑
func on_ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary):
	if not upgrade is Ability:
		return
	abilities.add_child(upgrade.ability_controller_scene.instantiate())
