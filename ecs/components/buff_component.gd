extends RefCounted
class_name BuffComponentData

## Buff 组件 — 纯数据结构（不继承 Node）
## 替代原来的 BuffInstance

enum buff叠加计时类型枚举 {
	不改变计时,
	叠加时刷新计时,
	每层独立计时,
	延长计时,
}

var buff_id: int = 0                      ## 唯一标识
var buff_name: String = ""
var buff_data: Dictionary = {}            ## JSON 配置原始数据
var caster_entity: int = -1              ## 施法者 Entity ID
var current_target_entity: int = -1      ## 当前目标 Entity ID
var duration: float = 0.0                 ## 秒
var elapsed: float = 0.0                 ## 已过时间（由 System 驱动）
var max_stack: int = 1
var current_stack: int = 1
var stack_type: buff叠加计时类型枚举 = buff叠加计时类型枚举.不改变计时
var blackboard: Dictionary = {}
var parent_buff_id: int = -1             ## 父 Buff ID

## 子 Buff ID 列表
var child_buff_ids: Array[int] = []

## 预编译表达式
var _compiled_duration: Callable
var _compiled_max_stack: Callable
var _compiled_conditions: Dictionary = {}  ## hash → Callable
var _compiled_values: Dictionary = {}      ## hash → Callable

## 生命周期标记
var is_active: bool = true

## 内部计时器（替代 Godot Timer 节点）
## ActionOverTime 的间隔计时
var _action_over_time_interval: float = 0.0
var _action_over_time_elapsed: float = 0.0
var _action_over_time_action: Dictionary = {}

## ActionTimeline 的计时
var _action_timeline_entries: Array[Dictionary] = []  ## [{time_sec, action, triggered}]
var _action_timeline_time_multiplier: float = 0.0

## PlayAnimation 状态标记
var _is_play_animation: bool = false
