class_name MusicRef
extends AudioRef

## 淡入时间（秒）
@export_range(0.0, 5.0, 0.1) var 淡入时间: float = 1.0

## 淡出时间（秒）
@export_range(0.0, 5.0, 0.1) var 淡出时间: float = 1.0

## 是否循环播放
@export var 循环播放: bool = true
