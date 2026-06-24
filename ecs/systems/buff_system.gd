extends ECSSystemBase
class_name BuffSystem

## ECS Buff 系统
## 替代原来的 BuffInstance 中的所有逻辑
## 遍历所有拥有 BuffComponent 的 Entity，执行 Buff 生命周期、SkillAction

var _next_buff_id: int = 1

## SkillSystem 引用
var skill_system: SkillSystem = null

## SubObjectSystem 引用
var subobject_system: SubObjectSystem = null

## 事件总线（用于事件驱动替代直接调用）
var event_bus: Node = null

func _init(em: EntityManager) -> void:
	super._init(em)

func set_dependencies(deps: Dictionary) -> void:
	# 支持部分注入
	if deps.has("skill_system"):
		skill_system = deps["skill_system"]
	if deps.has("subobject_system"):
		subobject_system = deps["subobject_system"]
	if deps.has("event_bus"):
		event_bus = deps["event_bus"]
		# 订阅常用事件（示例）
		if event_bus and event_bus.has_signal("unit_died") and not event_bus.is_connected("unit_died", Callable(self, "_on_unit_died")):
			event_bus.connect("unit_died", Callable(self, "_on_unit_died"))

func update(delta: float) -> void:
	var entities = entity_manager.query_entities([ECSComponentTypes.ComponentType.BUFF])
	
	for eid in entities:
		var buffs = entity_manager.get_component(eid, ECSComponentTypes.ComponentType.BUFF)
		if buffs == null:
			continue
		# 倒序遍历以便安全删除
		for i in range(buffs.size() - 1, -1, -1):
			var buff: BuffComponentData = buffs[i]
			if not buff.is_active:
				buffs.remove_at(i)
				continue
			_update_buff(eid, buff, delta)

func create_buff(buff_data: Dictionary, caster_entity: int, parent_buff_id: int = -1) -> BuffComponentData:
	var buff = BuffComponentData.new()
	buff.buff_id = _next_buff_id
	_next_buff_id += 1
	buff.buff_name = buff_data.get("name", "BuffInstance")
	buff.buff_data = buff_data
	buff.caster_entity = caster_entity
	buff.current_target_entity = caster_entity  # 默认目标为施法者
	buff.parent_buff_id = parent_buff_id
	
	# 预编译表达式
	if skill_system:
		buff._compiled_duration = skill_system._编译数值(buff_data.get("duration", {}))
		buff._compiled_max_stack = skill_system._编译数值(buff_data.get("maxStack", {}))
	
	# 最大层数
	buff.max_stack = max(1, int(_快速求值(buff, buff._compiled_max_stack)))
	buff.current_stack = 1
	
	# 叠加类型
	var stack_type_config = buff_data.get("stackType")
	match stack_type_config:
		"none":
			buff.stack_type = BuffComponentData.buff叠加计时类型枚举.不改变计时
		"refresh":
			buff.stack_type = BuffComponentData.buff叠加计时类型枚举.叠加时刷新计时
		"independent":
			buff.stack_type = BuffComponentData.buff叠加计时类型枚举.每层独立计时
		"extend":
			buff.stack_type = BuffComponentData.buff叠加计时类型枚举.延长计时
	
	# 添加到 ECS
	var entity_buffs = entity_manager.get_component(caster_entity, ECSComponentTypes.ComponentType.BUFF)
	if entity_buffs == null:
		entity_buffs = []
		entity_manager.add_component(caster_entity, ECSComponentTypes.ComponentType.BUFF, entity_buffs)
	entity_buffs.append(buff)
	
	# Buff 开始
	_on_buff_start(caster_entity, buff)
	
	return buff

func _on_buff_start(entity_id: int, buff: BuffComponentData) -> void:
	var 配置的持续时间 = _快速求值(buff, buff._compiled_duration) / 1000.0
	if 配置的持续时间 < 0:
		buff.duration = INF
		GMLogger.log_buff("buff '%s' duration=-1 → INF" % buff.buff_name)
	else:
		buff.duration = 配置的持续时间
	
	# 执行 buff 逻辑（无论持续时间多少，逻辑都要执行）
	var buff_logic_data = buff.buff_data.get("buffLogic")
	if buff_logic_data:
		GMLogger.log_buff("执行 buff 逻辑: %s" % buff_logic_data.get("$type", "?"))
		_buff_execute(entity_id, buff, buff_logic_data)
	else:
		GMLogger.log_buff("buff '%s' 没有 buffLogic!" % buff.buff_name)
	
	# 处理顶层 OneBuff.animation 字段（BuffAnimation 类型，独立于 buffLogic.PlayAnimation）
	var animation_data: Dictionary = buff.buff_data.get("animation", {})
	if not animation_data.is_empty():
		var anim_type: String = animation_data.get("$type", "").split(".")[-1]
		if anim_type != "None":
			var caster = entity_manager.get_unit(entity_id)
			if is_instance_valid(caster) and "当前状态" in caster:
				if caster.当前状态 != caster.角色状态.死亡:
					GMLogger.log_buff("buff '%s' 触发动画: %s" % [buff.buff_name, anim_type])
					caster.施法动画参数 = animation_data.duplicate()
					caster.当前状态 = caster.角色状态.施法
					buff._is_play_animation = true
	
	if buff.duration == 0.0:
		_on_buff_end(entity_id, buff)
		return

func _on_buff_end(entity_id: int, buff: BuffComponentData) -> void:
	buff.is_active = false
	
	# 禁用此 buff 激活的所有预置 Hitbox
	for hitbox_info in buff._active_pre_hitbox_nodes:
		var hb = hitbox_info.get("node")
		if is_instance_valid(hb):
			hb.disable()
			GMLogger.log_buff("ActivePreHitbox: 已禁用 %s" % hitbox_info.get("name", "?"))
	buff._active_pre_hitbox_nodes.clear()
	
	# 处理 PlayAnimation 状态恢复
	if buff._is_play_animation:
		var caster = entity_manager.get_unit(entity_id)
		if is_instance_valid(caster) and "当前状态" in caster:
			if caster.当前状态 == caster.角色状态.施法:
				caster.当前状态 = caster.角色状态.待机
	
func _update_buff(entity_id: int, buff: BuffComponentData, delta: float) -> void:
	if not buff.is_active:
		return
	
	buff.elapsed += delta
	
	# 检查持续时间（跳过无限持续时间的 buff）
	if buff.duration > 0.0 and buff.duration < INF and buff.elapsed >= buff.duration:
		_on_buff_end(entity_id, buff)
		return
	
	# 驱动 ActionOverTime
	if not buff._action_over_time_action.is_empty():
		buff._action_over_time_elapsed += delta
		while buff._action_over_time_elapsed >= buff._action_over_time_interval:
			buff._action_over_time_elapsed -= buff._action_over_time_interval
			_skillAction_execute(entity_id, buff, buff._action_over_time_action)
	
	# 驱动 ActionTimeline
	for entry in buff._action_timeline_entries:
		if entry.get("triggered", false):
			continue
		entry["_remaining"] = entry.get("_remaining", entry["time_sec"]) - delta
		if entry["_remaining"] <= 0.0:
			entry["triggered"] = true
			_skillAction_execute(entity_id, buff, entry["action"])

#region BuffLogic

func _buff_execute(entity_id: int, buff: BuffComponentData, logic_data: Dictionary) -> void:
	var logic_type = logic_data.get("$type", "").split(".")[-1]
	match logic_type:
		"PlayAnimation":
			var caster = entity_manager.get_unit(entity_id)
			if not is_instance_valid(caster):
				return
			if "当前状态" in caster:
				if caster.当前状态 == caster.角色状态.死亡:
					return
				var anim_config: Dictionary = buff.buff_data.get("animation", {})
				caster.施法动画参数 = anim_config.duplicate()
				caster.当前状态 = caster.角色状态.施法
			buff._is_play_animation = true
			
		"BuffList":
			var buff_logics = logic_data.get("buffs", [])
			for logic in buff_logics:
				_buff_execute(entity_id, buff, logic)
		
		"ActionOverTime":
			if skill_system == null:
				push_error("[BuffSystem] skill_system 为空，无法设置 ActionOverTime")
				return
			var interval_compiled = skill_system._编译数值(logic_data.get("interval", {}))
			var interval = _快速求值(buff, interval_compiled) / 1000.0
			if interval <= 0.0:
				push_error("[color=red]ActionOverTime 的 interval 必须大于0[/color]")
				return
			buff._action_over_time_interval = interval
			buff._action_over_time_elapsed = 0.0
			buff._action_over_time_action = logic_data.get("action", {})
		
		"ActionTimeline":
			if skill_system == null:
				push_error("[BuffSystem] ActionTimeline: skill_system 为空!")
				return
			var actionOnTimeList = logic_data.get("actionOnTimeList", [])
			var timeMultiplier_compiled = skill_system._编译数值(logic_data.get("addTimeMultiplierPercent", {}))
			var timeMultiplier = _快速求值(buff, timeMultiplier_compiled)
			GMLogger.log_buff("ActionTimeline: timeMultiplier=%f, entries=%d" % [timeMultiplier, actionOnTimeList.size()])
			if timeMultiplier < -1.0:
				return
			buff._action_timeline_time_multiplier = timeMultiplier
			for actionOnTime in actionOnTimeList:
				var time_compiled = skill_system._编译数值(actionOnTime.get("time", {}))
				var time_sec = _快速求值(buff, time_compiled) / 1000.0
				var action = actionOnTime.get("action")
				if time_sec <= 0.0:
					_skillAction_execute(entity_id, buff, action)
					continue
				buff._action_timeline_entries.append({
					"time_sec": time_sec * (1 + timeMultiplier),
					"action": action,
					"triggered": false,
					"_remaining": time_sec * (1 + timeMultiplier)
				})
		_:
			GMLogger.log_buff("未知的buff逻辑类型: %s" % logic_data.get("$type"))

#endregion

#region SkillAction

func _skillAction_execute(entity_id: int, buff: BuffComponentData, action: Dictionary) -> void:
	match action.get("$type").split(".")[-1]:
		"ActionList":
			var actions = action.get("actions", [])
			for act in actions:
				_skillAction_execute(entity_id, buff, act)
		
		"ActionIfElse":
			if skill_system == null:
				return
			var condition = action.get("condition", {})
			var actionTrue_list = action.get("actionTrue", [])
			var actionFalses_list = action.get("actionFalse", [])
			var cond_compiled = skill_system._编译条件(condition)
			if _快速求值条件(buff, cond_compiled):
				for act in actionTrue_list:
					_skillAction_execute(entity_id, buff, act)
			else:
				for act in actionFalses_list:
					_skillAction_execute(entity_id, buff, act)
		
		"ActionOnTarget":
			var target_selector = action.get("targetSelector")
			var buff_targets = _target_selector_result(buff, target_selector)
			var inner_action = action.get("action")
			for target in buff_targets:
				if target is Node:
					# circleArea 返回的是 Area2D (hurtbox)，需要通过 owner 找到真正的 Unit
					var actual_target: Node = target
					if target is Area2D and is_instance_valid(target.owner) and target.owner != target:
						actual_target = target.owner
					buff.current_target_entity = entity_manager.get_entity_id(actual_target)
					# 存入目标位置到 blackboard，用于子 Action（如 CreateObj）在目标未注册 ECS 时仍能获取方向
					if actual_target is Node2D:
						buff.blackboard["_action_target_position"] = actual_target.global_position
				_skillAction_execute(entity_id, buff, inner_action)
		
		"CreateObj":
			if skill_system == null or subobject_system == null:
				return
			var caster = entity_manager.get_unit(entity_id)
			if caster == null:
				return
			var scene_name = action.get("sceneName", "")
			if scene_name == "":
				push_error("[BuffSystem] CreateObj 缺少 sceneName 字段")
				return
			var obj_scene_path = skill_system.子物体场景路径 + "/" + scene_name + ".tscn"
			var obj_duration_compiled = skill_system._编译数值(action.get("duration", {}))
			var obj_duration = _快速求值(buff, obj_duration_compiled) / 1000.0
			if obj_duration == 0.0:
				return
			
			var obj_movement_config = action.get("movement")
			var hitbox_collision_config = action.get("hitboxCollision", {})
			
			subobject_system.spawn_existing_obj(
				obj_scene_path,
				caster.global_position,
				obj_duration,
				obj_movement_config,
				entity_id,
				buff,
				entity_id,
				hitbox_collision_config
			)
		
		"CreateHitbox":
			if skill_system == null or subobject_system == null:
				push_error("[BuffSystem] CreateHitbox: skill_system=%s, subobject_system=%s" % [skill_system, subobject_system])
				return
			var caster = entity_manager.get_unit(entity_id)
			if caster == null:
				return
			var obj_scene_path = skill_system.子物体场景路径 + "/子物体.tscn"
			var obj_duration_compiled = skill_system._编译数值(action.get("duration", {}))
			var obj_duration = _快速求值(buff, obj_duration_compiled) / 1000.0
			GMLogger.log_buff("CreateHitbox: duration=%.3f, scene=%s" % [obj_duration, obj_scene_path])
			if obj_duration == 0.0:
				GMLogger.log_buff("CreateHitbox: duration==0, 跳过!")
				return
			
			var obj_movement_config = action.get("movement")
			var hitbox_collision_config = action.get("hitboxCollision", {})
			var hitbox_half_width = _快速求值(buff, skill_system._编译数值(action.get("halfWidth", {})))
			var hitbox_half_height = _快速求值(buff, skill_system._编译数值(action.get("halfHeight", {})))
			
			subobject_system.spawn_hitbox(
				obj_scene_path,
				caster.global_position,
				obj_duration,
				obj_movement_config,
				entity_id,
				buff,
				entity_id,
				hitbox_collision_config,
				Vector2(hitbox_half_width, hitbox_half_height)
			)
		
		"ActivePreHitbox":
			if skill_system == null or subobject_system == null:
				push_error("[BuffSystem] ActivePreHitbox: skill_system=%s, subobject_system=%s" % [skill_system, subobject_system])
				return
			var caster = entity_manager.get_unit(entity_id)
			if caster == null:
				push_error("[BuffSystem] ActivePreHitbox: caster 为空")
				return
			
			var hitbox_name = action.get("HitboxName", "TouchHitbox")
			var hitbox_node = caster.get_node_or_null(hitbox_name)
			if hitbox_node == null or not (hitbox_node is HitboxComponent):
				push_error("[BuffSystem] ActivePreHitbox: 在 %s 上找不到 HitboxComponent '%s'" % [caster.name, hitbox_name])
				return
			
			var hitbox = hitbox_node as HitboxComponent
			var hitbox_collision_config = action.get("hitboxCollision", {})
			_configure_pre_hitbox(hitbox, hitbox_collision_config, buff, entity_id)
			
			# 启用 hitbox
			hitbox.enable()
			GMLogger.log_buff("ActivePreHitbox: 已激活 %s 上的 '%s'" % [caster.name, hitbox_name])
			
			# 记录以便 buff 结束时清理
			buff._active_pre_hitbox_nodes.append({"node": hitbox, "name": hitbox_name})
		
		_:
			GMLogger.log_buff("未知的技能行为类型: %s" % action.get("$type"))

#endregion

#region ActivePreHitbox 配置

## 配置预置 HitboxComponent 的碰撞参数
func _configure_pre_hitbox(hitbox: HitboxComponent, collision_config: Dictionary, buff: BuffComponentData, entity_id: int) -> void:
	if collision_config.is_empty():
		return
	
	# 设置 source_entity 和 entity_manager
	hitbox.source_entity = entity_id
	hitbox._entity_manager = entity_manager
	
	# 碰撞层
	var collisionLayer = collision_config.get("collisionLayer", [])
	if collisionLayer.size() > 0:
		hitbox.collision_layer = 0
		for layer in collisionLayer:
			hitbox.collision_layer |= int(layer)
	
	# 碰撞掩码
	var collisionMask = collision_config.get("collisionMask", [])
	if collisionMask.size() > 0:
		hitbox.collision_mask = 0
		for mask in collisionMask:
			hitbox.collision_mask |= int(mask)
	
	# 碰撞重置间隔
	var collideResetInterval = 0.0
	if skill_system:
		var interval_compiled = skill_system._编译数值(collision_config.get("collideResetInterval", {}))
		collideResetInterval = _快速求值(buff, interval_compiled) / 1000.0
	hitbox.collide_reset_interval = collideResetInterval
	
	# disableOnSourceDie
	var disableOnSourceDie = collision_config.get("disableOnSourceDie", false)
	hitbox.disable_on_source_die = disableOnSourceDie
	if disableOnSourceDie:
		var caster = entity_manager.get_unit(entity_id)
		if caster and caster.has_signal("死亡"):
			if not caster.死亡.is_connected(Callable(hitbox, "disable")):
				caster.死亡.connect(Callable(hitbox, "disable"))
	
	# collideAction
	var collideAction = collision_config.get("collideAction", {})
	if not collideAction.is_empty():
		hitbox.collide_action = collideAction

#endregion

#region 目标选择器

func _target_selector_result(buff: BuffComponentData, config: Dictionary) -> Array:
	if skill_system == null:
		return []
	var caster = entity_manager.get_unit(buff.caster_entity)
	var type_name = config.get("$type").split(".")[-1]
	match type_name:
		"expression":
			var expr = config.get("expression", "")
			var expression = Expression.new()
			var err = expression.parse(expr)
			if err != OK:
				push_error("[BuffSystem] 目标选择器 expression 解析失败: %s" % expression.get_error_text())
				return []
			var result = expression.execute([])
			if expression.has_execute_failed():
				push_error("[BuffSystem] 目标选择器 expression 执行失败: %s" % expression.get_error_text())
				return []
			return result if typeof(result) == TYPE_ARRAY else [result]
		"caster":
			return [caster] if caster else []
		"circleArea":
			if caster == null:
				return []
			var radius = _快速求值(buff, skill_system._编译数值(config.get("radius", {})))
			var fowardAngle = _快速求值(buff, skill_system._编译数值(config.get("fowardAngle", {})))
			return skill_system._get_target_in_circle_area(
				caster.global_position,
				caster.facingDirection,
				radius,
				fowardAngle,
				64,
			)
		"LimitCount":
			var inner_selector = config.get("targetSelector", {})
			var results = _target_selector_result(buff, inner_selector)
			var max_count = int(_快速求值(buff, skill_system._编译数值(config.get("count", {}))))
			if max_count > 0 and results.size() > max_count:
				results.resize(max_count)
			return results
		_:
			push_error("[color=red]未知的目标选择器类型: %s[/color]" % type_name)
			return []

#endregion

#region 表达式求值

func _快速求值(buff: BuffComponentData, compiled: Callable) -> float:
	if compiled == null:
		return 0.0
	var ctx = _构建上下文(buff)
	return compiled.call(ctx)

func _快速求值条件(buff: BuffComponentData, compiled: Callable) -> bool:
	if compiled == null:
		return true
	var ctx = _构建上下文(buff)
	return compiled.call(ctx)

func _构建上下文(buff: BuffComponentData) -> Dictionary:
	var caster = entity_manager.get_unit(buff.caster_entity)
	var current_target = entity_manager.get_unit(buff.current_target_entity)
	return {
		"buff_instance": buff,
		"skill_manager": skill_system,
		"caster": caster,
		"current_target": current_target,
		"blackboard": buff.blackboard,
		"random": func() -> int: return randi() % 100 + 1,
	}

#endregion
