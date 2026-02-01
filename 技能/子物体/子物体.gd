extends Node2D

class_name 子物体
@onready var hitbox_component: HitboxComponent = $HitboxComponent

var obj_process:Callable = func(delta: float) -> void:
	pass
# func _process(delta: float) -> void:
#     obj_process(delta)

func _physics_process(delta: float) -> void:
	obj_process.call(delta)
