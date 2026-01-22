extends CharacterBody2D
class_name BasicMonster

const MAX_SPEED = 25

@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	pass

# 受到伤害逻辑
func on_area_entered(area:Area2D) -> void:
	health_component.damage(1)
	 

# 敌人AI逻辑
func _process(delta: float) -> void:
	var direction = get_direction_to_player()
	velocity = direction * MAX_SPEED
	move_and_slide()


func get_direction_to_player():
	var player_nodes = get_tree().get_first_node_in_group("player") as Node2D
	if player_nodes != null:
		return (player_nodes.global_position - global_position).normalized()
	return Vector2.ZERO
