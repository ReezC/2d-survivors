extends Node2D

class_name 子物体
@onready var hitbox_component: HitboxComponent = $HitboxComponent

## SubObjectSystem._configure_movement() 动态赋值的运动回调
## SubObjectSystem.update() 中逐帧调用此回调驱动运动
var obj_process: Callable

func _physics_process(_delta: float) -> void:
	pass
