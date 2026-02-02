extends Node
class_name SkillManager

@onready var skills: Node = $Skills
@onready var buffs: Node = $Buffs
@export_dir var 子物体场景路径

var 当前锁定目标: Node2D = null

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
	
	# 生效被动技能
	for skill in skills.get_children():
		var skill_instance = skill as 技能实例
		if skill_instance.技能类型 == 技能数据.技能类型枚举.被动技能:
			skill_instance.cast()
#region AI逻辑

## 自动获取最近的目标
## 尝试向当前目标释放技能
## 当没有目标时，不会尝试释放技能
func 初始化_Player技能AI() -> void:
	var player_scan_timer = Timer.new()
	player_scan_timer.wait_time = 0.2
	player_scan_timer.name = "PlayerSkillAITimer"
	player_scan_timer.timeout.connect(Player技能AI_获取目标)
	add_child(player_scan_timer)
	player_scan_timer.start()

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


func test() -> void:
	var test_timer = Timer.new()
	test_timer.wait_time = 2.0
	test_timer.name = "SkillAITimer"
	test_timer.timeout.connect(_on_test_timer_timeout)
	add_child(test_timer)
	test_timer.start()

func _on_test_timer_timeout() -> void:
	释放技能(1)

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

#endregion


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



#region 目标选择
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
	# 	GameEvents.创建跳字.emit(center_position + point, "扫！", Color.PURPLE)
	if sector_polygon.size() < 3:
		push_error("扇形多边形顶点数不足")
		return []
	
	# 创建多边形形状
	var polygon_shape = ConvexPolygonShape2D.new()
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
	var num_points = int(TAU/half_angle_rad ) * 15  # 扇形边界上的点数

	points.append(center_position)  # 扇形中心点
	
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
