extends CharacterBody2D
class_name Unit


@onready var 视觉: Node2D = %视觉
@onready var animated_sprite_2d: AnimatedSprite2D = $视觉/AnimatedSprite2D
@onready var attribute_component: 单位属性Component = $单位属性component
@onready var health_bar: HealthBar = $HealthBar
@onready var 受击闪白效果timer: Timer = $受击闪白效果Timer
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

@onready var skill_manager: SkillManager = $SkillManager
@onready var skills: Node = $SkillManager/Skills
@onready var buffs: Node = $SkillManager/Buffs

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine = $AnimationTree.get("parameters/playback")
	
signal 出生	
signal 死亡

enum 角色状态{
	待机,
	移动,
	死亡,
	释放技能,
}

# 移动参数
var acccelerate = 10
var facingDirection:Vector2 = Vector2.DOWN

var 当前状态: 角色状态 = 角色状态.待机 :set = 修改角色状态
var 上一个状态: 角色状态 = 角色状态.待机
@export var 单位名称: String = "单位" :set = 设置_单位名称
@export var icon: Texture2D

func 设置_单位名称(新名称: String) -> void:
	单位名称 = 新名称
	name = 新名称

func 修改角色状态(新状态: 角色状态) -> void:
	_on_角色状态退出(当前状态)
	_on_角色状态进入(新状态)
	上一个状态 = 当前状态
	当前状态 = 新状态


func _on_角色状态进入(新状态: 角色状态) -> void:
	match 新状态:
		角色状态.死亡:
			hurtbox_component.monitoring = false
			hurtbox_component.monitorable = false
			health_bar.使用Tween渐隐()
		_:
			pass

func _on_角色状态退出(旧状态: 角色状态) -> void:
	pass
func _ready() -> void:
	attribute_component.初始化属性()
	animation_tree.active = true
	出生.emit()
	skill_manager.初始化()

func 设置受击闪白material(闪白material:ShaderMaterial) -> void:
	animated_sprite_2d.material = 闪白material
	if 受击闪白效果timer.is_stopped():
		受击闪白效果timer.start()
	

## 被击中事件处理
## 
## 暴击、闪避等战斗事件的判定在此处进行
## 采用归一圆桌算法：
## 	分子 = 当前判定的战斗事件概率
## 	分母 = min(各时间概率之和, 1.0)
## 
## @param hitbox: HitboxComponent
func _on_hurtbox_component_被击中(hitbox: HitboxComponent) -> void:
	if hitbox.命中伤害 > 0:
		# 判定伤害事件
		var 格挡率 = attribute_component.获取属性值("格挡率")
		var 闪避率 = attribute_component.获取属性值("闪避率")
		var 暴击率 = hitbox.source.attribute_component.获取属性值("暴击率")
		var 总概率 = 格挡率 + 闪避率 + 暴击率
		var 判定随机数 = randf() * 1.0 if 总概率 < 1.0 else randf() * 总概率

		if 判定随机数 < 闪避率:
			# 闪避成功
			pass
		elif 判定随机数 < 闪避率 + 格挡率:
			# 格挡成功
			var 格挡伤害减免 = attribute_component.获取属性值("格挡伤害减免")
			var 实际伤害 = hitbox.命中伤害 * (1.0 - 格挡伤害减免)
			attribute_component.受到伤害(实际伤害)
			设置受击闪白material(GameEvents.受击闪白material)
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d" % 实际伤害, Color.RED, 1)

		elif 判定随机数 < 闪避率 + 格挡率 + 暴击率:
			# 暴击成功
			var 暴击时额外伤害倍率 = hitbox.source.attribute_component.获取属性值("暴击伤害倍率")
			var 实际伤害 = hitbox.命中伤害 * (1.0 + 暴击时额外伤害倍率)
			attribute_component.受到伤害(实际伤害)
			设置受击闪白material(GameEvents.受击闪白material)
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d!" % 实际伤害, Color.GOLD, 1)
		else:
			# 普通命中
			attribute_component.受到伤害(hitbox.命中伤害)
			设置受击闪白material(GameEvents.受击闪白material)
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d" % hitbox.命中伤害, Color.RED, 0)


func die() -> void:
	当前状态 = 角色状态.死亡
	死亡.emit()
	print("%s 死亡" % name)
	# 添加死亡倒计时，3秒后删除节点
	await get_tree().create_timer(3.0).timeout
	self.queue_free()

func _on_受击闪白效果timer_timeout() -> void:
	animated_sprite_2d.material = null

func 计算碰撞相交位置(hitbox:HitboxComponent,hurtbox:HurtboxComponent) ->Vector2:
	var hitbox_shape = hitbox.get_node("CollisionShape2D")
	var hurtbox_shape = hurtbox.get_node("CollisionShape2D")
	
	var 攻击中心x:float = hitbox.global_position.x
	var 攻击中心y:float = hitbox.global_position.y
	var 攻击矩形尺寸 = hitbox_shape.shape.size
	var 攻击半宽 = 攻击矩形尺寸.x / 2
	var 攻击半高 = 攻击矩形尺寸.y / 2

	var 攻击左边界:float = 攻击中心x - 攻击半宽
	var 攻击右边界:float = 攻击中心x + 攻击半宽
	var 攻击上边界:float = 攻击中心y + 攻击半高
	var 攻击下边界:float = 攻击中心y - 攻击半高


	var 受击中心x:float = hurtbox.global_position.x
	var 受击中心y:float = hurtbox.global_position.y
	var 受击矩形尺寸 = hurtbox_shape.shape.size
	var 受击半宽 = 受击矩形尺寸.x / 2
	var 受击半高 = 受击矩形尺寸.y / 2
	var 受击左边界:float = 受击中心x - 受击半宽
	var 受击右边界:float = 受击中心x + 受击半宽
	var 受击上边界:float = 受击中心y + 受击半高
	var 受击下边界:float = 受击中心y - 受击半高

	var 相交左边界:float = maxf(攻击左边界, 受击左边界)
	var 相交右边界:float = minf(攻击右边界, 受击右边界)
	var 相交下边界:float = minf(攻击下边界, 受击下边界)
	var 相交上边界:float = maxf(攻击上边界, 受击上边界)
	

	var 随机x:float = randf_range(相交左边界, 相交右边界)
	var 随机y:float = randf_range(相交上边界, 相交下边界)
	var 随机坐标:Vector2 = Vector2(随机x, 随机y)
	return 随机坐标
