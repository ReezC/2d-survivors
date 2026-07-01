class_name AvatarState
## MSW 标准角色状态枚举 — 对应 StateToAvatarBodyActionSheet 的状态键

enum State {
	IDLE,		# 待机 → stand
	MOVE,		# 移动 → walk
	ATTACK,		# 攻击 → attack / swingO1 / swingT1 / shoot1
	HIT,		# 受击 → hit
	CROUCH,		# 蹲下 → crouch
	FALL,		# 下落 → fall
	JUMP,		# 跳跃 → fall（共用下落动作）
	CLIMB,		# 爬绳 → rope
	LADDER,		# 爬梯 → ladder
	DEAD,		# 死亡 → dead
	SIT,		# 坐下 → sit
}

## 状态名称转换表（非 const：Godot 不支持 enum 作为 const 字典键）
var state_names: Dictionary = {
	State.IDLE: "IDLE",
	State.MOVE: "MOVE",
	State.ATTACK: "ATTACK",
	State.HIT: "HIT",
	State.CROUCH: "CROUCH",
	State.FALL: "FALL",
	State.JUMP: "JUMP",
	State.CLIMB: "CLIMB",
	State.LADDER: "LADDER",
	State.DEAD: "DEAD",
	State.SIT: "SIT",
}

func get_name(st: State) -> String:
	return state_names.get(st, "IDLE")
