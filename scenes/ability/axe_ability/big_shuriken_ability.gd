extends Node2D

var rotation_radius = 15
var rotation_times = 1.0
var rotation_duration = 1.2 # 一圈所需时间

@onready var hitbox_component = $HitboxComponent

func _ready() -> void:
	var tween = create_tween()
	tween.tween_method(tween_method,0.0,rotation_times,rotation_times * rotation_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self,"queue_free")) # tween动画结束后执行

# 动画逻辑
func tween_method(rotations: float) -> void:
	var current_direction = Vector2.UP.rotated(rotations * TAU)

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		pass
	else :
		global_position = player.global_position + current_direction * rotation_radius
	# rotation = current_direction.rotated(PI / 2).angle() # animation_player 里处理旋转把
