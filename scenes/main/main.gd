extends Node

@export var end_screen_scene: PackedScene


func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player") as Unit
	player.死亡.connect(on_player_died)
	pass
	



func on_player_died() -> void:
	await get_tree().create_timer(3.0).timeout
	var end_screen_instance = end_screen_scene.instantiate()
	add_child(end_screen_instance)
	(end_screen_instance as CanvasLayer).set_defeat()


func on_arena_difficulty_changed(changed_value: int) -> void:
	pass
