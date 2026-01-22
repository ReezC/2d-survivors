extends Node

@export var upgrade_pool:Array[AbilityUpgrade]
@export var experience_manager: Node
@export var upgrade_screen_scene: PackedScene

var current_upgrades = {}
var upgrade_choices = 2

func _ready():
	experience_manager.level_up.connect(on_level_up)


# 应用升级
func apply_upgrade(upgrade: AbilityUpgrade) -> void:
	var has_upgrade = current_upgrades.has(upgrade.id)
	if !has_upgrade:
		current_upgrades[upgrade.id] = {
			"resource": upgrade,
			"quantity": 1
		}
	else:
		current_upgrades[upgrade.id]["quantity"] += 1
	
	if upgrade.max_quantity > 0:
		var current_quantity = current_upgrades[upgrade.id]["quantity"]
		if current_quantity == upgrade.max_quantity:
			upgrade_pool.erase(upgrade)
	
	GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades)

func on_upgrade_selected(upgrade: AbilityUpgrade) -> void:
	apply_upgrade(upgrade)


func on_level_up(new_level: int) -> void:

	var upgrade_screen_instance = upgrade_screen_scene.instantiate() as CanvasLayer
	add_child(upgrade_screen_instance)
	var chosen_upgrades = pick_upgrades()
	upgrade_screen_instance.set_ability_upgrade(chosen_upgrades) 
	upgrade_screen_instance.upgrade_selected.connect(on_upgrade_selected)

# 随机逻辑
func pick_upgrades():
	var filtered_upgrades = upgrade_pool.duplicate()
	var chosen_upgrades: Array[AbilityUpgrade] = []
	for i in range(upgrade_choices):
		if filtered_upgrades.size() == 0:
			break
		var chosen_upgrade = filtered_upgrades.pick_random() as AbilityUpgrade
		chosen_upgrades.append(chosen_upgrade)
		filtered_upgrades.erase(chosen_upgrade)
	return chosen_upgrades
