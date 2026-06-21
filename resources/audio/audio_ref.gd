class_name AudioRef
extends Resource

## 显示名称
@export var 显示名称: String = ""

## 音频流资源（直接拖入 .mp3/.ogg 文件）
@export var 音频流: AudioStream

## 输出总线（需与 Godot Audio Bus Layout 中的总线名称一致）
##   Master   - 主总线：总控输出，所有子总线的最终混合
##   Music    - 背景音乐：持续播放的背景音乐，受音乐音量、静音控制
##   SFX      - 通用音效：位置音效（受击、脚步等），支持衰减和随机音调
##   UISFX    - UI 音效：界面交互（点击、悬停），非位置音效，不受距离影响
##   Ambient  - 环境音：场景氛围（风声、雨声），通常循环播放
@export_enum("Master", "Music", "SFX", "UISFX", "Ambient") var 总线: String = "SFX"

## 音量（线性 0.0 ~ 1.0）
@export_range(0.0, 1.0, 0.01) var 音量: float = 1.0
