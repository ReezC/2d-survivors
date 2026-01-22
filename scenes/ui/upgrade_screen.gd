extends CanvasLayer

signal upgrade_selected(upgrade:AbilityUpgrade)

@export var upgrade_card_scene: PackedScene
@onready var card_container: HBoxContainer = %CardContainer


func _ready() -> void:
    get_tree().paused = true

# 添加多个能力升级选项
func set_ability_upgrade(upgrades:Array[AbilityUpgrade]) :
    for upgrade in upgrades:
        var card_instance = upgrade_card_scene.instantiate() as PanelContainer
        card_container.add_child(card_instance)
        card_instance.set_ability_upgrade(upgrade)
        card_instance.selected.connect(on_upgrade_selected.bind(upgrade))

func on_upgrade_selected(upgrade:AbilityUpgrade):
    emit_signal("upgrade_selected", upgrade)
    get_tree().paused = false
    queue_free()