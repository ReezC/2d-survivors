class_name SfxRef
extends AudioRef

## 随机音调下限
@export_range(0.1, 4.0, 0.01) var 最低音调: float = 1.0

## 随机音调上限
@export_range(0.1, 4.0, 0.01) var 最高音调: float = 1.0

## 最大传播距离（0 表示非位置音效，使用 1D 播放器）
@export var 最大传播距离: float = 0.0

## 衰减系数（仅位置音效生效）
## 控制声音随距离衰减的曲线强度，作用于 AudioStreamPlayer2D.attenuation
## 公式：volume_multiplier = distance ^ (-衰减系数)
##   0.0 = 无衰减（最大传播距离内满音量，边界外切断）
##   1.0 = 反比衰减（距离翻倍 → 音量减半）
##   2.0 = 平方反比衰减（距离翻倍 → 音量变为 1/4）
##   越大越陡峭
@export_range(0.0, 10.0, 0.1) var 衰减系数: float = 1.0

## 是否循环播放
@export var 循环播放: bool = false
