extends Node

signal arena_difficulty_changed(now_difficulty: int)

const DIFFICULTI_STAGE_COUNT = 5 # 一局游戏的难度阶段数

@export var end_screen_scene: PackedScene

@onready var timer = $Timer

var arena_difficulty = 0

func _ready() -> void:
	timer.timeout.connect(on_timer_timeout)

func _process(delta: float) -> void:
	# 上次难度阶段
	var last_difficulty = arena_difficulty
	# 获取当前难度阶段
	arena_difficulty = int((1.0 - timer.time_left / timer.wait_time) * DIFFICULTI_STAGE_COUNT)
	# 难度阶段变化时发出信号
	if last_difficulty != arena_difficulty:
		emit_signal("arena_difficulty_changed", arena_difficulty)

func get_time_elapsed() -> float:
	return timer.wait_time - timer.time_left


# 胜利条件：时间到
func on_timer_timeout() -> void:
	var end_screen_instance = end_screen_scene.instantiate() as CanvasLayer
	add_child(end_screen_instance)