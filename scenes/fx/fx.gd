extends Node2D
class_name fx

@export var speed_scale: float = 1.0
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.speed_scale = speed_scale
