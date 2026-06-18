extends Node

@export var end_screen_scene: PackedScene

# ---- GM 日志开关（编辑器勾选即可启用对应分类的日志打印）----
@export_group("GM 日志开关", "gm_")
@export var gm_战斗伤害:   bool = false
@export var gm_敌人生成:   bool = false
@export var gm_经验升级:   bool = false
@export var gm_技能系统:   bool = false
@export var gm_Buff与子物体: bool = false
@export var gm_对象池:     bool = false
@export var gm_ECS:        bool = false
@export var gm_属性变化:   bool = false
@export var gm_输入移动:   bool = false
@export var gm_通用:       bool = false


func _ready() -> void:
	# 同步 GM 日志开关到 GMLogger
	_sync_gm_logger()
	
	var player = get_tree().get_first_node_in_group("player") as Unit
	player.死亡.connect(on_player_died)


func _sync_gm_logger() -> void:
	GMLogger.set_enabled(GMLogger.LogCategory.战斗伤害,   gm_战斗伤害)
	GMLogger.set_enabled(GMLogger.LogCategory.敌人生成,   gm_敌人生成)
	GMLogger.set_enabled(GMLogger.LogCategory.经验升级,   gm_经验升级)
	GMLogger.set_enabled(GMLogger.LogCategory.技能系统,   gm_技能系统)
	GMLogger.set_enabled(GMLogger.LogCategory.Buff与子物体, gm_Buff与子物体)
	GMLogger.set_enabled(GMLogger.LogCategory.对象池,     gm_对象池)
	GMLogger.set_enabled(GMLogger.LogCategory.ECS,        gm_ECS)
	GMLogger.set_enabled(GMLogger.LogCategory.属性变化,   gm_属性变化)
	GMLogger.set_enabled(GMLogger.LogCategory.输入移动,   gm_输入移动)
	GMLogger.set_enabled(GMLogger.LogCategory.通用,       gm_通用)


func on_player_died() -> void:
	await get_tree().create_timer(3.0).timeout
	var end_screen_instance = end_screen_scene.instantiate()
	add_child(end_screen_instance)
	(end_screen_instance as CanvasLayer).set_defeat()


func on_arena_difficulty_changed(changed_value: int) -> void:
	pass
