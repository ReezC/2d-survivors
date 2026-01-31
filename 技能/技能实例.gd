extends Node
class_name 技能实例

signal 技能开始释放
signal 技能释放完成
signal 技能冷却结束

@export var 技能本体数据: 技能数据
var 冷却时间: float = 0.0
var cd_timer: Timer = Timer.new()

enum 技能状态 {
	准备就绪,
	冷却中,
}

var 当前状态: 技能状态 = 技能状态.准备就绪 : set  = 设置状态

	
	
func _ready() -> void:
	# 先解析技能数据
	if 技能本体数据.技能逻辑配置文件 != "":
		var file = FileAccess.open(技能本体数据.技能逻辑配置文件, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			var json = JSON.parse_string(json_text)
			技能本体数据.技能逻辑 = json
	name = str(技能本体数据.技能ID)


	
	var 冷却缩减 = get_node("../../../单位属性component").获取属性值("冷却缩减")
	# TODO：针对技能的冷却缩减
	var 专用冷却缩减 = 0.0
	冷却时间 = 技能本体数据.冷却时间 * (1.0 - 冷却缩减) * (1.0 - 专用冷却缩减)
	if 冷却时间 > 0.0:
		
		cd_timer.timeout.connect(_on_cd_timer_timeout)
		cd_timer.one_shot = true
		cd_timer.name = "CD_Timer"
		add_child(cd_timer)
	


func cast() -> void:
	# 暂定释放技能就进冷却
	emit_signal("技能开始释放")
	技能进入冷却()
	
	var skill_buff_data = 技能本体数据.技能逻辑.get("buff", null)
	var skill_buff = BuffInstance.new(skill_buff_data, self.owner)
	get_node("../../Buffs").add_child(skill_buff)


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
