extends Node

@export_range(0,1) var drop_percent: float = .5
@export var health_component: Node
@export var item_scene: PackedScene

func _ready() -> void:
	#(health_component as HealthComponent).died.connect(on_owner_died)
	pass

func on_owner_died() -> void:
	if randf() > drop_percent:
		return
	if item_scene == null:
		return
	if owner is not Node2D:
		return
	var spawn_position: Vector2 = (owner as Node2D).global_position
	var drop_scene_instance = item_scene.instantiate() as Node2D
	var entities_layer = get_tree().get_first_node_in_group("entities_layer") as Node2D
	entities_layer.add_child(drop_scene_instance)
	drop_scene_instance.global_position = spawn_position
