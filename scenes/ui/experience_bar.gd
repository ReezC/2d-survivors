extends CanvasLayer

@export var experience_manager: Node
@onready var progress_bar: ProgressBar = $MarginContainer/ProgressBar

func _ready() -> void:
	progress_bar.value = 0
	experience_manager.connect("experience_updated", on_experience_updated)

func on_experience_updated(current_exp: int, target_exp: int) -> void:
	progress_bar.value = current_exp
	progress_bar.max_value = target_exp
