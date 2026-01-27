extends Control

class_name 战斗跳字

@onready var 跳字label: Label = $跳字Label

var 跳字时间 = 0.8

func 设置跳字内容(内容: String, 颜色: Color) -> void:
	跳字label.text = 内容
	modulate = 颜色
	
	var tween = create_tween()
	
	var 向驻留位置移动的朝向 = Vector2(randf_range(-1,1), randf_range(-1,-0.3))
	# var 向驻留位置移动的朝向 = Vector2(1.0, 0.0)
	var 向驻留位置移动的距离 = randf_range(0.1, 0.5)
	## tween_method(func,a,b,t):声明一个func，该方法默认接受一个从a到b的动态值，值的变化时间是t
	tween.tween_method(_tween_跳字.bind(向驻留位置移动的朝向, 向驻留位置移动的距离),0.0,1.0,跳字时间).set_trans(Tween.TRANS_LINEAR)
	# tween.tween_callback(Callable(self,"queue_free")) # 动画结束后删除节点


## scale: 跳字先变大再变小，然后维持该大小驻留;
## position: 从开始到变小完成时间内快速向目标位置移动，然后慢速向上移动;
## modulate.a: 变小完成后，保持一定时间后渐隐消失;
func _tween_跳字(
	当前进度: float, 
	向驻留位置移动的朝向:Vector2,
	向驻留位置移动的距离: float,
	) -> void:

	# scale参数
	var 解放变大的进度 = 0.05
	var 达到最大时的进度 = 0.1 
	var 缩放开始驻留时的进度 = 0.2
	var 解放变大前的缩放比例 = 0.5
	var 最大缩放比例 = 2
	var 驻留缩放比例 = 1
	
	
	# position参数
	var 位置开始驻留时的进度 = 0.1
	向驻留位置移动的朝向 = 向驻留位置移动的朝向.normalized()
	# print(向驻留位置移动的朝向)
	var 向驻留位置移动的速度 = 向驻留位置移动的距离 / 位置开始驻留时的进度
	var 向上移动的速度 = 0.03

	# modulate.a参数
	var 驻留时长 = 0.75
	var 渐隐开始时间比例 = 位置开始驻留时的进度 + 驻留时长
	var 渐隐结束时间比例 = 1.0

	# 计算position
	if 当前进度 <= 位置开始驻留时的进度:
		var movement = 向驻留位置移动的朝向 * 向驻留位置移动的速度
		# print(向驻留位置移动的朝向)
		self.global_position += movement
	else:
		self.global_position.y -= 向上移动的速度 

	# 计算scale
	if 当前进度 <= 解放变大的进度:
		self.scale = 解放变大前的缩放比例 * Vector2.ONE
	elif 当前进度 <= 达到最大时的进度:
		self.scale = lerp(Vector2.ONE, Vector2.ONE * 最大缩放比例, 当前进度 / 达到最大时的进度)
	elif 当前进度 <= 缩放开始驻留时的进度:
		self.scale = lerp(Vector2.ONE * 最大缩放比例, Vector2.ONE * 驻留缩放比例, (当前进度 - 达到最大时的进度) / (缩放开始驻留时的进度 - 达到最大时的进度))
	else :
		self.scale = Vector2.ONE * 驻留缩放比例


	# 计算modulate.a
	if 当前进度 >= 渐隐开始时间比例:
		var 渐隐进度 = (当前进度 - 渐隐开始时间比例) / (渐隐结束时间比例 - 渐隐开始时间比例)
		self.modulate.a = lerp(1.0, 0.0, 渐隐进度)



# # 运行场景时，点击鼠标左键播放效果
# func _input(event):
# 	if event is InputEventMouseButton:
# 		if event.button_index == MOUSE_BUTTON_LEFT:
# 			if event.pressed:
# 				设置跳字内容("999999", Color.RED)
# 			else:
# 				pass
