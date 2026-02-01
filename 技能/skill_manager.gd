extends Node
class_name SkillManager

@onready var skills: Node = $Skills
@onready var buffs: Node = $Buffs
@export_dir var 子物体场景路径

func _ready() -> void:
	if owner.is_in_group("player"):
		test()
	

func 释放技能(技能ID: int) -> void:
	var 技能 = skills.get_node(str(技能ID)) as 技能实例
	# TODO：检测技能释放条件
	技能.cast()
	
func test() -> void:
	var test_timer = Timer.new()
	test_timer.wait_time = 2.0
	test_timer.timeout.connect(_on_test_timer_timeout)
	add_child(test_timer)
	test_timer.start()

func _on_test_timer_timeout() -> void:
	释放技能(1)

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
		if not target_set.has(rid):
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
	
	# GameEvents.创建跳字.emit(center_position, "0", Color.RED)

	for i in range(num_points + 1):
		var t = float(i) / float(num_points)
		var angle = lerp(start_angle, end_angle, t)
		var point = center_position + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
		# GameEvents.创建跳字.emit(point, str(i), Color.RED)
	return points
