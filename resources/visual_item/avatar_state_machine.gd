class_name AvatarStateMachine extends RefCounted
## 角色状态 → 动作映射表
## 对应 MSW 的 StateToAvatarBodyActionSheet / AvatarStateAnimationComponent
##
## 职责：
## 1. 将 AvatarState 映射为 {action_name, play_rate}
## 2. 根据武器类型选择对应的攻击动作
## 3. 为标准动作提供默认的动画名备用列表（stand1/stand2 等）

## 状态 → 动作名映射（大写状态 → 小写动作名）
var _state_to_action: Dictionary = {}

## 状态 → 播放速率
var _state_to_play_rate: Dictionary = {}

## 动作名 → 候选动画名列表
var _action_to_candidates: Dictionary = {
	"stand": ["stand1", "stand2"],
	"walk": ["walk1", "walk2"],
	"jump": ["jump"],
	"sit": ["sit"],
	"crouch": ["prone"],
	"rope": ["rope"],
	"ladder": ["ladder"],
	"dead": ["dead"],
	"hit": ["hit"],
	"fly": ["fly"],
	"heal": ["heal"],
	"alert": ["alert"],
}

## 武器类别枚举
enum WeaponType {
	NONE,			# 无武器
	ONE_HAND_SWORD,	# 单手剑/匕首 → swingO1-O3, stabO1-O2
	TWO_HAND_SWORD,	# 双手剑/锤 → swingT1-T3, stabT1-T2
	SPEAR,			# 长柄武器 → swingP1-P2
	BOW,			# 弓/弩 → shoot1-shoot2
	WAND,			# 法杖/魔杖 → swingO1-O3
}

## 武器类别 → 攻击动作名（整数键避免 const 限制）
var _weapon_attack_actions: Dictionary = {}
var _current_state: AvatarState.State = AvatarState.State.IDLE
var _weapon_type: WeaponType = WeaponType.NONE


func _init() -> void:
	# 初始化状态映射（enum 键必须在非 const 字典中）
	_state_to_action = {
		AvatarState.State.IDLE: "stand",
		AvatarState.State.MOVE: "walk",
		AvatarState.State.ATTACK: "attack",
		AvatarState.State.HIT: "hit",
		AvatarState.State.CROUCH: "crouch",
		AvatarState.State.FALL: "fall",
		AvatarState.State.JUMP: "fall",
		AvatarState.State.CLIMB: "rope",
		AvatarState.State.LADDER: "ladder",
		AvatarState.State.DEAD: "dead",
		AvatarState.State.SIT: "sit",
	}
	_state_to_play_rate = {
		AvatarState.State.IDLE: 1.0,
		AvatarState.State.MOVE: 1.68,
		AvatarState.State.ATTACK: 1.33,
		AvatarState.State.HIT: 1.0,
		AvatarState.State.CROUCH: 1.0,
		AvatarState.State.FALL: 1.0,
		AvatarState.State.JUMP: 1.0,
		AvatarState.State.CLIMB: 1.0,
		AvatarState.State.LADDER: 1.0,
		AvatarState.State.DEAD: 1.0,
		AvatarState.State.SIT: 1.0,
	}
	_weapon_attack_actions = {
		WeaponType.NONE:            ["alert"],
		WeaponType.ONE_HAND_SWORD:  ["swingO1", "swingO2", "swingO3", "stabO1", "stabO2"],
		WeaponType.TWO_HAND_SWORD:  ["swingT1", "swingT2", "swingT3", "stabT1", "stabT2"],
		WeaponType.SPEAR:           ["swingP1", "swingP2"],
		WeaponType.BOW:             ["shoot1", "shoot2"],
		WeaponType.WAND:            ["swingO1", "swingO2", "swingO3"],
	}


## 设置当前武器类型
func set_weapon_type(wt: WeaponType) -> void:
	_weapon_type = wt

## 获取当前状态对应的动作名
func get_action_name() -> String:
	return _state_to_action.get(_current_state, "stand")

## 获取当前状态对应的播放速率
func get_play_rate() -> float:
	return _state_to_play_rate.get(_current_state, 1.0)

## 获取当前状态对应的候选动画名列表
## 返回空数组表示不需要动画（如某些状态无需驱动动画）
func get_candidates() -> Array[String]:
	var action := get_action_name()
	if action == "attack":
		# 根据武器类型返回候选攻击动作
		var weapon_actions: Array = _weapon_attack_actions.get(_weapon_type, ["alert"])
		var candidates: Array[String] = []
		for wa in weapon_actions:
			candidates.append(wa)
		return candidates
	var arr: Array = _action_to_candidates.get(action, [])
	if arr.is_empty():
		arr = [action] as Array[String]
	return arr as Array[String]

## 切换状态
func change_state(st: AvatarState.State) -> void:
	if st == _current_state:
		return
	# DEAD 状态锁：进入 DEAD 后只能切回 IDLE
	if _current_state == AvatarState.State.DEAD:
		if st != AvatarState.State.IDLE:
			return
	_current_state = st

## 获取当前状态枚举
func get_current_state() -> AvatarState.State:
	return _current_state
