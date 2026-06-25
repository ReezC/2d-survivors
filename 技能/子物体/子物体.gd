extends Node2D

class_name 子物体

@onready var hitbox_component: HitboxComponent = get_node_or_null("HitboxComponent")

## SubObjectSystem._configure_movement() 动态赋值的运动回调
## SubObjectSystem.update() 中逐帧调用此回调驱动运动
var obj_process: Callable

#region 音效
@export_group("音效")
@export var 生成音效: SfxRef               ## 创建时播放
@export var 生成音效延迟: float = 0.0       ## 延迟（毫秒）
# @export var 命中音效: SfxRef               ## 命中目标时播放
# @export var 命中音效延迟: float = 0.0       ## 延迟（毫秒）
# @export var 销毁音效: SfxRef               ## 销毁时播放
# @export var 销毁音效延迟: float = 0.0       ## 延迟（毫秒）


func _ready() -> void:
	_播放延迟音效(生成音效, 生成音效延迟)


func _播放延迟音效(sfx: SfxRef, delay_ms: float) -> void:
	if sfx == null:
		return
	if delay_ms <= 0.0:
		AudioManager.play_sfx_ref(sfx, global_position)
		return

	var _ref: WeakRef = weakref(self)
	get_tree().create_timer(delay_ms / 1000.0).timeout.connect(func() -> void:
		var _self := _ref.get_ref() as Node2D
		if _self:
			AudioManager.play_sfx_ref(sfx, _self.global_position)
	, CONNECT_ONE_SHOT)
#endregion


# func _physics_process(_delta: float) -> void:
# 	pass
