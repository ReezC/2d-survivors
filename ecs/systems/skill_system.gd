extends ECSSystemBase
class_name SkillSystem

## ECS 技能系统
## 替代原来的 SkillManager 中的技能管理逻辑
## 遍历所有拥有 SkillComponent 的 Entity，执行 AI 决策、冷却更新、释放技能

enum AI类型枚举 {
	无,
	Player技能AI,
	Enemy技能AI,
}

## 预编译表达式缓存
static var _compiled_float_cache: Dictionary = {}
static var _compiled_cond_cache: Dictionary = {}
static var _compiler := ExprCompiler.new()

## AI 类型（int 类型，接收来自 SkillManager.AI类型枚举 的赋值）
var skill_ai: int = 0  # 0=无, 1=Player技能AI, 2=Enemy技能AI

## 子物体场景路径
var 子物体场景路径: String = "res://技能/子物体"

## Player AI 的目标扫描相关
var _player_scan_timer: float = 0.0
var _player_scan_interval: float = 0.2
var _player_locked_target: Node2D = null

## BuffSystem 引用（用于创建 Buff）
var buff_system: BuffSystem = null

## SubObjectSystem 引用（用于创建子物体）
var subobject_system: SubObjectSystem = null

## 事件总线
var event_bus: Node = null

func set_dependencies(deps: Dictionary) -> void:
	if deps.has("buff_system"):
		buff_system = deps["buff_system"]
	if deps.has("subobject_system"):
		subobject_system = deps["subobject_system"]
	if deps.has("event_bus"):
		event_bus = deps["event_bus"]

## 获取技能拥有者的可读名称
func _owner_name(entity_id: int) -> String:
	var unit = entity_manager.get_unit(entity_id)
	if unit == null:
		return "entity=%d" % entity_id
	if unit.has_method("get") and "unit_name" in unit:
		return "%s (entity=%d)" % [unit.unit_name, entity_id]
	return "%s (entity=%d)" % [unit.name, entity_id]

func _init(em: EntityManager) -> void:
	super._init(em)

@warning_ignore("unused_private_class_variable")
var _skill_ai_warned: bool = false

func update(delta: float) -> void:
	# 始终更新所有实体的冷却
	_update_cooldowns(delta)
	# 同时运行玩家和敌人 AI（不再依赖全局 skill_ai 变量）
	_update_player_ai(delta)
	_update_enemy_ai(delta)

## 为 Unit 注册技能
func register_entity(unit: Node, skill_data_list: Array[技能数据]) -> void:
	var eid = entity_manager.get_entity_id(unit)
	if eid == -1:
		eid = entity_manager.create_entity(unit)
	
	# 从 技能数据 列表创建 SkillComponentData
	var skill_components: Array[SkillComponentData] = []
	for skill_res in skill_data_list:
		var scd = _create_skill_component(skill_res, unit, eid)
		skill_components.append(scd)
	
	entity_manager.add_component(eid, ECSComponentTypes.ComponentType.SKILL, skill_components)

## 从技能数据创建 SkillComponentData
func _create_skill_component(skill_res: 技能数据, caster: Node, eid: int) -> SkillComponentData:
	var scd = SkillComponentData.new()
	scd.技能本体数据 = skill_res
	scd.id = skill_res.技能ID
	scd.技能名称 = skill_res.技能名称
	
	skill_res.解析技能配置()
	scd.skill_logic_data = skill_res.技能逻辑
	scd.技能类型 = skill_res.技能类型
	
	# 预编译表达式
	scd._compiled_cd = _编译数值(skill_res.获取技能CD() if typeof(skill_res.获取技能CD()) == TYPE_DICTIONARY else {"$type": "skillconfig.FloatValue.Const", "value": skill_res.获取技能CD()})
	scd._compiled_trigger_range = _编译数值(skill_res.获取技能触发范围() if typeof(skill_res.获取技能触发范围()) == TYPE_DICTIONARY else {"$type": "skillconfig.FloatValue.Const", "value": skill_res.获取技能触发范围()})
	
	# 计算冷却时间（配置值单位为毫秒，转换为秒）
	var 冷却时间配置 = skill_res.获取技能CD()
	if typeof(冷却时间配置) == TYPE_DICTIONARY:
		if scd._compiled_cd:
			scd.冷却时间 = max(0, _求值数值(scd._compiled_cd, null, caster)) / 1000.0
	else:
		scd.冷却时间 = float(冷却时间配置) / 1000.0
	
	# 计算触发范围
	var 触发范围配置 = skill_res.获取技能触发范围()
	if typeof(触发范围配置) == TYPE_DICTIONARY:
		if scd._compiled_trigger_range:
			scd.技能触发范围 = max(0, _求值数值(scd._compiled_trigger_range, null, caster))
	else:
		scd.技能触发范围 = float(触发范围配置)
	
	scd.动画名称 = skill_res.技能逻辑.get("buffOccupyAnim", "")
	
	# 应用冷却缩减
	if caster.has_method("get") and "attribute_component" in caster:
		var attr_comp = caster.attribute_component
		var 冷却缩减 = attr_comp.获取属性值("冷却缩减")
		scd.冷却时间 = scd.冷却时间 * (1.0 - 冷却缩减)
	
	# 被动技能直接释放
	if scd.技能类型 == 技能数据.技能类型枚举.被动技能:
		GMLogger.log_skill("[%s] 被动技能生效: %s (id=%d)" % [_owner_name(eid), scd.技能名称, scd.id])
		_cast_skill_internal(eid, scd)
	
	return scd

## 初始化所有技能（对已注册的 entity 的被动技能释放）
func 初始化技能() -> void:
	var entities = entity_manager.query_entities([ECSComponentTypes.ComponentType.SKILL])
	for eid in entities:
		var skills = entity_manager.get_component(eid, ECSComponentTypes.ComponentType.SKILL)
		if skills == null:
			continue
		for scd in skills:
			if scd.技能类型 == 技能数据.技能类型枚举.被动技能 and scd.当前状态 == SkillComponentData.技能状态.准备就绪:
				_cast_skill_internal(eid, scd)

#region AI 逻辑

func _update_player_ai(delta: float) -> void:
	# 定时扫描目标
	_player_scan_timer -= delta
	if _player_scan_timer <= 0.0:
		_player_scan_timer = _player_scan_interval
		_player_scan_for_target()
	
	# 尝试释放技能
	if _player_locked_target != null and is_instance_valid(_player_locked_target):
		_try_cast_skills_for_group(_player_locked_target, "player")

## 敌人 AI：每个敌人独立扫描玩家并尝试释放技能
func _update_enemy_ai(delta: float) -> void:
	var entities = entity_manager.query_entities([ECSComponentTypes.ComponentType.SKILL])
	for eid in entities:
		var caster = entity_manager.get_unit(eid)
		if caster == null:
			continue
		if not "enemy" in caster.get_groups():
			continue
		# 检查死亡
		if caster.has_method("get") and "当前状态" in caster:
			if caster.当前状态 == caster.角色状态.死亡:
				continue
		
		# 获取该敌人的主动技能最大触发范围
		var skills = entity_manager.get_component(eid, ECSComponentTypes.ComponentType.SKILL)
		if skills == null:
			continue
		var max_range: float = 0.0
		var has_ready_skill: bool = false
		for scd in skills:
			if scd.技能类型 == 技能数据.技能类型枚举.主动技能 and scd.当前状态 == SkillComponentData.技能状态.准备就绪:
				has_ready_skill = true
				max_range = max(max_range, scd.技能触发范围)
		
		if not has_ready_skill:
			continue
		
		# 扫描范围内最近的玩家
		var player = _get_nearest_target_in_group(caster, max_range, "player", GameEvents.collision_layer_enum.玩家hurtbox)
		if player == null:
			continue
		
		# 尝试释放技能
		for scd in skills:
			if scd.技能类型 != 技能数据.技能类型枚举.主动技能:
				continue
			if scd.当前状态 != SkillComponentData.技能状态.准备就绪:
				continue
			var dist = caster.global_position.distance_to(player.global_position)
			if dist <= scd.技能触发范围:
				释放技能(eid, scd.id)
				break

## 扫描范围内最近的某 group 目标
func _get_nearest_target_in_group(caster: Node2D, max_range: float, target_group: String, collision_layer: int) -> Node2D:
	var available_targets = _get_target_in_circle_area(
		caster.global_position,
		Vector2.RIGHT.rotated(caster.rotation),
		max_range,
		360.0,
		collision_layer
	)
	var actual_targets: Array = []
	for t in available_targets:
		var unit: Node = t
		if t is Area2D and is_instance_valid(t.owner) and t.owner != t:
			unit = t.owner
		if unit is Node and target_group in unit.get_groups():
			actual_targets.append(unit)
	return _get_nearest_target(caster, actual_targets)

func _player_scan_for_target() -> void:
	var entities = entity_manager.query_entities([ECSComponentTypes.ComponentType.SKILL])
	var max_range: float = 0.0
	var player_eid: int = -1
	
	for eid in entities:
		var skills = entity_manager.get_component(eid, ECSComponentTypes.ComponentType.SKILL)
		if skills == null:
			continue
		for scd in skills:
			if scd.技能类型 != 技能数据.技能类型枚举.主动技能:
				continue
			if scd.当前状态 == SkillComponentData.技能状态.准备就绪:
				var unit = entity_manager.get_unit(eid)
				if unit and "player" in unit.get_groups():
					max_range = max(max_range, scd.技能触发范围)
					player_eid = eid
	
	if max_range <= 0.0 or player_eid == -1:
		if _player_locked_target != null:
			_player_locked_target = null
		return
	
	var player = entity_manager.get_unit(player_eid)
	if player == null:
		return
	
	var available_targets = _get_target_in_circle_area(
		player.global_position,
		Vector2.RIGHT.rotated(player.rotation),
		max_range,
		360.0,
		GameEvents.collision_layer_enum.敌人hurtbox
	)
	# _get_target_in_circle_area 返回的是 Area2D (hurtbox)，需要获取其 owner（真正的 Unit）
	var actual_targets: Array = []
	for t in available_targets:
		if t is Area2D and is_instance_valid(t.owner) and t.owner != t:
			actual_targets.append(t.owner)
		else:
			actual_targets.append(t)
	_player_locked_target = _get_nearest_target(player, actual_targets)

func _try_cast_skills_for_group(target: Node2D, caster_group: String) -> void:
	var entities = entity_manager.query_entities([ECSComponentTypes.ComponentType.SKILL])
	for eid in entities:
		var caster = entity_manager.get_unit(eid)
		if caster == null:
			continue
		if caster_group not in caster.get_groups():
			continue
		# 检查施法者是否处于可释放技能的状态
		if caster.has_method("get") and "当前状态" in caster:
			if caster.当前状态 == caster.角色状态.死亡:
				continue
		var skills = entity_manager.get_component(eid, ECSComponentTypes.ComponentType.SKILL)
		if skills == null:
			continue
		for scd in skills:
			if scd.技能类型 != 技能数据.技能类型枚举.主动技能:
				continue
			if scd.当前状态 != SkillComponentData.技能状态.准备就绪:
				continue
			var dist = caster.global_position.distance_to(target.global_position)
			if dist <= scd.技能触发范围:
				释放技能(eid, scd.id)
				return

func _update_cooldowns(delta: float) -> void:
	var entities = entity_manager.query_entities([ECSComponentTypes.ComponentType.SKILL])
	for eid in entities:
		var skills = entity_manager.get_component(eid, ECSComponentTypes.ComponentType.SKILL)
		if skills == null:
			continue
		for scd in skills:
			if scd.当前状态 == SkillComponentData.技能状态.冷却中:
				scd.cd_remaining -= delta
				if scd.cd_remaining <= 0.0:
					scd.cd_remaining = 0.0
					scd.当前状态 = SkillComponentData.技能状态.准备就绪
					GMLogger.log_skill("[%s] 技能就绪: %s (id=%d)" % [_owner_name(eid), scd.技能名称, scd.id])

func _get_nearest_target(owner_node: Node2D, targets: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for t in targets:
		var target_node = t as Node2D
		if target_node == null:
			continue
		var dist = owner_node.global_position.distance_to(target_node.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = target_node
	return nearest

#endregion

#region 技能释放

func 释放技能(entity_id: int, 技能ID: int) -> void:
	var skills = entity_manager.get_component(entity_id, ECSComponentTypes.ComponentType.SKILL)
	if skills == null:
		return
	
	for scd in skills:
		if scd.id == 技能ID and scd.当前状态 == SkillComponentData.技能状态.准备就绪:
			_cast_skill_internal(entity_id, scd)
			return

func _cast_skill_internal(entity_id: int, scd: SkillComponentData) -> void:
	var skill_buff_data = scd.skill_logic_data.get("buff", null)
	if skill_buff_data == null or skill_buff_data.is_empty():
		GMLogger.log_skill("[%s] 技能释放失败: %s (id=%d) — 无 buff 数据" % [_owner_name(entity_id), scd.技能名称, scd.id])
		return
	
	# 通过 BuffSystem 创建 Buff（不再传递 caster Node）
	if buff_system:
		GMLogger.log_skill("[%s] 技能释放: %s (id=%d)" % [_owner_name(entity_id), scd.技能名称, scd.id])
		buff_system.create_buff(skill_buff_data, entity_id, -1)
	else:
		push_error("[SkillSystem] buff_system 未设置，无法创建 Buff！")
		GMLogger.log_skill("[%s] 技能释放失败: %s (id=%d) — buff_system 未设置" % [_owner_name(entity_id), scd.技能名称, scd.id])
	
	match scd.技能类型:
		技能数据.技能类型枚举.主动技能:
			# 进入冷却
			if scd.冷却时间 > 0.0:
				scd.当前状态 = SkillComponentData.技能状态.冷却中
				scd.cd_remaining = scd.冷却时间
				GMLogger.log_skill("[%s] 技能进入冷却: %s (id=%d), CD=%.2fs" % [_owner_name(entity_id), scd.技能名称, scd.id, scd.冷却时间])
			else:
				scd.当前状态 = SkillComponentData.技能状态.准备就绪
			
			# 播放技能动画
			if scd.动画名称 != "":
				var caster = entity_manager.get_unit(entity_id)
				if caster:
					var dur_compiled = _编译数值(skill_buff_data.get("duration", {}))
					var 动画持续时间 = _求值数值(dur_compiled, null, caster)
					_播放技能动画(caster, scd.动画名称, 动画持续时间)
		技能数据.技能类型枚举.被动技能:
			# 被动技能 Buff 已创建，标记为已生效防止重复释放
			scd.当前状态 = SkillComponentData.技能状态.已生效

static func _播放技能动画(who: Node2D, 动画名称: String, 技能动画持续时间: float) -> void:
	if not is_instance_valid(who):
		return
	if who.has_method("get") and "当前状态" in who:
		if who.当前状态 == who.角色状态.死亡:
			return
		var anim_config: Dictionary = {
			"$type": "skillconfig.BuffAnimation.Single",
			"animationName": 动画名称,
		}
		who.施法动画参数 = anim_config
		who.当前状态 = who.角色状态.施法
	
	var anim_timer = Timer.new()
	anim_timer.wait_time = 技能动画持续时间 / 1000.0
	anim_timer.one_shot = true
	anim_timer.name = "SkillAnimTimer"
	var who_ref = weakref(who)
	anim_timer.timeout.connect(func():
		var w = who_ref.get_ref()
		if w and "当前状态" in w:
			w.当前状态 = w.角色状态.待机
	)
	who.add_child(anim_timer)
	anim_timer.start()

#endregion

#region 目标扫描

func _get_target_in_circle_area(
	center_position: Vector2,
	direction: Vector2,
	radius: float,
	angle_deg: float,
	target_collision_layer: int
) -> Array:
	# 需要场景树引用
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return []
	var space_state = tree.root.world_2d.direct_space_state
	
	var targets_in_area = []
	var target_set = {}
	
	var sector_polygon = _create_sector_polygon(Vector2.ZERO, direction, radius, angle_deg)
	if sector_polygon.size() < 3:
		return []
	
	var polygon_shape = ConvexPolygonShape2D.new()
	polygon_shape.points = sector_polygon
	
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = polygon_shape
	query.transform = Transform2D(0, center_position)
	query.collision_mask = target_collision_layer
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results = space_state.intersect_shape(query, 100)
	for result in results:
		var obj = result.collider
		if obj == null:
			continue
		var rid = obj.get_rid()
		if not target_set.has(rid) and obj.monitorable == true:
			target_set[rid] = true
			targets_in_area.append(obj)
	
	return targets_in_area

func _create_sector_polygon(center: Vector2, direction: Vector2, radius: float, angle_deg: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var half_angle_rad = deg_to_rad(min(angle_deg, 360)) / 2.0
	var start_angle = direction.angle() - half_angle_rad
	var end_angle = direction.angle() + half_angle_rad
	var num_points = int(ceil(angle_deg / 15.0))
	
	for i in range(num_points + 1):
		var t = float(i) / float(num_points)
		var angle = lerp(start_angle, end_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

#endregion

#region 表达式编译与求值

func _编译数值(值配置: Dictionary) -> Callable:
	if 值配置 == null or 值配置.is_empty():
		return func(_ctx: Dictionary) -> float: return 0.0
	var key = JSON.stringify(值配置)
	if _compiled_float_cache.has(key):
		return _compiled_float_cache[key]
	var compiled = _compiler.compile_float_value(值配置)
	_compiled_float_cache[key] = compiled
	return compiled

func _编译条件(条件配置: Dictionary) -> Callable:
	if 条件配置 == null or 条件配置.is_empty():
		return func(_ctx: Dictionary) -> bool: return true
	var key = JSON.stringify(条件配置)
	if _compiled_cond_cache.has(key):
		return _compiled_cond_cache[key]
	var compiled = _compiler.compile_condition(条件配置)
	_compiled_cond_cache[key] = compiled
	return compiled

func _求值数值(compiled: Callable, source_buff: BuffComponentData = null, caster_override: Node = null) -> float:
	var ctx = _构建上下文(source_buff, caster_override)
	return compiled.call(ctx)

func _求值条件(compiled: Callable, source_buff: BuffComponentData = null, caster_override: Node = null) -> bool:
	var ctx = _构建上下文(source_buff, caster_override)
	return compiled.call(ctx)

func _构建上下文(source_buff: BuffComponentData = null, caster_override: Node = null) -> Dictionary:
	var caster: Node = null
	var current_target: Node = null
	if source_buff:
		caster = entity_manager.get_unit(source_buff.caster_entity)
		current_target = entity_manager.get_unit(source_buff.current_target_entity)
	elif caster_override:
		caster = caster_override
	
	return {
		"buff_instance": source_buff,
		"skill_manager": self,
		"caster": caster,
		"current_target": current_target,
		"blackboard": source_buff.blackboard if source_buff else {},
		"random": func() -> int: return randi() % 100 + 1,
	}
#endregion
