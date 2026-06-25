extends ECSSystemBase
class_name SubObjectSystem

## ECS 子物体系统
## 统一管理所有由技能创建的 Hitbox/弹幕子物体
## 替代原来分散在 BuffInstance.create_obj 中的 add_child + Timer 模式

## 活跃子物体追踪
class TrackedObject:
	var node: 子物体
	var remaining_time: float
	var owner_entity: int
	var source_buff: BuffComponentData
	
	func _init(n: 子物体, dur: float, eid: int, buff: BuffComponentData) -> void:
		node = n
		remaining_time = dur
		owner_entity = eid
		source_buff = buff

var _active_objects: Array[TrackedObject] = []

## SkillSystem 引用（用于编译表达式）
var skill_system: SkillSystem = null

## 事件总线
var event_bus: Node = null

func _init(em: EntityManager) -> void:
	super._init(em)

func set_dependencies(deps: Dictionary) -> void:
	if deps.has("skill_system"):
		skill_system = deps["skill_system"]
	if deps.has("event_bus"):
		event_bus = deps["event_bus"]

func update(delta: float) -> void:
	for i in range(_active_objects.size() - 1, -1, -1):
		var tracked: TrackedObject = _active_objects[i]
		var obj = tracked.node
		if not is_instance_valid(obj):
			_active_objects.remove_at(i)
			continue
		
		# 只有有限持续时间的子物体才计时（负数表示无限持续）
		if tracked.remaining_time > 0.0:
			tracked.remaining_time -= delta
			if tracked.remaining_time <= 0.0:
				obj.queue_free()
				_active_objects.remove_at(i)
				continue
		
		# 执行自定义运动
		if obj.obj_process and obj.obj_process is Callable:
			obj.obj_process.call(delta)

## 创建已存在的预制子物体（CreateObj）
func spawn_existing_obj(
	scene_path: String,
	position: Vector2,
	duration: float,
	movement_config: Dictionary,
	caster_entity: int,
	buff: BuffComponentData,
	owner_entity: int,
	hitbox_collision_config: Dictionary
) -> 子物体:
	var obj_instance = load(scene_path).instantiate() as 子物体
	if obj_instance == null:
		push_error("[SubObjectSystem] 无法加载子物体场景: %s" % scene_path)
		return null
	
	obj_instance.global_position = position
	
	# 根据施法者水平朝向翻转子物体
	_apply_facing_flip(obj_instance, caster_entity)
	
	# 配置碰撞层
	_configure_hitbox(obj_instance, hitbox_collision_config, buff)
	
	# 配置运动（通过 entity_id 而非 Node）
	_configure_movement(obj_instance, movement_config, caster_entity, buff)
	
	# 添加到场景
	_add_to_foreground(obj_instance)
	
	# 设置 Hitbox source_entity 和 entity_manager
	var hitbox = obj_instance.get_node_or_null("HitboxComponent")
	if hitbox and hitbox.has_method("set"):
		hitbox.set("source_entity", caster_entity)
		hitbox.set("_entity_manager", entity_manager)
	
	# 追踪
	var tracked = TrackedObject.new(obj_instance, duration, owner_entity, buff)
	_active_objects.append(tracked)
	
	obj_instance.set_physics_process(true)
	obj_instance.name = "SkillObj"
	
	return obj_instance

## 创建 Hitbox 子物体（CreateHitbox）
func spawn_hitbox(
	scene_path: String,
	position: Vector2,
	duration: float,
	movement_config: Dictionary,
	caster_entity: int,
	buff: BuffComponentData,
	owner_entity: int,
	hitbox_collision_config: Dictionary,
	half_extents: Vector2
) -> 子物体:
	var obj_instance = load(scene_path).instantiate() as 子物体
	if obj_instance == null:
		push_error("[SubObjectSystem] 无法加载子物体场景: %s" % scene_path)
		return null
	
	obj_instance.global_position = position
	
	# 根据施法者水平朝向翻转子物体
	_apply_facing_flip(obj_instance, caster_entity)
	
	# 配置碰撞层
	_configure_hitbox(obj_instance, hitbox_collision_config, buff)
	
	# 创建矩形碰撞形状（Godot 4 使用 size，不是 extents）
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = half_extents * 2.0
	collision_shape.shape = rect_shape
	collision_shape.name = "CollisionShape2D"
	
	var hitbox_node = obj_instance.get_node_or_null("HitboxComponent")
	if hitbox_node:
		hitbox_node.add_child(collision_shape)
	
	# 配置运动（通过 entity_id 而非 Node）
	_configure_movement(obj_instance, movement_config, caster_entity, buff)
	
	# 添加到场景
	_add_to_foreground(obj_instance)
	
	# 设置 Hitbox source_entity 和 entity_manager
	if hitbox_node and hitbox_node.has_method("set"):
		hitbox_node.set("source_entity", caster_entity)
		hitbox_node.set("_entity_manager", entity_manager)
	
	# 追踪
	var tracked = TrackedObject.new(obj_instance, duration, owner_entity, buff)
	_active_objects.append(tracked)
	
	obj_instance.set_physics_process(true)
	obj_instance.name = "HitboxObj"
	
	GMLogger.log_buff("spawn_hitbox 完成: pos=(%.1f,%.1f), dur=%.3f, size=(%.1f,%.1f), total=%d" % [position.x, position.y, duration, half_extents.x, half_extents.y, _active_objects.size()])
	
	return obj_instance

## 根据施法者水平朝向翻转子物体
## 精灵默认朝左，朝右时 scale.x = -1 实现镜像翻转
func _apply_facing_flip(obj: 子物体, caster_entity: int) -> void:
	var caster = entity_manager.get_unit(caster_entity)
	if caster == null:
		return
	if not "facingDirection" in caster:
		return
	var facing_x: float = caster.facingDirection.x
	if facing_x > 0.0:
		obj.scale.x = -abs(obj.scale.x)
	elif facing_x < 0.0:
		obj.scale.x = abs(obj.scale.x)


## 配置 Hitbox 碰撞
func _configure_hitbox(obj: 子物体, collision_config: Dictionary, buff: BuffComponentData) -> void:
	if collision_config.is_empty():
		return
	
	var hitbox = obj.get_node_or_null("HitboxComponent")
	if hitbox == null:
		return
	
	var collisionLayer = collision_config.get("collisionLayer", [])
	var collisionMask = collision_config.get("collisionMask", [])
	var disableOnSourceDie = collision_config.get("disableOnSourceDie", false)
	
	var collideResetInterval = 0.0
	if skill_system:
		var interval_compiled = skill_system._编译数值(collision_config.get("collideResetInterval", {}))
		collideResetInterval = _快速求值(buff, interval_compiled) / 1000.0
	
	if collisionLayer.size() > 0:
		hitbox.collision_layer = 0
		for layer in collisionLayer:
			hitbox.collision_layer |= int(layer)
	
	if collisionMask.size() > 0:
		hitbox.collision_mask = 0
		for mask in collisionMask:
			hitbox.collision_mask |= int(mask)
	
	if "disable_on_source_die" in hitbox:
		hitbox.disable_on_source_die = disableOnSourceDie
	if "collide_reset_interval" in hitbox:
		hitbox.collide_reset_interval = collideResetInterval
	
	# 传递 collideAction 配置到 HitboxComponent
	var collideAction = collision_config.get("collideAction", {})
	if not collideAction.is_empty() and "collide_action" in hitbox:
		hitbox.collide_action = collideAction

## 配置子物体运动
func _configure_movement(obj: 子物体, movement_config: Dictionary, caster_entity: int, buff: BuffComponentData) -> void:
	if movement_config.is_empty():
		return
	
	var caster = entity_manager.get_unit(caster_entity)
	if caster == null:
		return
	
	var movement_type = movement_config.get("$type").split(".")[-1]
	match movement_type:
		"Line":
			var current_target = entity_manager.get_unit(buff.current_target_entity) if buff else caster
			# 如果目标未注册 ECS（如敌人没有 SkillManager），从 blackboard 获取目标位置
			var target_pos = current_target.global_position if current_target else null
			if target_pos == null and buff and buff.blackboard.has("_action_target_position"):
				target_pos = buff.blackboard["_action_target_position"]
			var line_obj_direction = caster.global_position.direction_to(target_pos) if target_pos else Vector2.RIGHT
			
			var toTarget = movement_config.get("toTarget")
			if not toTarget:
				var directX = _快速求值(buff, skill_system._编译数值(movement_config.get("directionX", {}))) if skill_system else 0.0
				var directY = _快速求值(buff, skill_system._编译数值(movement_config.get("directionY", {}))) if skill_system else 0.0
				line_obj_direction = Vector2(directX, directY).normalized()
				if caster.has_method("get") and "facingDirection" in caster:
					line_obj_direction = line_obj_direction.rotated(Vector2.DOWN.angle()).rotated(caster.facingDirection.angle())
			
			var speed = _快速求值(buff, skill_system._编译数值(movement_config.get("speed", {}))) if skill_system else 0.0
			var obj_ref = weakref(obj)
			obj.obj_process = func(delta: float) -> void:
				var o = obj_ref.get_ref()
				if o:
					o.global_position += line_obj_direction * speed * delta
		
		"Bind":
			var bind_to_caster = movement_config.get("bindToCaster", true)
			var current_target = entity_manager.get_unit(buff.current_target_entity) if buff else null
			var bind_node = caster if bind_to_caster else (current_target if current_target else caster)
			var bind_ref = weakref(bind_node) if bind_node else null
			var obj_ref_bind = weakref(obj)
			obj.obj_process = func(delta: float) -> void:
				var b = bind_ref.get_ref() if bind_ref else null
				var o = obj_ref_bind.get_ref()
				if b and o:
					o.global_position = b.global_position
			if bind_node and is_instance_valid(bind_node):
				var obj_ref_conn = weakref(obj)
				bind_node.tree_exited.connect(func():
					var o = obj_ref_conn.get_ref()
					if o:
						o.queue_free()
				)
		
		_:
			push_error("[color=red]未知的子物体运动类型: %s[/color]" % movement_type)

func _add_to_foreground(obj: Node2D) -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		return
	var foreground = tree.get_first_node_in_group("foreground_layer")
	if foreground:
		foreground.add_child(obj)

func _快速求值(buff: BuffComponentData, compiled: Callable) -> float:
	if compiled == null:
		return 0.0
	var caster = entity_manager.get_unit(buff.caster_entity)
	var current_target = entity_manager.get_unit(buff.current_target_entity)
	var ctx = {
		"buff_instance": buff,
		"skill_manager": skill_system,
		"caster": caster,
		"current_target": current_target,
		"blackboard": buff.blackboard,
		"random": func() -> int: return randi() % 100 + 1,
	}
	return compiled.call(ctx)

## 清理某个 Entity 的所有子物体，返回清理的数量
func cleanup_entity_objects(entity_id: int) -> int:
	var cleaned: int = 0
	for i in range(_active_objects.size() - 1, -1, -1):
		if _active_objects[i].owner_entity == entity_id:
			var node = _active_objects[i].node
			if is_instance_valid(node):
				node.queue_free()
			_active_objects.remove_at(i)
			cleaned += 1
	return cleaned

## 清理所有子物体
func cleanup_all() -> void:
	for tracked in _active_objects:
		if is_instance_valid(tracked.node):
			tracked.node.queue_free()
	_active_objects.clear()
