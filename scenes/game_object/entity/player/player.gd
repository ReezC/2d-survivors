extends Unit
class_name Player


var inputDirection:Vector2 = Vector2.ZERO
var 平滑移速:Vector2 = Vector2.ZERO
var _last_horizontal_sign: int = -1  # 默认朝左（与精灵默认方向一致）

@onready var character_body: CharacterBody = $body
@onready var paper_doll: PaperDollAnimator = get_node_or_null("PaperDollAnimator") as PaperDollAnimator

# ---- Face 独立状态机 ----
## 脸部动画与角色身体动画完全解耦，后续可扩展 HAPPY / SAD 等表情状态。
enum FaceState { IDLE }
var _face_state: int = FaceState.IDLE

# IDLE 状态下的眨眼子行为
var _face_is_blinking: bool = false
var _face_blink_remaining: int = 0         # 本次剩余 blink 次数（1 或 2）
var _face_blink_gap_ms: float = 0.0        # 两次 blink 之间的间隔计时器
var _face_blink_interval_ms: float = 3000.0
var _face_blink_timer_ms: float = 0.0
var _face_blink_frame: int = 0
var _face_blink_frame_timer_ms: float = 0.0
const FACE_BLINK_FRAME_DELAY_MS := 60.0
const FACE_BLINK_SEQUENCE_GAP_MS := 150.0  # 连眨两次时，第一次和第二次的间隔
const FACE_BLINK_INTERVAL_MIN_MS := 2000.0
const FACE_BLINK_INTERVAL_MAX_MS := 6000.0
const FACE_BLINK_DOUBLE_CHANCE := 0.3       # 30% 几率连眨两次
var _has_setup_buff_anim: bool = false      # 当前施法周期是否已设置 buff 动画


func _ready() -> void:
	super._ready()
	# 连接 PaperDoll 的 buff 动画结束信号（仅在 Sequence 类型自然播完时触发）
	if paper_doll:
		paper_doll.buff_animation_finished.connect(_on_buff_animation_finished)

func _process(delta: float) -> void:
	player_move(delta)
	set_anim()
	_update_face_state(delta)
	move_and_slide()


func player_move(delta: float) -> void:
	inputDirection = Input.get_vector("move_left","move_right","move_up","move_down")
	if 当前状态 == 角色状态.死亡:
		velocity = velocity.lerp(Vector2.ZERO, acccelerate * delta)
	elif 当前状态 == 角色状态.施法:
		# 施法中不改变状态，速度受系数控制（从待机进入=0，从移动进入=0.5）
		var effective_coef := 施法移动速度系数
		if _last_horizontal_sign != 0 and _last_horizontal_sign * inputDirection.x < 0:
			effective_coef = 0.0  # 移动输入与朝向相反，禁止移动
		var target_velocity = inputDirection * attribute_component.获取属性值("移动速度") * effective_coef
		velocity = velocity.lerp(target_velocity, acccelerate * delta)
	else:
		# 待机/移动：根据输入切换状态
		if inputDirection != Vector2.ZERO:
			当前状态 = 角色状态.移动
		else:
			当前状态 = 角色状态.待机
		velocity = velocity.lerp(inputDirection * attribute_component.获取属性值("移动速度"), acccelerate * delta)
	
	# 检测水平方向变化，驱动纸娃娃翻转（施法状态下默认禁用朝向修改）
	if 当前状态 != 角色状态.施法 or 施法允许改朝向:
		var h_sign := _get_horizontal_sign()
		if h_sign != 0 and h_sign != _last_horizontal_sign:
			_last_horizontal_sign = h_sign
			if paper_doll:
				paper_doll.set_face_direction(h_sign)
			if character_body:
				character_body.set_face_direction(h_sign)


## PaperDoll 的 Sequence 类型 buff 动画自然播完时回调
func _on_buff_animation_finished() -> void:
	if 当前状态 == 角色状态.施法:
		当前状态 = 角色状态.待机
		GMLogger.log_player_state("[%s] 施法动画结束 → 待机" % 单位名称)


func set_anim() -> void:
	# ---- 纸娃娃动画驱动 ----
	if paper_doll:
		match 当前状态:
			角色状态.待机:
				if _has_setup_buff_anim:
					paper_doll.stop_buff_animation()
					_has_setup_buff_anim = false
				paper_doll.set_animation_by_state(0)
			角色状态.移动:
				if _has_setup_buff_anim:
					paper_doll.stop_buff_animation()
					_has_setup_buff_anim = false
				paper_doll.set_animation_by_state(1)
			角色状态.施法:
				if not _has_setup_buff_anim and not 施法动画参数.is_empty():
					paper_doll.play_buff_animation(施法动画参数)
					_has_setup_buff_anim = true
	
	# ---- AnimationTree 动画驱动（仅非纸娃娃模式时使用） ----
	if state_machine == null:
		return
	# var tree_active: bool = animation_tree and animation_tree.active
	# if not tree_active:
		# return
	# match 当前状态:
	# 	角色状态.死亡:
	# 		state_machine.travel("ghoststand")
	# 	# 角色状态.施法:
	# 	# 	state_machine.travel("skill")
	# 	角色状态.待机:
	# 		state_machine.travel("stand1")
	# 	角色状态.移动:
	# 		state_machine.travel("walk1")
	# 		animation_tree.set("parameters/move/blend_position", facingDirection)
		


func get_x_facing_direction() -> float:
	var x_input = inputDirection.x
	if x_input == 0:
		return facingDirection.x
	return x_input

func _get_horizontal_sign() -> int:
	"""获取当前水平方向符号：1=右, -1=左, 0=无输入"""
	if inputDirection.x > 0.1:
		return 1
	elif inputDirection.x < -0.1:
		return -1
	return 0

func get_facing_direction() -> Vector2:
	if inputDirection == Vector2.ZERO:
		return facingDirection
		
	if inputDirection.y > .1 and abs(inputDirection.y) >= abs(inputDirection.x):
		facingDirection = Vector2.DOWN
	elif inputDirection.y < -.1 and abs(inputDirection.y) >= abs(inputDirection.x):
		facingDirection = Vector2.UP
	else:
		if inputDirection.x >.1:
			facingDirection = Vector2.RIGHT
		elif inputDirection.x<-.1:
			facingDirection = Vector2.LEFT
	
	return facingDirection


# ============================================================
# Face 独立状态机
# ============================================================

func _update_face_state(delta: float) -> void:
	"""每帧驱动 face 状态机（仅纸娃娃模式下有效）"""
	if paper_doll == null:
		return
	if not paper_doll.get_face_node():
		return

	match _face_state:
		FaceState.IDLE:
			_face_idle_update(delta)


func _face_idle_update(delta: float) -> void:
	"""IDLE 状态：跟随身体动画帧 + 随机眨眼"""
	if not _face_is_blinking:
		# 同步 face 到身体动画
		paper_doll.apply_face_to_current_frame()

		# 眨眼倒计时
		if paper_doll.face_has_animation("blink"):
			_face_blink_timer_ms += delta * 1000.0
			if _face_blink_timer_ms >= _face_blink_interval_ms:
				_face_blink_timer_ms = 0.0
				_face_blink_remaining = 2 if randf() < FACE_BLINK_DOUBLE_CHANCE else 1
				_face_is_blinking = true
				_face_blink_frame = 0
				_face_blink_frame_timer_ms = 0.0
				paper_doll.set_face_frame("blink", 0)
		return

	# 正在播放 blink 动画
	if _face_blink_gap_ms > 0.0:
		# 两次 blink 之间的间隔期，face 跟随身体动画
		paper_doll.apply_face_to_current_frame()
		_face_blink_gap_ms -= delta * 1000.0
		if _face_blink_gap_ms <= 0.0:
			_face_blink_gap_ms = 0.0
			_face_blink_frame = 0
			_face_blink_frame_timer_ms = 0.0
			paper_doll.set_face_frame("blink", 0)
		return

	_face_blink_frame_timer_ms += delta * 1000.0
	if _face_blink_frame_timer_ms >= FACE_BLINK_FRAME_DELAY_MS:
		_face_blink_frame_timer_ms = 0.0
		_face_blink_frame += 1

		var blink_max := paper_doll.face_get_frame_count("blink")
		if _face_blink_frame >= blink_max:
			_face_blink_remaining -= 1
			if _face_blink_remaining > 0:
				# 先回到 default 动画，间隔后再眨下一次
				paper_doll.apply_face_to_current_frame()
				_face_blink_gap_ms = FACE_BLINK_SEQUENCE_GAP_MS
			else:
				_face_is_blinking = false
				_face_blink_interval_ms = randf_range(FACE_BLINK_INTERVAL_MIN_MS, FACE_BLINK_INTERVAL_MAX_MS)
		else:
			paper_doll.set_face_frame("blink", _face_blink_frame)
