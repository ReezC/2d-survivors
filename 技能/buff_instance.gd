extends Node
class_name BuffInstance

var 施法者: Node
var buff_data: Dictionary
var parent_buff:BuffInstance
var 持续时间: float = 0.0


var 层数: int = 0
var 最大层数:= INF
var 叠加计时类型: buff叠加计时类型枚举 = buff叠加计时类型枚举.不改变计时

var BlackBoard: Dictionary = {}
var buff_timer: Timer = Timer.new()
var 当前目标: Node2D = null

var skill_manager: Node

signal buff开始
signal buff结束

enum buff叠加计时类型枚举 {
	不改变计时,
	叠加时刷新计时,
	每层独立计时,
	延长计时,
}


func _init(_buff_data: Dictionary, _施法者: Node,_parent_buff:BuffInstance = null) -> void:
	name = _buff_data.get("name", "BuffInstance")
	buff_data = _buff_data
	施法者 = _施法者
	skill_manager = 施法者.skill_manager
	parent_buff = _parent_buff if _parent_buff != null else self
	
	# TODO：叠层逻辑在此时处理
	最大层数 = max(1, int(skill_manager._解析数值(buff_data.get("maxStack"))))
	var 叠加计时类型配置 = buff_data.get("stackType")
	match 叠加计时类型配置:
		"none":
			叠加计时类型 = buff叠加计时类型枚举.不改变计时
		"refresh":
			叠加计时类型 = buff叠加计时类型枚举.叠加时刷新计时
		"independent":
			叠加计时类型 = buff叠加计时类型枚举.每层独立计时
		"extend":
			叠加计时类型 = buff叠加计时类型枚举.延长计时
	


## 技能
## └──buff
##    ├──effect1
##    ├──effect2
##    └──...

func _ready() -> void:
	on_buff_start()
	var buff_logic_data = buff_data.get("buffLogic")
	buff_excute(buff_logic_data)
	

func buff_excute(buff_logic_data: Dictionary) -> void:
	match buff_logic_data.get("$type").split(".")[-1]:
		"PlayAnimation":
			# var animation_name = buff_logic_data.get("animationName")
			# var anim_tree = 施法者.get_node_or_null("AnimationTree") as AnimationTree
			if 施法者.当前状态 == 施法者.角色状态.死亡:
				return
			施法者.当前状态 = 施法者.角色状态.释放技能
			buff结束.connect(func():
				施法者.当前状态 = 施法者.角色状态.待机
			)
		"BuffList":
			var buff_logics = buff_logic_data.get("buffs", [])
			for logic in buff_logics:
				buff_excute(logic)

		"ActionOverTime":
			var interval =skill_manager. _解析数值(buff_logic_data.get("interval")) / 1000.0
			if interval <= 0.0:
				push_error("[color=red]ActionOverTime 的 interval 必须大于0[/color]")
				return
			var action = buff_logic_data.get("action", {})
			var action_over_time_timer = Timer.new()
			action_over_time_timer.wait_time = interval
			action_over_time_timer.autostart = true
			action_over_time_timer.connect("timeout", func():
				skillAction_execute(action)
			)
			add_child(action_over_time_timer)
			action_over_time_timer.start()

		_:
			print_rich("[color=red]未知的buff逻辑类型: %s[/color]" % buff_logic_data.get("$type"))
	
	
func on_buff_start() -> void:
	emit_signal("buff开始")
	# buff开始时的逻辑
	当前目标 = parent_buff.施法者 as Node2D if parent_buff != null else null
	var 配置的持续时间 = skill_manager._解析数值(buff_data.get("duration")) / 1000.0
	if 配置的持续时间 < 0:
		持续时间 = INF
	else:
		持续时间 = 配置的持续时间
	if 持续时间 == 0.0:
		_on_buff_timer_timeout()
		print_rich("[color=green]Buff %s 瞬间完成[/color]" % name)
		return
	buff_timer.wait_time = 持续时间
	buff_timer.one_shot = true
	buff_timer.timeout.connect(_on_buff_timer_timeout)
	add_child(buff_timer)
	buff_timer.start()
	print_rich("[color=green][%s秒] Buff %s 开始，持续时间：%.2f 秒[/color]" % [Time.get_ticks_msec()/1000.0, name, buff_timer.wait_time])


func on_buff_end() -> void:
	emit_signal("buff结束")
	# buff结束时的逻辑
	print_rich("[color=green][%s秒] Buff %s 结束[/color]" % [Time.get_ticks_msec()/1000.0, name])
	queue_free()


func _on_buff_timer_timeout() -> void:
	on_buff_end()


#region 技能行为
func skillAction_execute(action: Dictionary) -> void:
	match action.get("$type").split(".")[-1]:
		"ActionOnTarget":
			var target_selector = action.get("targetSelector")
			var buff_targets = target_selector_result(target_selector)
			# GameEvents.创建跳字.emit(施法者.global_position, str(len(buff_targets)), Color.YELLOW)
			var _action = action.get("action")
			for target in buff_targets:
				当前目标 = target
				skillAction_execute(_action)
		"CreateObj":
			var obj_id = int(action.get("id"))
			var obj_scene_path = skill_manager.子物体场景路径 + "/" + str(obj_id) + ".tscn" as String
			var obj_duration = skill_manager._解析数值(action.get("duration")) / 1000.0
			var obj_movement_config = action.get("movement")
			var obj_instance = load(obj_scene_path).instantiate() as 子物体
			obj_instance.global_position = 施法者.global_position
			var obj_duration_timer = Timer.new()
			obj_duration_timer.wait_time = obj_duration
			obj_duration_timer.one_shot = true
			obj_duration_timer.timeout.connect(func():
				obj_instance.queue_free()
			)

			var hitbox_collision_config = action.get("hitboxCollision")
			var collisionLayer = hitbox_collision_config.get("collisionLayer", [])
			var collisionMask = hitbox_collision_config.get("collisionMask", [])
			var disableOnSourceDie = hitbox_collision_config.get("disableOnSourceDie", false)
			if collisionLayer.size() > 0:
				obj_instance.get_node("HitboxComponent").collision_layer = 0
				for layer in collisionLayer:
					obj_instance.get_node("HitboxComponent").collision_layer |= int(layer)
			if collisionMask.size() > 0:
				obj_instance.get_node("HitboxComponent").collision_mask = 0
				for mask in collisionMask:
					obj_instance.get_node("HitboxComponent").collision_mask |= int(mask)
				obj_instance.get_node("HitboxComponent").disable_on_source_die = disableOnSourceDie

			var created_obj = create_obj(obj_instance, obj_movement_config, obj_duration_timer)
			created_obj.name = "SkillObj[%s]" % str(obj_id)
					

		"CreateHitbox":
			var obj_scene_path = skill_manager.子物体场景路径 + "/子物体.tscn" as String
			var obj_duration = skill_manager._解析数值(action.get("duration")) / 1000.0
			var obj_movement_config = action.get("movement")
			var obj_instance = load(obj_scene_path).instantiate() as 子物体
			obj_instance.global_position = 施法者.global_position
			var obj_duration_timer = Timer.new()
			obj_duration_timer.wait_time = obj_duration
			obj_duration_timer.one_shot = true
			obj_duration_timer.timeout.connect(func():
				obj_instance.queue_free()
			)

			var hitbox_half_width = skill_manager._解析数值(action.get("halfWidth"))
			var hitbox_half_height = skill_manager._解析数值(action.get("halfHeight"))
			var hitbox_collision_config = action.get("hitboxCollision")
			var collisionLayer = hitbox_collision_config.get("collisionLayer", [])
			var collisionMask = hitbox_collision_config.get("collisionMask", [])
			var disableOnSourceDie = hitbox_collision_config.get("disableOnSourceDie", false)
			if collisionLayer.size() > 0:
				obj_instance.get_node("HitboxComponent").collision_layer = 0
				for layer in collisionLayer:
					obj_instance.get_node("HitboxComponent").collision_layer |= int(layer)
			if collisionMask.size() > 0:
				obj_instance.get_node("HitboxComponent").collision_mask = 0
				for mask in collisionMask:
					obj_instance.get_node("HitboxComponent").collision_mask |= int(mask)
				obj_instance.get_node("HitboxComponent").disable_on_source_die = disableOnSourceDie
			
			
			var collision_shape = CollisionShape2D.new()
			collision_shape.shape = RectangleShape2D.new()
			collision_shape.name = "CollisionShape2D"
			obj_instance.get_node("HitboxComponent").add_child(collision_shape)
			collision_shape.shape.extents = Vector2(hitbox_half_width, hitbox_half_height)
			
			var created_obj = create_obj(obj_instance, obj_movement_config, obj_duration_timer)
			created_obj.name = "HitboxObj"
			
		_:
			print_rich("[color=red]未知的技能行为类型: %s[/color]" % action.get("$type"))


func create_obj(_obj_instance,_obj_movement_config,_obj_duration_timer) -> 子物体:
	_obj_instance.get_node("HitboxComponent").source = 施法者
	var 子物体运动类型 = _obj_movement_config.get("$type").split(".")[-1]
	match 子物体运动类型:
		"Line":
			var line_obj_direction = 当前目标.global_position.direction_to(施法者.global_position) * -1
			var toTarget = _obj_movement_config.get("toTarget")
			if not toTarget:
				var directX = skill_manager._解析数值(_obj_movement_config.get("directionX"))
				var directY = skill_manager._解析数值(_obj_movement_config.get("directionY"))
				line_obj_direction = Vector2(directX, directY).normalized().rotated(Vector2.DOWN.angle()).rotated(施法者.facingDirection.angle())
			var speed = skill_manager._解析数值(_obj_movement_config.get("speed"))
			_obj_instance.obj_process = func(delta: float) -> void:
				_obj_instance.global_position += line_obj_direction * speed * delta

		"Bind":
			var bind_to_caster = _obj_movement_config.get("bindToCaster", true)
			_obj_instance.obj_process = func(delta: float) -> void:
				if bind_to_caster:
					_obj_instance.global_position = 施法者.global_position
				else:
					_obj_instance.global_position = 当前目标.global_position
			
			
	_obj_instance.add_child(_obj_duration_timer)
	# TODO:更精细的hitbox管理
	skill_manager.get_tree().get_first_node_in_group("foreground_layer").add_child(_obj_instance)
	_obj_duration_timer.start()
	_obj_instance.set_physics_process(true)
	return _obj_instance

#endregion


#region 目标选择器
## TODO: 实现layer映射
func target_selector_result(target_selector_config: Dictionary) -> Array:
	var 类型 = target_selector_config.get("$type").split(".")[-1]
	match 类型:
		"expression":
			var expr = target_selector_config.get("expression", "")
			# 这里可以使用更复杂的表达式解析器
			return Expression.new().execute(expr)
		"caster":
			return [施法者]
		"circleArea":
			var radius = skill_manager._解析数值(target_selector_config.get("radius"))
			var fowardAngle = skill_manager._解析数值(target_selector_config.get("fowardAngle"))
			return skill_manager.get_target_in_circle_area(
				施法者.global_position,
				施法者.facingDirection,
				radius,
				fowardAngle,
				64,
			)
			
		_:
			push_error("[color=red][%s秒] 未知的目标选择器类型: %s[/color]" % [Time.get_ticks_msec()/1000.0, 类型])
			return []



#endregion
