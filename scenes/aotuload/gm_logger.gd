extends Node
## GM 日志管理器 — 全局控制各类 log 是否打印

# 日志分类枚举
enum LogCategory {
	战斗伤害,     # 伤害计算、命中检测
	敌人信息,     # 怪物信息、波次
	经验升级,     # 经验获取、升级选择
	角色状态,     # 玩家状态变化（待机/移动/施法/死亡）
	技能信息,     # 技能冷却、释放流程
	Buff信息,     # Buff 生命周期、SkillAction 执行
	子物体,       # 子物体生成、运动、销毁
	对象池,       # 对象池回收/扩展
	ECS,          # EntityManager 实体/组件调试
	属性变化,     # 属性变更、治疗
	输入移动,     # 玩家输入、移动方向
	通用,         # 其他杂项
}

# 默认所有分类关闭
var _category_enabled: Dictionary = {}
var _default_enabled: bool = false


func _ready() -> void:
	# 初始化所有分类为关闭
	for cat in LogCategory.values():
		_category_enabled[cat] = _default_enabled
	process_mode = Node.PROCESS_MODE_ALWAYS


## 检查某分类是否启用
func is_enabled(category: LogCategory) -> bool:
	return _category_enabled.get(category, _default_enabled)


## 设置某分类是否启用
func set_enabled(category: LogCategory, enabled: bool) -> void:
	_category_enabled[category] = enabled


## 设置所有分类
func set_all(enabled: bool) -> void:
	for cat in LogCategory.values():
		_category_enabled[cat] = enabled


## 获取所有分类状态
func get_all_status() -> Dictionary:
	return _category_enabled.duplicate()


## 核心日志方法 — 仅在对应分类启用时打印
func _log(category: LogCategory, message: String, rich_color: String = "") -> void:
	if not is_enabled(category):
		return
	
	var cat_name: String = LogCategory.keys()[category]
	if rich_color.is_empty():
		print("[%s] %s" % [cat_name, message])
	else:
		print_rich("[color=%s][%s][/color] %s" % [rich_color, cat_name, message])


## 带颜色的快捷日志
func log_damage(msg: String) -> void:
	_log(LogCategory.战斗伤害, msg, "RED")

func log_enemy(msg: String) -> void:
	_log(LogCategory.敌人信息, msg, "ORANGE")

func log_exp(msg: String) -> void:
	_log(LogCategory.经验升级, msg, "GREEN")

func log_player_state(msg: String) -> void:
	_log(LogCategory.角色状态, msg, "BLUE")

func log_skill(msg: String) -> void:
	_log(LogCategory.技能信息, msg, "CYAN")

func log_buff(msg: String) -> void:
	_log(LogCategory.Buff信息, msg, "DARK_CYAN")

func log_subobj(msg: String) -> void:
	_log(LogCategory.子物体, msg, "TEAL")

func log_pool(msg: String) -> void:
	_log(LogCategory.对象池, msg, "GRAY")

func log_ecs(msg: String) -> void:
	_log(LogCategory.ECS, msg, "VIOLET")

func log_attr(msg: String) -> void:
	_log(LogCategory.属性变化, msg, "YELLOW")

func log_input(msg: String) -> void:
	_log(LogCategory.输入移动, msg, "DIM_GRAY")

func log_info(msg: String) -> void:
	_log(LogCategory.通用, msg, "WHITE")
