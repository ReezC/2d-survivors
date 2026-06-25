extends CharacterBody2D
class_name Unit


@onready var 视觉 = %视觉
@onready var animated_sprite_2d: AnimatedSprite2D = null
@onready var attribute_component: 单位属性Component = $单位属性component
@onready var health_bar: HealthBar = $HealthBar
@onready var 受击闪白效果timer: Timer = $受击闪白效果Timer
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

@onready var skill_manager: SkillManager = $SkillManager

@onready var animation_tree: AnimationTree = null
@onready var state_machine = null

signal 出生	
signal 死亡

enum 角色状态{
	待机,
	移动,
	死亡,
	施法,
}

# 移动参数
var acccelerate = 10
var facingDirection:Vector2 = Vector2.DOWN

var 当前状态: 角色状态 = 角色状态.待机 :set = 修改角色状态
var 上一个状态: 角色状态 = 角色状态.待机
## 施法状态附带的动画参数（与 cfg 中 BuffAnimation 接口结构一致）
var 施法动画参数: Dictionary = {}
## 施法状态下的移动速度系数（0=完全静止, 0.5=半速, 1.0=全速）
## 由修改角色状态根据转入来源自动设置：待机→施法=0, 移动→施法=0.5
var 施法移动速度系数: float = 1.0
## 施法状态下是否允许输入改变朝向（默认禁用，后续可由配置覆盖）
var 施法允许改朝向: bool = false
@export var 单位名称: String = "单位" :set = 设置_单位名称
@export var icon: Texture2D

## 音效配置
@export_group("死亡状态配置")
@export var 死亡音效: SfxRef    # 死亡时播放的音效资源（直接拖入 .tres）
@export var 死亡特效: PackedScene  # 死亡时播放的特效资源（直接拖入 .tscn）

func 设置_单位名称(新名称: String) -> void:
	单位名称 = 新名称
	name = 新名称

var _角色状态名: Dictionary = {
	角色状态.待机: "待机",
	角色状态.移动: "移动",
	角色状态.死亡: "死亡",
	角色状态.施法: "施法",
}


func 修改角色状态(新状态: 角色状态) -> void:
	"""修改角色状态。进入施法状态前，请先设置 施法动画参数。"""
	if 当前状态 == 新状态:
		return
	if is_in_group("player"):
		GMLogger.log_player_state("[%s] %s → %s" % [单位名称, _角色状态名[当前状态], _角色状态名[新状态]])
	if 新状态 != 角色状态.施法:
		施法动画参数 = {}
	
	# 进入施法状态时，根据来源状态设置移动速度系数
	if 新状态 == 角色状态.施法:
		match 当前状态:
			角色状态.待机:
				施法移动速度系数 = 0.0
			角色状态.移动:
				施法移动速度系数 = 0.2
			_:
				施法移动速度系数 = 0.0
	
	_on_角色状态退出(当前状态)
	_on_角色状态进入(新状态)
	上一个状态 = 当前状态
	当前状态 = 新状态


func _on_角色状态进入(新状态: 角色状态) -> void:
	match 新状态:
		角色状态.死亡:
			hurtbox_component.set_deferred("monitoring", false)
			hurtbox_component.set_deferred("monitorable", false)
			
			health_bar.使用Tween渐隐()
		_:
			pass

func _on_角色状态退出(旧状态: 角色状态) -> void:
	pass
func _ready() -> void:
	# 子类场景可能不包含 AnimatedSprite2D（如纸娃娃模式），按需查找
	animated_sprite_2d = $视觉.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	# AnimationTree 在纸娃娃模式或单位.tscn 移除后可能不存在
	animation_tree = get_node_or_null("AnimationTree") as AnimationTree
	if animation_tree:
		state_machine = animation_tree.get("parameters/playback")
		animation_tree.active = true
	attribute_component.初始化属性()
	出生.emit()
	skill_manager.初始化()

func 设置受击闪白material(闪白material:ShaderMaterial) -> void:
	# 对视觉节点下所有子节点设置闪白材质（包括纸娃娃系统创建的精灵）
	_apply_material_to_all_sprites(闪白material)
	if 受击闪白效果timer.is_stopped():
		受击闪白效果timer.start()
	

## 被击中时事件处理：
## 
## 暴击、闪避等战斗事件的判定在此处进行
## 采用归一圆桌算法：
## 	分子 = 当前判定的战斗事件概率
## 	分母 = min(各时间概率之和, 1.0)
## 
## @param hitbox: HitboxComponent
func _on_hurtbox_component_被击中(hitbox: HitboxComponent) -> void:
	# 如果 hitbox 配置了 collideAction，根据配置执行对应逻辑
	if not hitbox.collide_action.is_empty():
		var action_type = hitbox.collide_action.get("$type", "").split(".")[-1]
		match action_type:
			"Damage":
				_执行伤害判定(hitbox)
			_:
				push_error("[单位] 未知的 collideAction 类型: %s" % action_type)
		return
	
	# 未配置 collideAction 时走默认伤害流程（兼容老式 ability controller）
	if hitbox.命中伤害 > 0:
		_执行伤害判定(hitbox)

## 执行伤害判定（归一圆桌算法）
func _执行伤害判定(hitbox: HitboxComponent) -> void:
	if hitbox.命中伤害 <= 0:
		return
	# 判定伤害事件
	var 格挡率 = attribute_component.获取属性值("格挡率")
	var 闪避率 = attribute_component.获取属性值("闪避率")
	# 通过 entity 或 source node 获取施法者的暴击率
	var source_attr = null
	if hitbox._entity_manager and hitbox.source_entity > 0:
		source_attr = hitbox._entity_manager.get_component(hitbox.source_entity, ECSComponentTypes.ComponentType.ATTRIBUTE)
	var 暴击率: float = 0.0
	var 暴击伤害倍率: float = 0.0
	if source_attr and source_attr.has_method("获取属性值"):
		暴击率 = source_attr.获取属性值("暴击率")
		暴击伤害倍率 = source_attr.获取属性值("暴击伤害倍率")
	else:
		var src = hitbox.get_source_node()
		if src and "attribute_component" in src:
			暴击率 = src.attribute_component.获取属性值("暴击率")
			暴击伤害倍率 = src.attribute_component.获取属性值("暴击伤害倍率")
	var 总概率 = 格挡率 + 闪避率 + 暴击率
	var 判定随机数 = randf() * 1.0 if 总概率 < 1.0 else randf() * 总概率

	if 判定随机数 < 闪避率:
		# 闪避成功
		if "player" in self.get_groups():
			# 玩家闪避，显示绿色跳字
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "闪避", 跳字对象池.跳字类型枚举.玩家闪避, 1)
		elif "enemy" in self.get_groups():
			# 非玩家单位闪避，显示怪物闪避跳字
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "闪避", 跳字对象池.跳字类型枚举.怪物闪避, 1)
	elif 判定随机数 < 闪避率 + 格挡率:
		# 格挡成功
		var 格挡伤害减免 = attribute_component.获取属性值("格挡伤害减免")
		var 实际伤害 = hitbox.命中伤害 * (1.0 - 格挡伤害减免)
		attribute_component.受到伤害(实际伤害)
		
		if "player" in self.get_groups():
			# 玩家受到格挡伤害，显示蓝色跳字
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d" % 实际伤害, 跳字对象池.跳字类型枚举.玩家格挡后的伤害, 1)
			# 设置受击闪白material(GameEvents.受击闪白material)
		elif "enemy" in self.get_groups():
			# 非玩家单位受到格挡伤害，显示怪物格挡跳字
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d" % 实际伤害, 跳字对象池.跳字类型枚举.怪物格挡后的伤害, 1)
			# 设置受击闪白material(GameEvents.受击闪白material)

	elif 判定随机数 < 闪避率 + 格挡率 + 暴击率:
		# 暴击成功
		var 实际伤害 = hitbox.命中伤害 * (1.0 + 暴击伤害倍率)
		attribute_component.受到伤害(实际伤害)
		
		if "player" in self.get_groups():
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "暴击%d!" % 实际伤害, 跳字对象池.跳字类型枚举.玩家受到的暴击伤害, 1)
			设置受击闪白material(GameEvents.受击闪红material)
		elif "enemy" in self.get_groups():
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "暴击%d!" % 实际伤害, 跳字对象池.跳字类型枚举.怪物受到的暴击伤害, 1)
			设置受击闪白material(GameEvents.受击闪白material)
	else:
		# 普通命中
		attribute_component.受到伤害(hitbox.命中伤害)
		
		if "player" in self.get_groups():
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d" % hitbox.命中伤害, 跳字对象池.跳字类型枚举.玩家受到的普通伤害, 1)
			设置受击闪白material(GameEvents.受击闪红material)
		elif "enemy" in self.get_groups():
			GameEvents.创建跳字.emit(计算碰撞相交位置(hitbox, hurtbox_component), "%d" % hitbox.命中伤害, 跳字对象池.跳字类型枚举.怪物受到的普通伤害, 0)
			设置受击闪白material(GameEvents.受击闪白material)
	
	# 播放受击音效（传入世界坐标以启用位置衰减）
	AudioManager.play_sfx_ref(hurtbox_component.受击音效, global_position)


func die() -> void:
	当前状态 = 角色状态.死亡
	死亡.emit()
	# 播放死亡音效（传入世界坐标以启用位置衰减）
	AudioManager.play_sfx_ref(死亡音效, global_position)
	if is_in_group("player"):
		GMLogger.log_player_state("%s 死亡" % name)
	elif is_in_group("enemy"):
		GMLogger.log_enemy("%s 死亡" % name)

	GMLogger.log_attr("%s 死亡" % name)
	# 实例化死亡特效并添加到视觉节点上方（视觉的兄弟节点），避免跟随死亡漂浮动画
	if 死亡特效 != null and 视觉 != null:
		var tombstone = 死亡特效.instantiate()
		self.add_child(tombstone)
		self.move_child(tombstone, 视觉.get_index())
		tombstone.global_position = 视觉.global_position
		if facingDirection.x > 0.0:
			tombstone.scale.x = -abs(tombstone.scale.x)
		elif facingDirection.x < 0.0:
			tombstone.scale.x = abs(tombstone.scale.x)
	# 添加死亡倒计时，3秒后删除节点
	await get_tree().create_timer(3.0).timeout
	self.queue_free()

func _on_受击闪白效果timer_timeout() -> void:
	# 恢复视觉节点下所有子节点的材质
	_apply_material_to_all_sprites(null)

## 递归遍历视觉节点树，对所有 Sprite2D/AnimatedSprite2D 设置材质
func _apply_material_to_all_sprites(mat: ShaderMaterial) -> void:
	_apply_material_recursive(视觉, mat)

func _apply_material_recursive(node: Node, mat: ShaderMaterial) -> void:
	if node is AnimatedSprite2D or node is Sprite2D:
		node.material = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

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

## 创建特效实例
func create_fx(fx_scene: PackedScene, offset: Vector2=Vector2.ZERO,bind:bool=false ,speed_scale: float = 1.0) -> void:
	var fx_instance = fx_scene.instantiate() as fx
	fx_instance.speed_scale = speed_scale
	if bind:
		add_child(fx_instance)
	else:
		fx_instance.position = global_position + offset
		get_tree().current_scene.add_child(fx_instance)
