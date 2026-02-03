extends Node
class_name 技能实例

signal 技能开始释放
signal 技能释放完成
signal 技能冷却结束

@export var 技能本体数据: 技能数据

## 当前冷却记录在CD_Timer中

var cd_timer: Timer = Timer.new()
var id: int = 0
var 技能名称: String = "未命名"

var 技能类型: 技能数据.技能类型枚举
## 来源优先级：技能数据配置文件 > 手动配置的技能逻辑 > .tres手动填写的值
var 冷却时间: float = 0.0:get = 获取冷却时间
## 来源优先级：技能数据配置文件 > 手动配置的技能逻辑 > .tres手动填写的值
var 技能触发范围: float = 0.0:get = 获取技能触发范围
## 来源优先级：技能数据配置文件 > 手动配置的技能逻辑
var 动画名称: String = ""
var 施法者: Node2D = null


@onready var skill_manager: SkillManager = get_parent().get_parent() as SkillManager

enum 技能状态 {
	准备就绪,
	冷却中,
}

var 当前状态: 技能状态 = 技能状态.准备就绪 : set  = 设置状态

	
	
func 初始化() -> void:
	施法者 = owner as Node2D

	技能本体数据.解析技能配置()
	技能类型 = 技能本体数据.技能类型
	# 初始化技能冷却
	var 冷却时间配置 = 技能本体数据.获取技能CD()
	if typeof(冷却时间配置) == TYPE_DICTIONARY:
		冷却时间 = max(0,skill_manager._解析数值(冷却时间配置))
	else:
		冷却时间 = float(冷却时间配置) 

	# 触发范围
	var 触发范围配置 = 技能本体数据.获取技能触发范围()
	if typeof(触发范围配置) == TYPE_DICTIONARY:
		技能触发范围 = max(0,skill_manager._解析数值(触发范围配置))
	else:
		技能触发范围 = float(触发范围配置)		
	
	# 动画名称
	动画名称 = 技能本体数据.技能逻辑.get("buffOccupyAnim","")


	id = 技能本体数据.技能ID
	name = str(技能本体数据.技能ID)
	技能名称 = 技能本体数据.技能名称

	
	
	var 冷却缩减 = get_node("../../../单位属性component").获取属性值("冷却缩减")
	# TODO：针对技能的冷却缩减
	var 专用冷却缩减 = 0.0
	冷却时间 = 技能本体数据.冷却时间 * (1.0 - 冷却缩减) * (1.0 - 专用冷却缩减)
	if 冷却时间 > 0.0:
		
		cd_timer.timeout.connect(_on_cd_timer_timeout)
		cd_timer.one_shot = true
		cd_timer.name = "CD_Timer"
		add_child(cd_timer)
	

func 获取技能触发范围() -> float:
	if 技能本体数据.技能逻辑.has("skillTriggerRange"):
		技能触发范围 = skill_manager._解析数值(技能本体数据.技能逻辑.get("skillTriggerRange"))
	if 技能触发范围 <= 0.0:
		push_error("[color=red]技能 %s 的触发范围配置错误，必须大于0，已强制设置为1.0[/color]" % 技能名称)
		技能触发范围 = 0.0
	return 技能触发范围

func 获取冷却时间() -> float:
	return 冷却时间



func cast() -> void:
	# 暂定释放技能就进冷却
	emit_signal("技能开始释放")
	var skill_buff_data = 技能本体数据.技能逻辑.get("buff", null)
	var skill_buff = BuffInstance.new(skill_buff_data, 施法者)
	get_node("../../Buffs").add_child(skill_buff)

	match 技能类型:
		技能数据.技能类型枚举.主动技能:
			技能进入冷却()
			# 播放技能动画
			if 动画名称 != null:
				var 技能动画持续时间 = skill_manager._解析数值(技能本体数据.技能逻辑.get("buff").get("duration"))
				SkillManager.播放技能动画(施法者, 动画名称,技能动画持续时间)
		技能数据.技能类型枚举.被动技能:
			emit_signal("技能释放完成")
			return
	
	


func 设置状态(new_status: 技能状态) :
	当前状态 = new_status
	match 当前状态:
		技能状态.准备就绪:
			emit_signal("技能冷却结束")
		技能状态.冷却中:
			emit_signal("技能释放完成")

func 技能进入冷却() -> void:
	if 冷却时间 <= 0.0:
		设置状态(技能状态.准备就绪)
		return
	设置状态(技能状态.冷却中)
	cd_timer.wait_time = 冷却时间
	cd_timer.start()

func _on_cd_timer_timeout() -> void:
	设置状态(技能状态.准备就绪)
