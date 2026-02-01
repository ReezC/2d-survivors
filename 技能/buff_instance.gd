extends Node
class_name BuffInstance

var 施法者: Node
var buff_data: Dictionary
var parent_buff:BuffInstance
var 持续时间: float = 0.0


var 层数: int = 0
var 最大层数: int = 1

var BlackBoard: Dictionary = {}
var buff_timer: Timer = Timer.new()
var 当前目标: Node2D = null

var skill_manager: Node

signal buff开始
signal buff结束

enum buff叠加计时类型 {
	不改变计时,
	叠加时刷新计时,
	每层独立计时,
	延长计时,
}


func _init(_buff_data: Dictionary, _施法者: Node,_parent_buff:BuffInstance = null) -> void:
	name = _buff_data.get("name", "BuffInstance")
	buff_data = _buff_data
	施法者 = _施法者
	parent_buff = _parent_buff if _parent_buff != null else self
	
	# TODO：叠层逻辑在此时处理
	最大层数 = max(1, int(_解析数值(buff_data.get("maxStack"))))
	


## 技能
## └──buff
##    ├──effect1
##    ├──effect2
##    └──...

func _ready() -> void:
	on_buff_start()
	var buff_logic_data = buff_data.get("buffLogic")
	buff_excute(buff_logic_data)
	skill_manager = 施法者.skill_manager

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
			var interval = _解析数值(buff_logic_data.get("interval")) / 1000.0
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
	当前目标 = parent_buff.施法者 as Node2D if parent_buff != null else 施法者 as Node2D
	var 配置的持续时间 = _解析数值(buff_data.get("duration")) / 1000.0
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
			var obj_duration = _解析数值(action.get("duration")) / 1000.0
			var obj_movement_config = action.get("movement")
			match obj_movement_config.get("$type").split(".")[-1]:
				"Line":
					var line_obj_direction = 当前目标.global_position.direction_to(施法者.global_position) * -1
					var toTarget = obj_movement_config.get("toTarget")
					if not toTarget:
						var directX = _解析数值(obj_movement_config.get("directionX"))
						var directY = _解析数值(obj_movement_config.get("directionY"))
						line_obj_direction = Vector2(directX, directY).normalized().rotated(Vector2.DOWN.angle()).rotated(施法者.facingDirection.angle())
					var speed = _解析数值(obj_movement_config.get("speed"))
					var obj_instance = load(obj_scene_path).instantiate() as 子物体
					obj_instance.global_position = 施法者.global_position
					var obj_duration_timer = Timer.new()
					obj_duration_timer.wait_time = obj_duration
					obj_duration_timer.one_shot = true
					obj_duration_timer.timeout.connect(func():
						obj_instance.queue_free()
					)
					obj_instance.add_child(obj_duration_timer)
					# TODO:更精细的hitbox管理
					skill_manager.get_tree().get_first_node_in_group("foreground_layer").add_child(obj_instance)
					obj_instance.hitbox_component.source = 施法者
					obj_duration_timer.start()
					obj_instance.set_physics_process(true)
					obj_instance.obj_process = func(delta: float) -> void:
						obj_instance.global_position += line_obj_direction * speed * delta

					
		_:
			print_rich("[color=red]未知的技能行为类型: %s[/color]" % action.get("$type"))
	

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
			var radius = _解析数值(target_selector_config.get("radius"))
			var fowardAngle = _解析数值(target_selector_config.get("fowardAngle"))
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


#region 数值与条件解析器
func _解析数值(值配置:Dictionary) -> float:
	var 类型 = 值配置.get("$type").split(".")[-1]
	match 类型:
		"Const":
			var v = 值配置.get("value")
			return float(v) if v != null else 0.0
		"Expression":
			var expr = 值配置.get("expression", "0.0")
			# 这里可以使用更复杂的表达式解析器
			return Expression.new().execute(expr)
		"Add":
			var values = 值配置.get("values", [])
			var 总和: float = 0.0
			for v in values:
				总和 += _解析数值(v)
			return 总和
		"Minus":
			var value1 = 值配置.get("value1", {})
			var value2 = 值配置.get("value2", {})
			return _解析数值(value1) - _解析数值(value2)
		"Multiply":
			var values = 值配置.get("values", [])
			var 积: float = 1.0
			for v in values:
				积 *= _解析数值(v)
			return 积
		"Divide":
			var 被除数 = 值配置.get("value1", {})
			var 除数 = 值配置.get("value2", {})
			var 除数值 = _解析数值(除数)
			if 除数值 != 0.0:
				return _解析数值(被除数) / 除数值
			else:
				push_error("[color=red]除数不能为零[/color]")
				return 0.0
		"Int":
			return float(int(_解析数值(值配置.get("value", {}))))
		_:
			push_error("[color=red]未知的数值类型: %s[/color]" % 类型)
			return 0.0

func _解析条件(条件配置:Dictionary)->bool:
	var 类型 = 条件配置.get("$type").split(".")[-1]
	match 类型:
		"Const":
			return 条件配置.get("value", false)
		"expression":
			var expr = 条件配置.get("expression", "false")
			# 这里可以使用更复杂的表达式解析器
			return Expression.new().execute(expr)
		"Chance":
			var 几率百分比 = 条件配置.get("chance", 0.0)
			var 几率百分比加成 = 条件配置.get("addChances",[])
			for 加成 in 几率百分比加成:
				几率百分比 += _解析数值(加成)
			var 随机值 = randi() % 100 + 1
			return 随机值 < 几率百分比
		"Gte":
			var value1 = 条件配置.get("value1", {})
			var value2 = 条件配置.get("value2", {})
			return _解析数值(value1) >= _解析数值(value2)
		"Lte":
			var value1 = 条件配置.get("value1", {})
			var value2 = 条件配置.get("value2", {})
			return _解析数值(value1) <= _解析数值(value2)
		"Equal":
			var value1 = 条件配置.get("value1", {})
			var value2 = 条件配置.get("value2", {})
			return _解析数值(value1) == _解析数值(value2)
		"And":
			var conditions = 条件配置.get("conditions", [])
			for cond in conditions:
				if not _解析条件(cond):
					return false
			return true
		"Or":
			var conditions = 条件配置.get("conditions", [])
			for cond in conditions:
				if _解析条件(cond):
					return true
			return false
		"Not":
			var condition = 条件配置.get("condition", {})
			return not _解析条件(condition)
		_:
			push_error("[color=red]未知的条件类型: %s[/color]" % 类型)
			return false
#endregion
