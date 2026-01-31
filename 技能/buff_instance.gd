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
	buff_excute()
	# on_buff_end()

func buff_excute() -> void:
	var buff_logic_data = buff_data.get("buffLogic")
	match buff_logic_data.get("$type").split(".")[-1]:
		_:
			print_rich("[color=red]未知的buff逻辑类型: %s[/color]" % buff_logic_data.get("$type"))
	
	
func on_buff_start() -> void:
	# buff开始时的逻辑
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
	print_rich("[color=green]Buff %s 开始，持续时间：%.2f 秒[/color]" % [name, buff_timer.wait_time])


func on_buff_end() -> void:
	# buff结束时的逻辑
	print_rich("[color=green]Buff %s 结束[/color]" % name)
	queue_free()


func _on_buff_timer_timeout() -> void:
	on_buff_end()

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
