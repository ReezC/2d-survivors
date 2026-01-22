extends CanvasLayer

@export var arena_time_manager: Node
@onready var time_label = %TimeLabel


func _process(delta: float):
	if arena_time_manager == null:
		return
	var time_elapsed = arena_time_manager.get_time_elapsed()

	var minutes = int(time_elapsed) / 60
	var seconds = int(time_elapsed) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]
