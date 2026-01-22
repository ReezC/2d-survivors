extends Camera2D


func _ready() -> void:
	make_current()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var player_nodes = get_tree().get_nodes_in_group("player") # 返回的是列表
	if player_nodes.size() > 0:
		var player = player_nodes[0] as Node2D
		global_position = player.global_position
		
