extends Node2D
class_name fx

# @export var duration: float = 1.0
@export var speed_scale: float = 1.0
# @onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	animation_player.speed_scale = speed_scale
	# animated_sprite_2d.speed_scale = speed_scale
	# animated_sprite_2d.play()
	# var tween = create_tween()
	# tween.tween_callback(Callable(self, "queue_free")).set_delay(duration)
