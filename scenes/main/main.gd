extends Node

@export var end_screen_scene: PackedScene

# ============================================
# BGM 配置 — 由策划在 Inspector 中拖入 MusicRef .tres 文件
# ============================================

@export_group("BGM 配置")
## 普通战斗 BGM
@export var 战斗Bgm: MusicRef
## Boss 战 BGM
@export var BossBgm: MusicRef
## 胜利 BGM
@export var 胜利Bgm: MusicRef
## 失败 BGM
@export var 失败Bgm: MusicRef

## ============================================================================
## GM 日志开关 — 编辑器勾选即可启用对应分类的日志打印
## 
## 使用方式：在编辑器中选中 Main 节点，Inspector 面板的 "GM 日志开关" 分组下勾选需要的分类即可。
## 所有日志通过 GMLogger Autoload 统一输出，输出格式为 "[分类名] 日志内容"。
## ============================================================================

@export_group("GM 日志开关", "gm_")

## 战斗伤害 — 伤害计算、命中检测、伤害数字等
## 来源：伤害系统、Hitbox 碰撞处理
@export var gm_战斗伤害:   bool = false

## 敌人生成 — 怪物生成、波次控制、敌人数统计
## 来源：敌人生成器、波次管理器
@export var gm_敌人生成:   bool = false

## 经验升级 — 经验获取、升级选择、属性成长
## 来源：经验系统、升级界面
@export var gm_经验升级:   bool = false

## 技能系统 — 技能释放成功/失败、冷却开始/就绪、被动技能生效、拥有者死亡
## 来源：SkillSystem（skill_system.gd）、SkillManager（skill_manager.gd）、AbilityController
## 包含玩家和怪物双方的技能 AI 行为
@export var gm_技能系统:   bool = false

## Buff与子物体 — 底层 Buff 创建/执行/销毁、子物体生成（hitbox/弹幕）、技能时间线
## 来源：BuffSystem（buff_system.gd）、SubObjectSystem（subobject_system.gd）
## 与"技能系统"互补：技能系统关注技能层面，Buff与子物体关注具体执行细节
@export var gm_Buff与子物体: bool = false

## 对象池 — 对象池回收/扩展/重用
## 来源：对象池管理器
@export var gm_对象池:     bool = false

## ECS — EntityManager 实体/组件的创建、销毁、查询
## 来源：EntityManager（entity_manager.gd）
@export var gm_ECS:        bool = false

## 属性变化 — 属性变更（HP/攻击力/移速等）、治疗、死亡触发
## 来源：属性组件、属性修改器
@export var gm_属性变化:   bool = false

## 输入移动 — 玩家输入方向、移动向量、输入设备切换
## 来源：输入管理器、玩家移动控制器
@export var gm_输入移动:   bool = false

## 通用 — 其他未归类的杂项日志
## 来源：各处零散日志
@export var gm_通用:       bool = false


func _ready() -> void:
	# 同步 GM 日志开关到 GMLogger
	_sync_gm_logger()
	
	var player = get_tree().get_first_node_in_group("player") as Unit
	player.死亡.connect(on_player_died)

	# 开始播放战斗 BGM
	if 战斗Bgm:
		AudioManager.play_music_ref(战斗Bgm)


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
	# 切换到失败 BGM
	if 失败Bgm:
		AudioManager.play_music_ref(失败Bgm)

	await get_tree().create_timer(3.0).timeout
	var end_screen_instance = end_screen_scene.instantiate()
	add_child(end_screen_instance)
	(end_screen_instance as CanvasLayer).set_defeat()


func on_arena_difficulty_changed(changed_value: int) -> void:
	# 难度阶段变化时切换 BGM（例如进入 Boss 阶段）
	if BossBgm and changed_value > 1:  # 难度 > 1 视为 Boss 阶段
		AudioManager.play_music_ref(BossBgm)
