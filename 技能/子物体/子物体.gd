extends Node2D

class_name 子物体
@onready var hitbox_component: HitboxComponent = $HitboxComponent


## 子物体执行过程函数
## 重写此函数以实现自定义行为
var obj_process:Callable = func(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	# 子物体的运动由 SubObjectSystem.update() 统一驱动
	# 这里不再调用 obj_process，避免 call_deferred 导致 lambda 捕获已释放对象
	pass
