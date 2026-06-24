extends RefCounted
class_name ExprCompiler

## 表达式预编译器
## 将 FloatValue / Condition 的 JSON 表达式树预编译为 Callable，
## 运行时只需传入 context Dictionary 即可直接求值，避免每次递归遍历 JSON。

# context 中可用的 key：
#   "buff_instance"   : BuffComponentData — 当前 Buff 组件数据（ECS）
#   "skill_manager"   : SkillSystem       — 技能系统引用（ECS）
#   "caster"          : Node              — 施法者
#   "current_target"  : Node2D            — 当前目标
#   "blackboard"      : Dictionary        — 技能黑板
#   "random"          : Callable          — func() -> int (0-99), 用于 Chance 条件


## 编译 FloatValue 表达式树 → Callable
## 返回 Callable 签名: func(context: Dictionary) -> float
func compile_float_value(config: Dictionary) -> Callable:
	if config == null or config.is_empty():
		return func(_ctx: Dictionary) -> float: return 0.0

	var type_name = _get_type_name(config)
	match type_name:
		"Const":
			var val = float(config.get("value", 0.0))
			return func(_ctx: Dictionary) -> float: return val

		"expression":
			var expr = Expression.new()
			var err = expr.parse(config.get("expr", "0.0"))
			if err != OK:
				push_error("[ExprCompiler] FloatValue expression 解析失败: %s" % expr.get_error_text())
				return func(_ctx: Dictionary) -> float: return 0.0
			return func(ctx: Dictionary) -> float:
				var result = expr.execute([], ctx.get("buff_instance", null))
				if not expr.has_execute_failed():
					return float(result)
				return 0.0

		"Add":
			var compiled_values: Array[Callable] = []
			for v in config.get("values", []):
				compiled_values.append(compile_float_value(v))
			return func(ctx: Dictionary) -> float:
				var total: float = 0.0
				for c in compiled_values:
					total += c.call(ctx)
				return total

		"Minus":
			var c1 = compile_float_value(config.get("value1", {}))
			var c2 = compile_float_value(config.get("value2", {}))
			return func(ctx: Dictionary) -> float: return c1.call(ctx) - c2.call(ctx)

		"Multiply":
			var compiled_values: Array[Callable] = []
			for v in config.get("values", []):
				compiled_values.append(compile_float_value(v))
			return func(ctx: Dictionary) -> float:
				var product: float = 1.0
				for c in compiled_values:
					product *= c.call(ctx)
				return product

		"Divide":
			var c1 = compile_float_value(config.get("value1", {}))
			var c2 = compile_float_value(config.get("value2", {}))
			return func(ctx: Dictionary) -> float:
				var divisor = c2.call(ctx)
				if divisor != 0.0:
					return c1.call(ctx) / divisor
				push_warning("[ExprCompiler] 除数为零，返回 1.0")
				return 1.0

		"Int":
			var c = compile_float_value(config.get("value", {}))
			return func(ctx: Dictionary) -> float: return float(int(c.call(ctx)))

		"ByBlackBoard":
			var key = config.get("key", "")
			return func(ctx: Dictionary) -> float:
				var bb: Dictionary = ctx.get("blackboard", {})
				return float(bb.get(key, 0.0))

		"ByNumberArray":
			# 暂不支持预编译，回退到运行时解析
			push_warning("[ExprCompiler] ByNumberArray 暂不支持预编译，将回退到运行时解析")
			return func(_ctx: Dictionary) -> float:
				push_error("[ExprCompiler] ByNumberArray 未实现")
				return 0.0

		"ValueIfElse":
			var cond = compile_condition(config.get("condition", {}))
			var c_true = compile_float_value(config.get("valueTrue", {}))
			var c_false = compile_float_value(config.get("valueFalse", {}))
			return func(ctx: Dictionary) -> float:
				return c_true.call(ctx) if cond.call(ctx) else c_false.call(ctx)

		"ValueSwitch":
			var cases: Array[Dictionary] = []
			for case_item in config.get("cases", []):
				cases.append({
					"condition": compile_condition(case_item.get("condition", {})),
					"value": compile_float_value(case_item.get("value", {}))
				})
			var def_value = compile_float_value(config.get("def", {}))
			return func(ctx: Dictionary) -> float:
				for cs in cases:
					if cs["condition"].call(ctx):
						return cs["value"].call(ctx)
				return def_value.call(ctx)

		"ByActor":
			var actor_type = config.get("actorType", "Caster")
			var actor_value_compiled = _compile_actor_float_value(config.get("value", {}))
			return func(ctx: Dictionary) -> float:
				var actor_node: Node = null
				match actor_type:
					"Caster":
						actor_node = ctx.get("caster")
					"CurentTarget":
						actor_node = ctx.get("current_target")
					_:
						push_error("[ExprCompiler] 未知的 ByActor actorType: %s" % actor_type)
						return 0.0
				if actor_node == null:
					return 0.0
				return actor_value_compiled.call(actor_node)

		_:
			push_error("[ExprCompiler] 未知的 FloatValue 类型: %s" % type_name)
			return func(_ctx: Dictionary) -> float: return 0.0


## 编译 Condition 表达式树 → Callable
## 返回 Callable 签名: func(context: Dictionary) -> bool
func compile_condition(config: Dictionary) -> Callable:
	if config == null or config.is_empty():
		return func(_ctx: Dictionary) -> bool: return true

	var type_name = _get_type_name(config)
	match type_name:
		"Bool":
			var val = bool(config.get("value", false))
			return func(_ctx: Dictionary) -> bool: return val

		"expression":
			var expr = Expression.new()
			var err = expr.parse(config.get("expr", "false"))
			if err != OK:
				push_error("[ExprCompiler] Condition expression 解析失败: %s" % expr.get_error_text())
				return func(_ctx: Dictionary) -> bool: return false
			return func(ctx: Dictionary) -> bool:
				var result = expr.execute([], ctx.get("buff_instance", null))
				if not expr.has_execute_failed():
					return bool(result)
				return false

		"Chance":
			var chance = float(config.get("chance", 0.0))
			var add_chances: Array[Callable] = []
			for ac in config.get("addChances", []):
				add_chances.append(compile_float_value(ac))
			return func(ctx: Dictionary) -> bool:
				var total_chance = chance
				for c in add_chances:
					total_chance += c.call(ctx)
				var rand_val = (ctx.get("random") as Callable).call() if ctx.has("random") else randi() % 100 + 1
				return rand_val < total_chance

		"Gte":
			var c1 = compile_float_value(config.get("value1", {}))
			var c2 = compile_float_value(config.get("value2", {}))
			return func(ctx: Dictionary) -> bool: return c1.call(ctx) >= c2.call(ctx)

		"Lte":
			var c1 = compile_float_value(config.get("value1", {}))
			var c2 = compile_float_value(config.get("value2", {}))
			return func(ctx: Dictionary) -> bool: return c1.call(ctx) <= c2.call(ctx)

		"Equal":
			var c1 = compile_float_value(config.get("value1", {}))
			var c2 = compile_float_value(config.get("value2", {}))
			return func(ctx: Dictionary) -> bool: return is_equal_approx(c1.call(ctx), c2.call(ctx))

		"And":
			var compiled_conds: Array[Callable] = []
			for cond in config.get("conditions", []):
				compiled_conds.append(compile_condition(cond))
			return func(ctx: Dictionary) -> bool:
				for c in compiled_conds:
					if not c.call(ctx):
						return false
				return true

		"Or":
			var compiled_conds: Array[Callable] = []
			for cond in config.get("conditions", []):
				compiled_conds.append(compile_condition(cond))
			return func(ctx: Dictionary) -> bool:
				for c in compiled_conds:
					if c.call(ctx):
						return true
				return false

		"Not":
			var inner = compile_condition(config.get("condition", {}))
			return func(ctx: Dictionary) -> bool: return not inner.call(ctx)

		"ByActor":
			var actor_type = config.get("actorType", "Caster")
			var actor_cond_compiled = _compile_actor_condition(config.get("condition", {}))
			return func(ctx: Dictionary) -> bool:
				var actor_node: Node = null
				match actor_type:
					"Caster":
						actor_node = ctx.get("caster")
					"CurentTarget":
						actor_node = ctx.get("current_target")
					_:
						push_error("[ExprCompiler] 未知的 ByActor actorType: %s" % actor_type)
						return false
				if actor_node == null:
					return false
				return actor_cond_compiled.call(actor_node)

		_:
			push_error("[ExprCompiler] 未知的 Condition 类型: %s" % type_name)
			return func(_ctx: Dictionary) -> bool: return false


## 编译 ActorFloatValue → Callable(actor_node: Node) -> float
func _compile_actor_float_value(config: Dictionary) -> Callable:
	if config == null or config.is_empty():
		return func(_actor: Node) -> float: return 0.0

	var type_name = _get_type_name(config)
	match type_name:
		"expression":
			var expr = Expression.new()
			var err = expr.parse(config.get("expr", "0.0"))
			if err != OK:
				push_error("[ExprCompiler] ActorFloatValue expression 解析失败: %s" % expr.get_error_text())
				return func(_actor: Node) -> float: return 0.0
			return func(actor: Node) -> float:
				var result = expr.execute([], actor)
				if not expr.has_execute_failed():
					return float(result)
				return 0.0

		"Attribute":
			var attr_id = config.get("attr")
			return func(actor: Node) -> float:
				if actor == null or not actor.has_method("get") or not "attribute_component" in actor:
					return 0.0
				var attr_comp = actor.attribute_component
				var attr_name = attr_comp.获取属性名称_by_id(attr_id)
				return attr_comp.获取属性值(attr_name)

		_:
			push_error("[ExprCompiler] 未知的 ActorFloatValue 类型: %s" % type_name)
			return func(_actor: Node) -> float: return 0.0


## 编译 ActorCondition → Callable(actor_node: Node) -> bool
func _compile_actor_condition(config: Dictionary) -> Callable:
	if config == null or config.is_empty():
		return func(_actor: Node) -> bool: return true

	var type_name = _get_type_name(config)
	match type_name:
		"CurrentState":
			var state_name = config.get("stateName", "")
			return func(actor: Node) -> bool:
				if actor == null or not actor.has_method("get") or not "当前状态" in actor:
					return false

				return actor.当前状态 == actor.角色状态[state_name]

		"expression":
			var expr = Expression.new()
			var err = expr.parse(config.get("expr", "false"))
			if err != OK:
				push_error("[ExprCompiler] ActorCondition expression 解析失败: %s" % expr.get_error_text())
				return func(_actor: Node) -> bool: return false
			return func(actor: Node) -> bool:
				var result = expr.execute([], actor)
				if not expr.has_execute_failed():
					return bool(result)
				return false

		"And":
			var compiled_conds: Array[Callable] = []
			for cond in config.get("conditions", []):
				compiled_conds.append(_compile_actor_condition(cond))
			return func(actor: Node) -> bool:
				for c in compiled_conds:
					if not c.call(actor):
						return false
				return true

		"Or":
			var compiled_conds: Array[Callable] = []
			for cond in config.get("conditions", []):
				compiled_conds.append(_compile_actor_condition(cond))
			return func(actor: Node) -> bool:
				for c in compiled_conds:
					if c.call(actor):
						return true
				return false

		"Not":
			var inner = _compile_actor_condition(config.get("condition", {}))
			return func(actor: Node) -> bool: return not inner.call(actor)

		_:
			push_error("[ExprCompiler] 未知的 ActorCondition 类型: %s" % type_name)
			return func(_actor: Node) -> bool: return false


func _get_type_name(config: Dictionary) -> String:
	var full_type: String = config.get("$type", "")
	var parts = full_type.split(".")
	return parts[-1] if parts.size() > 0 else ""
