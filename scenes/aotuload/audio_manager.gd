extends Node
# AudioManager - 音频系统管理器（Autoload）
# 负责管理音效播放池、背景音乐切换、音频总线音量控制

# ============================================
# 音频总线枚举（需与 Godot Audio Bus Layout 中的总线名称一致）
# ============================================

## 音频总线枚举
enum AudioBus {
	MASTER,   # 主总线：总控输出，所有子总线的最终混合
	MUSIC,    # 背景音乐：游戏中持续播放的背景音乐，支持自动淡入淡出
	SFX,      # 通用音效：位置音效（受击、脚步、爆炸等），支持衰减和随机音调
	UISFX,    # UI 音效：界面交互音效（点击、悬停、弹窗等），非位置音效，不受场景距离影响
	AMBIENT,  # 环境音：场景氛围音（风声、雨声、虫鸣等），通常循环播放
}

# ============================================
# 常量
# ============================================
const SFX_2D_POOL_SIZE := 16
const SFX_1D_POOL_SIZE := 8

# ============================================
# 音频总线索引缓存
# ============================================
var _bus_indices: Dictionary = {}

# ============================================
# SFX 播放池
# ============================================
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []
var _sfx_1d_pool: Array[AudioStreamPlayer] = []
var _sfx_2d_next: int = 0
var _sfx_1d_next: int = 0

# ============================================
# 音乐播放器（双通道交叉淡入淡出）
# ============================================
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music_channel: AudioStreamPlayer = null
var _idle_music_channel: AudioStreamPlayer = null
var _current_music_ref: MusicRef = null
var _music_fade_tween: Tween

# ============================================
# 音量默认值
# ============================================
var _default_volumes: Dictionary = {
	"Master": 1.0,
	"Music": 1.0,
	"SFX": 1.0,
	"UISFX": 1.0,
	"Ambient": 0.7,
}

# ============================================
# 初始化
# ============================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_create_music_players()
	_create_sfx_pools()
	GMLogger.log_info("AudioManager: 初始化完成")


func _setup_audio_buses() -> void:
	# 缓存音频总线索引
	var bus_names := ["Master", "Music", "SFX", "UISFX", "Ambient"]
	for bus_name in bus_names:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			_bus_indices[bus_name] = idx
			# 恢复默认音量
			if _default_volumes.has(bus_name):
				set_bus_volume_linear(bus_name, _default_volumes[bus_name])


func _create_music_players() -> void:
	# 音乐播放器（双通道）
	_music_a = AudioStreamPlayer.new()
	_music_a.name = "MusicChannelA"
	_music_a.bus = "Music"
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.name = "MusicChannelB"
	_music_b.bus = "Music"
	add_child(_music_b)

	_current_music_channel = _music_a
	_idle_music_channel = _music_b


func _create_sfx_pools() -> void:
	# 2D 位置音效池
	var container_2d := Node.new()
	container_2d.name = "SFX2DPool"
	add_child(container_2d)

	for i in SFX_2D_POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.name = "SFX2D_" + str(i)
		player.bus = "SFX"
		player.max_polyphony = 1
		container_2d.add_child(player)
		_sfx_2d_pool.append(player)

	# 1D 非位置音效池
	var container_1d := Node.new()
	container_1d.name = "SFX1DPool"
	add_child(container_1d)

	for i in SFX_1D_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFX1D_" + str(i)
		player.bus = "SFX"
		player.max_polyphony = 1
		container_1d.add_child(player)
		_sfx_1d_pool.append(player)


# ============================================
# SFX 播放
# ============================================

## 播放音效（直接传入 SfxRef 资源引用）
## @param ref: SfxRef - 音效资源引用（由调用方在 Inspector 中配置并传入）
## @param position: Vector2（可选）- 世界坐标
func play_sfx_ref(ref: SfxRef, position: Vector2 = Vector2.ZERO) -> Node:
	if ref == null or ref.音频流 == null:
		return null

	if position != Vector2.ZERO and ref.最大传播距离 > 0.0:
		return _play_sfx_2d(ref, position)
	else:
		return _play_sfx_1d(ref)


## 播放位置音效（世界坐标）
func _play_sfx_2d(ref: SfxRef, position: Vector2) -> AudioStreamPlayer2D:
	var player := _sfx_2d_pool[_sfx_2d_next]
	_sfx_2d_next = (_sfx_2d_next + 1) % SFX_2D_POOL_SIZE

	if player.playing:
		player.stop()

	player.stream = ref.音频流
	player.bus = _resolve_bus(ref.总线, "SFX")
	player.global_position = position
	player.volume_db = linear_to_db(ref.音量)
	player.max_distance = ref.最大传播距离
	player.attenuation = ref.衰减系数
	player.pitch_scale = _random_pitch(ref)
	player.play()
	return player


## 播放非位置音效（UI 等）
func _play_sfx_1d(ref: SfxRef) -> AudioStreamPlayer:
	var player := _sfx_1d_pool[_sfx_1d_next]
	_sfx_1d_next = (_sfx_1d_next + 1) % SFX_1D_POOL_SIZE

	if player.playing:
		player.stop()

	player.stream = ref.音频流
	player.bus = _resolve_bus(ref.总线, "SFX")
	player.volume_db = linear_to_db(ref.音量)
	player.pitch_scale = _random_pitch(ref)
	player.play()
	return player


## 从 SfxRef 获取随机音调
func _random_pitch(ref: SfxRef) -> float:
	if ref.最低音调 >= ref.最高音调:
		return ref.最低音调
	return randf_range(ref.最低音调, ref.最高音调)


# ============================================
# 音乐播放
# ============================================

## 播放背景音乐（直接传入 MusicRef 资源引用），自动淡入淡出
## @param ref: MusicRef - 音乐资源引用（由场景配置方在 Inspector 中配置并传入）
func play_music_ref(ref: MusicRef) -> void:
	if ref == null or ref.音频流 == null:
		return

	# 相同引用不重复播放
	if ref == _current_music_ref:
		return

	var fade_out := _get_current_music_fade_out()

	# 如果当前有音乐在播放，执行淡出
	if _current_music_channel and _current_music_channel.playing:
		_fade_and_stop_channel(_current_music_channel, fade_out)
		await get_tree().create_timer(fade_out * 0.5).timeout

	# 切换通道
	var target_channel := _get_idle_music_channel()
	_current_music_ref = ref

	target_channel.stream = ref.音频流
	target_channel.bus = _resolve_bus(ref.总线, "Music")
	target_channel.volume_db = linear_to_db(0.01)  # 起始几乎无声

	# 设置循环模式
	var loop_stream := target_channel.stream
	if loop_stream is AudioStreamWAV:
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if ref.循环播放 else AudioStreamWAV.LOOP_DISABLED
	elif loop_stream is AudioStreamOggVorbis:
		loop_stream.loop = ref.循环播放

	target_channel.play()

	# 执行淡入
	_fade_channel_volume(target_channel, ref.音量, ref.淡入时间)

	_swap_music_channels()
	_current_music_channel = target_channel
	_idle_music_channel = _get_other_channel(target_channel)


## 停止背景音乐（淡出）
func stop_music(fade_out: float = -1.0) -> void:
	if fade_out < 0:
		fade_out = _get_current_music_fade_out()

	_current_music_ref = null

	for channel in [_music_a, _music_b]:
		if channel.playing:
			_fade_and_stop_channel(channel, fade_out)


func _fade_channel_volume(channel: AudioStreamPlayer, target_volume: float, duration: float) -> void:
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()

	_music_fade_tween = create_tween()
	_music_fade_tween.tween_method(
		func(v: float): channel.volume_db = linear_to_db(v),
		0.0, target_volume, duration
	).set_trans(Tween.TRANS_LINEAR)


func _fade_and_stop_channel(channel: AudioStreamPlayer, duration: float) -> void:
	var current_vol := db_to_linear(channel.volume_db)
	var tween := create_tween()
	tween.tween_method(
		func(v: float): channel.volume_db = linear_to_db(v),
		current_vol, 0.0, duration
	).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		channel.stop()
	)


func _get_current_music_fade_out() -> float:
	if _current_music_ref == null:
		return 0.5
	return _current_music_ref.淡出时间


func _get_idle_music_channel() -> AudioStreamPlayer:
	# 返回空闲的音乐通道（优先使用未播放的）
	if _idle_music_channel and not _idle_music_channel.playing:
		return _idle_music_channel
	if _current_music_channel == _music_a:
		return _music_b
	return _music_a


func _get_other_channel(channel: AudioStreamPlayer) -> AudioStreamPlayer:
	if channel == _music_a:
		return _music_b
	return _music_a


func _swap_music_channels() -> void:
	var temp := _current_music_channel
	_current_music_channel = _idle_music_channel
	_idle_music_channel = temp


# ============================================
# 音频总线音量控制
# ============================================

## 设置总线音量（线性 0.0 ~ 1.0）
func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	if not _bus_indices.has(bus_name):
		return
	var idx: int = _bus_indices[bus_name]
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))


## 获取总线音量（线性 0.0 ~ 1.0）
func get_bus_volume_linear(bus_name: String) -> float:
	if not _bus_indices.has(bus_name):
		return 0.0
	var idx: int = _bus_indices[bus_name]
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


## 静音/取消静音总线
func set_bus_mute(bus_name: String, mute: bool) -> void:
	if not _bus_indices.has(bus_name):
		return
	var idx: int = _bus_indices[bus_name]
	AudioServer.set_bus_mute(idx, mute)


## 是否静音
func is_bus_muted(bus_name: String) -> bool:
	if not _bus_indices.has(bus_name):
		return false
	var idx: int = _bus_indices[bus_name]
	return AudioServer.is_bus_mute(idx)


# ============================================
# 工具方法
# ============================================

## 获取当前播放的音乐引用（null 表示无）
func get_current_music_ref() -> MusicRef:
	return _current_music_ref


## 判断音乐是否正在播放
func is_music_playing() -> bool:
	return _current_music_channel != null and _current_music_channel.playing


## 解析总线名称：如果为空或无效则回退到默认总线
func _resolve_bus(bus_name: String, fallback: String) -> String:
	if bus_name.is_empty():
		return fallback
	# 验证总线是否存在于 AudioServer 中
	if AudioServer.get_bus_index(bus_name) < 0:
		GMLogger.log_info("AudioManager: 总线 '%s' 不存在，回退至 '%s'" % [bus_name, fallback])
		return fallback
	return bus_name
