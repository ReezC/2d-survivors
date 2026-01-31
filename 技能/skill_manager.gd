extends Node
class_name SkillManager

@onready var skills: Node = $Skills
@onready var buffs: Node = $Buffs

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
