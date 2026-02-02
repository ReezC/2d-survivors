extends Node2D

class_name 子物体
@onready var hitbox_component: HitboxComponent = $HitboxComponent


## 子物体执行过程函数
## 重写此函数以实现自定义行为
var obj_process:Callable = func(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	obj_process.call_deferred(delta)
