extends Node


const 受击闪白material = preload("uid://c0gikbxr2hvpe")

signal experience_vial_collected(exp_amount: int)
signal ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary)


func emit_experience_vial_collected(exp_amount: int) -> void:
	experience_vial_collected.emit(exp_amount)

func emit_ability_upgrade_added(upgrade:AbilityUpgrade, current_upgrades:Dictionary) -> void:
	ability_upgrade_added.emit(upgrade, current_upgrades)
