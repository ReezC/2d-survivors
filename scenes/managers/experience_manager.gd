extends Node

signal experience_updated(current_exp: int, target_exp: int)
signal level_up(new_level: int)

const TARGET_EXPS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

var current_exp = 0
var current_level = 1

var target_exp = TARGET_EXPS[0]

func _ready():
	GameEvents.experience_vial_collected.connect(on_experience_vial_collected)

func increment_exp(num_exp: int) -> void:
	current_exp = min(current_exp + num_exp, target_exp)
	emit_signal("experience_updated", current_exp, target_exp)
	if current_exp >= target_exp:
		current_level += 1
		current_exp = current_exp - target_exp
		emit_signal("experience_updated", current_exp, target_exp)
		emit_signal("level_up", current_level)
		if current_level - 1 < TARGET_EXPS.size():
			target_exp = TARGET_EXPS[current_level - 1]
		else:
			target_exp = target_exp + int(target_exp * 0.5)


	print("经验+ %d. 当前经验: %d" % [num_exp, current_exp])

func on_experience_vial_collected(exp_amount: int) -> void:
	increment_exp(exp_amount)