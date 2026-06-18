extends Node
class_name SkillManager

@onready var skills: Node = $Skills
@onready var buffs: Node = $Buffs
@export_dir var 子物体场景路径

var 当前锁定目标: Node2D = null
var scan_timer: Timer = null

## 预编译表达式缓存
## key: 表达式 JSON 文本的 hash → { "float": Callable, "cond": Callable }
## 同一个 JSON 配置只需编译一次
static var _compiled_float_cache: Dictionary = {}
static var _compiled_cond_cache: Dictionary = {}
static var _compiler := ExprCompiler.new()

enum AI类型枚举 {
	无,
	Player技能AI,
	Enemy技能AI,
}

@export var skill_ai: AI类型枚举


func _process(delta: float) -> void:
	match skill_ai:
		AI类型枚举.Player技能AI:
			if 当前锁定目标 != null:
				按优先级尝试释放技能(当前锁定目标)
		AI类型枚举.Enemy技能AI:
			pass
		


func 初始化() -> void:
	match skill_ai:
		AI类型枚举.Player技能AI:
			初始化_Player技能AI()
		AI类型枚举.Enemy技能AI:
			pass
	
	# 初始化技能
	预编译所有技能()
	for skill in skills.get_children():
		var skill_instance = skill as 技能实例
		skill_instance.初始化()
		if skill_instance.技能类型 == 技能数据.技能类型枚举.被动技能:
			skill_instance.cast()
#region AI逻辑

## 自动获取最近的目标
## 尝试向当前目标释放技能
## 当没有目标时，不会尝试释放技能
func 初始化_Player技能AI() -> void:
	scan_timer = Timer.new()
	scan_timer.wait_time = 0.2
	scan_timer.name = "PlayerSkillAITimer"
	scan_timer.timeout.connect(Player技能AI_获取目标)
	add_child(scan_timer)
	scan_timer.start()

## 获取目标的条件：所有可用技能中，最大的触发范围内有目标
func Player技能AI_获取目标() -> void:
	# 先获取最大的可用技能的触发范围
	skills = get_node("Skills")
	var 活跃技能的最大触发范围: float = 0.0
	for skill in skills.get_children():
		if skill.技能类型 != 技能数据.技能类型枚举.主动技能:
			continue
		var skill_instance = skill as 技能实例
		if skill_instance.当前状态 == 技能实例.技能状态.准备就绪:
			活跃技能的最大触发范围 = max(活跃技能的最大触发范围, skill_instance.获取技能触发范围())
			if 活跃技能的最大触发范围 <= 0.0:
				push_error("[color=red]有技能可用但触发范围都<=0，请检查技能配置[/color]")
				return
			var 可用的目标 = get_target_in_circle_area(
				owner.global_position,
				Vector2.RIGHT.rotated(owner.rotation),
				活跃技能的最大触发范围,
				360.0,
				GameEvents.collision_layer_enum.敌人hurtbox
			)
			当前锁定目标 = 从多目标中获取最近的目标(可用的目标)


# func test() -> void:
# 	var test_timer = Timer.new()
# 	test_timer.wait_time = 2.0
# 	test_timer.name = "SkillAITimer"
# 	test_timer.timeout.connect(_on_test_timer_timeout)
# 	add_child(test_timer)
# 	test_timer.start()

# func _on_test_timer_timeout() -> void:
# 	释放技能(1)

## 按优先级尝试释放可用的技能
func 按优先级尝试释放技能(target: Node2D) -> void:
	var 技能列表 = skills.get_children()
	# TODO:技能列表.sort_custom(self, "_技能优先级排序函数")
	for skill in 技能列表:
		var skill_instance = skill as 技能实例
		if skill_instance.当前状态 == 技能实例.技能状态.准备就绪:
			var 技能触发范围 = skill_instance.获取技能触发范围()
			var 距离 = owner.global_position.distance_to(target.global_position)
			if 距离 <= 技能触发范围:
				释放技能(skill_instance.id)
				break

# 拥有者死亡时，销毁buff实例
func _on_单位_死亡() -> void:
	for buff in buffs.get_children():
		buff.queue_free()
	if scan_timer != null:
		#scan_timer.stop()
		scan_timer.queue_free()
	print_rich("[color=red]%s 的技能管理器检测到拥有者死亡，已销毁所有buff实例[/color]" % owner.name)
#endregion



#region 技能释放与动画
func 释放技能(技能ID: int) -> void:
	var 技能 = skills.get_node(str(技能ID)) as 技能实例
	# TODO：检测技能释放条件
	技能.cast()


## TODO：释放不同技能的动画
static func 播放技能动画(who:Node2D, 动画名称: String,技能动画持续时间: float) -> void:
	if who.当前状态 == who.角色状态.死亡:
		return
	who.当前状态 = who.角色状态.释放技能
	var anim_timer = Timer.new()
	anim_timer.wait_time = 技能动画持续时间 / 1000.0
	anim_timer.one_shot = true
	anim_timer.name = "SkillAnimTimer"
	anim_timer.timeout.connect(func():
		who.当前状态 = who.角色状态.待机
	)
	who.add_child(anim_timer)
	anim_timer.start()
#endregion


#region 目标扫描
func get_target_in_circle_area(
	center_position: Vector2,
	direction: Vector2,
	radius: float, 
	angle_deg: float,
	target_collision_layer: int
) -> Array:
	var space_state = get_tree().root.world_2d.direct_space_state
	var targets_in_area = []
	var target_set = {}  # 使用集合避免重复

	# 创建扇形多边形
	var sector_polygon = create_sector_polygon(
		Vector2.ZERO,  # 改为相对于原点
		direction,
		radius,
		angle_deg
	)
	# for point in sector_polygon:
		# GameEvents.创建跳字.emit(center_position + point, "扫！", Color.PURPLE)
	if sector_polygon.size() < 3:
		push_error("扇形多边形顶点数不足")
		return []
	
	# 创建多边形形状
	var polygon_shape = ConvexPolygonShape2D.new()
	# polygon_shape.points = Geometry2D.convex_hull(sector_polygon)
	polygon_shape.points = sector_polygon
	
	# 设置查询参数
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = polygon_shape
	# 通过变换矩阵设置位置
	query.transform = Transform2D(0, center_position)
	query.collision_mask = target_collision_layer
	query.collide_with_areas = true
	query.collide_with_bodies = true  # 可能也需要检测刚体
	
	# 执行查询
	var results = space_state.intersect_shape(query, 100)
	for result in results:
		var obj = result.collider
		var rid = obj.get_rid() if obj else RID()
		if not target_set.has(rid) and obj.monitorable == true:
			target_set[rid] = true
			targets_in_area.append(obj)
	
	## 清理资源
	#polygon_shape.free()
	#query.free()
	#
	return targets_in_area


func create_sector_polygon(
	center_position: Vector2,
	direction: Vector2,
	radius: float,
	angle_deg: float
	) -> PackedVector2Array:
	var points = PackedVector2Array()
	var half_angle_rad = deg_to_rad(min(angle_deg, 360)) / 2.0
	var start_angle = direction.angle() - half_angle_rad
	var end_angle = direction.angle() + half_angle_rad
	var num_points = int(ceil(angle_deg / 15.0))  # 每15度一个点

	# points.append(center_position)  # 扇形中心点
	
	# GameEvents.创建跳字.emit(center_position, str(center_position), Color.PURPLE)

	for i in range(num_points + 1):
		var t = float(i) / float(num_points)
		var angle = lerp(start_angle, end_angle, t)
		var point = center_position + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
		# GameEvents.创建跳字.emit(point, "扫！", Color.PURPLE)
	return points

func 从多目标中获取最近的目标(targets:Array)->Node2D:
	var 最近目标:Node2D = null
	var 最近距离:float = INF
	for target in targets:
		var target_node = target as Node2D
		var distance = owner.global_position.distance_to(target_node.global_position)
		if distance < 最近距离:
			最近距离 = distance
			最近目标 = target_node
	return 最近目标
#endregion

#region 预编译表达式（新）
## 预编译 FloatValue → Callable（带缓存）
func 编译数值(值配置: Dictionary) -> Callable:
	if 值配置 == null or 值配置.is_empty():
		return func(_ctx: Dictionary) -> float: return 0.0
	var key = 值配置.hash()
	if _compiled_float_cache.has(key):
		return _compiled_float_cache[key]
	var compiled = _compiler.compile_float_value(值配置)
	_compiled_float_cache[key] = compiled
	return compiled

## 预编译 Condition → Callable（带缓存）
func 编译条件(条件配置: Dictionary) -> Callable:
	if 条件配置 == null or 条件配置.is_empty():
		return func(_ctx: Dictionary) -> bool: return true
	var key = 条件配置.hash()
	if _compiled_cond_cache.has(key):
		return _compiled_cond_cache[key]
	var compiled = _compiler.compile_condition(条件配置)
	_compiled_cond_cache[key] = compiled
	return compiled

## 使用预编译的 FloatValue 求值
func 求值数值(compiled: Callable, source_buff: BuffInstance = null) -> float:
	var ctx = _构建上下文(source_buff)
	return compiled.call(ctx)

## 使用预编译的 Condition 求值
func 求值条件(compiled: Callable, source_buff: BuffInstance = null) -> bool:
	var ctx = _构建上下文(source_buff)
	return compiled.call(ctx)

func _构建上下文(source_buff: BuffInstance = null) -> Dictionary:
	var ctx := {
		"buff_instance": source_buff,
		"skill_manager": self,
		"caster": source_buff.施法者 if source_buff else null,
		"current_target": source_buff.当前目标 if source_buff else null,
		"blackboard": source_buff.BlackBoard if source_buff else {},
		"random": func() -> int: return randi() % 100 + 1,
	}
	return ctx

## 初始化时预编译所有技能中的表达式
func 预编译所有技能() -> void:
	for skill in skills.get_children():
		var si = skill as 技能实例
		if si == null:
			continue
		# 预编译技能逻辑中的所有表达式
		si.预编译表达式()
#endregion

#region 数值与条件解析器（旧版，保留兼容；内部会尝试走预编译缓存）
func _解析数值(值配置:Dictionary, source_buff:BuffInstance=null) -> float:
	# 尝试走预编译路径
	var compiled = 编译数值(值配置)
	var ctx = _构建上下文(source_buff)
	return compiled.call(ctx)

func _解析条件(条件配置:Dictionary, source_buff:BuffInstance = null)->bool:
	# 尝试走预编译路径
	var compiled = 编译条件(条件配置)
	var ctx = _构建上下文(source_buff)
	return compiled.call(ctx)
#endregion
