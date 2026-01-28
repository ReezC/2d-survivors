extends Node
class_name 跳字对象池

# 跳字场景
@export var 跳字场景: PackedScene = preload("res://scenes/ui/floating_text/战斗跳字.tscn")

# 对象池设置
@export var 初始池大小: int = 20
@export var 最大池大小: int = 100
@export var 自动扩展: bool = true
@export var 跳字存活时间: float = 1.5
@export var 父节点路径: NodePath

# 私有变量
var 可用对象数组: Array = []
var 使用中对象字典: Dictionary = {}
var 父节点: Node
var 跳字计数器: int = 0

func _ready() -> void:
	# 初始化父节点
	if 父节点路径:
		父节点 = get_node(父节点路径)
	else:
		父节点 = get_tree().current_scene
	
	# 预创建对象池
	初始化对象池()
	GameEvents.创建跳字.connect(显示跳字)




	

func 初始化对象池() -> void:
	for i in 初始池大小:
		var 新跳字 = 创建跳字实例()
		可用对象数组.append(新跳字)

func 创建跳字实例() -> Node:
	var 实例 = 跳字场景.instantiate()
	实例.visible = false
	父节点.add_child(实例)
	return 实例

func 获取跳字() -> Node:
	if 可用对象数组.size() > 0:
		var 跳字 = 可用对象数组.pop_back()
		跳字.visible = true
		return 跳字
	
	if 自动扩展 and 使用中对象字典.size() < 最大池大小:
		var 新跳字 = 创建跳字实例()
		新跳字.visible = true
		print("对象池扩展，创建新跳字")
		return 新跳字
	
	return 复用旧跳字()

func 复用旧跳字() -> Node:
	if 使用中对象字典.size() == 0:
		return 创建跳字实例()
	
	# 查找最早创建的跳字
	var 最早键值 = 使用中对象字典.keys()[0]
	var 最早时间 = 使用中对象字典[最早键值]
	
	for 键值 in 使用中对象字典:
		if 使用中对象字典[键值] < 最早时间:
			最早键值 = 键值
			最早时间 = 使用中对象字典[键值]
	
	var 旧跳字 = 最早键值
	回收跳字(旧跳字)
	旧跳字.visible = true
	print("复用旧跳字")
	return 旧跳字

func 显示跳字(位置: Vector2, 内容: String, 颜色: Color = Color.WHITE,Z层级: int = 0) -> Node:
	var 跳字 = 获取跳字()
	
	if not 跳字:
		return null
	
	# 记录跳字ID
	var 跳字ID = 跳字计数器
	跳字计数器 += 1
	
	# 设置跳字属性
	跳字.global_position = 位置
	跳字.设置跳字内容(内容, 颜色)
	跳字.name = "战斗跳字_%d" % 跳字ID
	跳字.z_index = Z层级
	
	父节点.move_child(跳字, 父节点.get_child_count() - 1)

	# 添加到使用中字典
	使用中对象字典[跳字] = Time.get_ticks_msec()
	
	# 使用 SceneTreeTimer 设置回收
	var 计时器: SceneTreeTimer = get_tree().create_timer(跳字存活时间)
	计时器.timeout.connect(
		func():
			if is_instance_valid(跳字) and 跳字 in 使用中对象字典:
				回收跳字(跳字)
	, CONNECT_ONE_SHOT)
	
	return 跳字

func 回收跳字(跳字: Node) -> void:
	if 跳字 in 使用中对象字典:
		使用中对象字典.erase(跳字)
	
	跳字.visible = false
	跳字.position = Vector2.ZERO
	
	if not 跳字 in 可用对象数组:
		可用对象数组.append(跳字)
	
	清理多余对象()

func 清理多余对象() -> void:
	var 当前总数 = 可用对象数组.size() + 使用中对象字典.size()
	if 当前总数 > 最大池大小:
		var 需要清理数量 = 当前总数 - 最大池大小
		for i in range(min(需要清理数量, 可用对象数组.size())):
			var 待清理对象 = 可用对象数组[0]
			可用对象数组.remove_at(0)
			待清理对象.queue_free()


func 显示治疗数字(目标位置: Vector2, 治疗值: int) -> Node:
	return 显示跳字(目标位置, "+%d" % 治疗值, Color.GREEN)

func 获取对象池状态() -> Dictionary:
	return {
		"可用数量": 可用对象数组.size(),
		"使用中数量": 使用中对象字典.size(),
		"总数量": 可用对象数组.size() + 使用中对象字典.size(),
		"最大容量": 最大池大小
	}


# 测试函数
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 点击时显示随机伤害数字
			var 随机伤害 = randi_range(10, 100)
			var 是否暴击 = randf() < 0.2
			显示跳字(event.position, "%d" % 随机伤害, Color.RED)
			
			# 显示状态
			
