extends Node

@export var axe_ability_scene: PackedScene

var damage = 10

func _ready() -> void:
    $Timer.timeout.connect(on_timer_timeout)


# 本体逻辑
func on_timer_timeout():
    var player = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        return
    var axe_instance = axe_ability_scene.instantiate() as Node2D
    var foreground_layer = get_tree().get_first_node_in_group("foreground_layer") as Node2D
    if foreground_layer == null:
        return
    foreground_layer.add_child(axe_instance)
    axe_instance.global_position = player.global_position
    axe_instance.hitbox_component.damage_amount = damage

    