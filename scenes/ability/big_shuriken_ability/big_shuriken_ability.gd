extends Node2D

var rotation_radius = 50
var rotation_end_radius = 100
var rotation_times = 1.0
var rotation_duration = 2 # 一圈所需时间
var line_speed = 1000 # 线速度

var original_rotation = 0.0
var rotation_direction = 1 # 1为顺时针，-1为逆时针


@onready var hitbox_component = $HitboxComponent

func _ready() -> void:
    original_rotation = randf_range(0, TAU)
    if randi() % 2 == 0:
        rotation_direction = 1
    else:
        rotation_direction = -1
    var tween = create_tween()
    tween.tween_method(tween_method,0.0,rotation_times,rotation_times * rotation_duration)
    tween.tween_callback(Callable(self,"queue_free"))

# 动画逻辑
func tween_method(rotations: float) -> void:
    var player = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        return
    
    # 计算当前半径
    rotation_radius = rotation_end_radius * (rotations / rotation_times)
    
    # 计算当前角度，角速度与半径成反比
    if rotation_radius > 0:
        # 累积角度 = 积分(线速度/半径 dt)
        # 由于半径随时间线性增长：r(t) = k*t
        # 所以 θ(t) = (v/k) * ln(t)
        # 但这里rotations已经是t的线性函数，所以：
        var k = rotation_end_radius / rotation_times
        var accumulated_angle = (line_speed / k) * log(1 + rotations)  # 加1避免log(0)
        
        var current_direction = Vector2.RIGHT.rotated(accumulated_angle * rotation_direction + original_rotation)
        global_position = player.global_position + current_direction * rotation_radius
        rotation = current_direction.rotated(PI / 2).angle()