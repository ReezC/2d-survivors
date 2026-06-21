extends Node
# AudioManager - 音频系统管理 Autoload
# 负责管理音效播放池、背景音乐切换、音频总线音量控制

# ============================================
# 导出配置
# ============================================
@export_dir var sfx_config_dir: String = "res://config/_audioconfig_音频配置_sfx"
@export_dir var music_config_dir: String = "res://config/_audioconfig_音频配置_music"

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
var _current_music_id: int = -1
var _music_fade_tween: Tween

# ============================================
# 配置缓存
# ============================================
var _sfx_config: Dictionary = {}
var _music_config: Dictionary = {}
var _stream_cache: Dictionary = {}

# ============================================
# 音量默认值
# ============================================
var _default_volumes: Dictionary = {
	"Master": 1.0,
	"Music": 0.8,
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
	_load_config()
	_connect_game_events()
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
# 配置加载
# ============================================

func _load_config() -> void:
	_load_sfx_from_cfggen()
	_load_music_from_cfggen()


func _load_sfx_from_cfggen() -> void:
	# 从 cfggen 生成的 JSON 目录加载音效配置
	if sfx_config_dir.is_empty():
		return

	var dir := DirAccess.open(sfx_config_dir)
	if dir == null:
		GMLogger.log_info("AudioManager: 无法打开 SFX 配置目录 %s" % sfx_config_dir)
		_load_sfx_fallback()
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_parse_sfx_json(sfx_config_dir + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	GMLogger.log_info("AudioManager: 加载了 %d 条音效配置" % _sfx_config.size())


func _parse_sfx_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return

	var id: int = data.get("id", -1)
	if id < 0:
		return

	# 从 asset.assetref 获取路径（cfggen 会解析外键引用）
	var asset_path: String = data.get("assetPath", "")
	if asset_path.is_empty():
		asset_path = data.get("path", "")

	_sfx_config[id] = {
		"id": id,
		"name": data.get("name", ""),
		"path": asset_path,
		"bus": data.get("bus", "SFX"),
		"volume": float(data.get("volume", 1.0)),
		"pitchMin": float(data.get("pitchMin", 1.0)),
		"pitchMax": float(data.get("pitchMax", 1.0)),
		"maxDistance": float(data.get("maxDistance", 0)),
		"attenuation": float(data.get("attenuation", 0)),
		"loop": bool(data.get("loop", false)),
	}


func _load_sfx_fallback() -> void:
	# 开发阶段的硬编码默认配置
	# 当 cfggen JSON 尚未生成时使用，方便快速调试
	# 格式: { id: {name, path, bus, volume, pitchMin, pitchMax, maxDistance, attenuation, loop} }
	_sfx_config = {
		1: {"id":1, "name":"玩家受击", "path":"", "bus":"SFX", "volume":1.0, "pitchMin":0.9, "pitchMax":1.1, "maxDistance":0, "attenuation":0, "loop":false},
		2: {"id":2, "name":"玩家死亡", "path":"", "bus":"SFX", "volume":1.0, "pitchMin":0.9, "pitchMax":1.1, "maxDistance":0, "attenuation":0, "loop":false},
		3: {"id":3, "name":"敌人受击", "path":"res://assets/MapleStory/Sound/Mob/0100100.Damage.mp3", "bus":"SFX", "volume":0.8, "pitchMin":0.9, "pitchMax":1.1, "maxDistance":1200, "attenuation":0.5, "loop":false},
		4: {"id":4, "name":"敌人死亡", "path":"res://assets/MapleStory/Sound/Mob/0100100.Die.mp3", "bus":"SFX", "volume":0.8, "pitchMin":0.9, "pitchMax":1.1, "maxDistance":1200, "attenuation":0.5, "loop":false},
		5: {"id":5, "name":"UI点击", "path":"", "bus":"UISFX", "volume":0.8, "pitchMin":1.0, "pitchMax":1.0, "maxDistance":0, "attenuation":0, "loop":false},
		6: {"id":6, "name":"UI悬停", "path":"", "bus":"UISFX", "volume":0.6, "pitchMin":1.0, "pitchMax":1.0, "maxDistance":0, "attenuation":0, "loop":false},
		7: {"id":7, "name":"升级", "path":"", "bus":"UISFX", "volume":1.0, "pitchMin":1.0, "pitchMax":1.0, "maxDistance":0, "attenuation":0, "loop":false},
		8: {"id":8, "name":"脚步声", "path":"", "bus":"SFX", "volume":0.5, "pitchMin":0.9, "pitchMax":1.1, "maxDistance":400, "attenuation":0.2, "loop":false},
	}
	GMLogger.log_info("AudioManager: 使用内置默认 SFX 配置（%d条）" % _sfx_config.size())


func _load_music_from_cfggen() -> void:
	if music_config_dir.is_empty():
		return

	var dir := DirAccess.open(music_config_dir)
	if dir == null:
		GMLogger.log_info("AudioManager: 无法打开 Music 配置目录 %s" % music_config_dir)
		_load_music_fallback()
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_parse_music_json(music_config_dir + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	GMLogger.log_info("AudioManager: 加载了 %d 条音乐配置" % _music_config.size())


func _parse_music_json(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return

	var id: int = data.get("id", -1)
	if id < 0:
		return

	var asset_path: String = data.get("assetPath", "")
	if asset_path.is_empty():
		asset_path = data.get("path", "")

	_music_config[id] = {
		"id": id,
		"name": data.get("name", ""),
		"path": asset_path,
		"bus": data.get("bus", "Music"),
		"volume": float(data.get("volume", 0.8)),
		"fadeIn": float(data.get("fadeIn", 1.0)),
		"fadeOut": float(data.get("fadeOut", 1.0)),
		"loop": bool(data.get("loop", true)),
	}


func _load_music_fallback() -> void:
	_music_config = {
		1: {"id":1, "name":"主界面", "path":"res://assets/MapleStory/Sound/Bgm00.img/RestNPeace.mp3", "bus":"Music", "volume":0.8, "fadeIn":1.0, "fadeOut":0.5, "loop":true},
		2: {"id":2, "name":"普通战斗", "path":"res://assets/MapleStory/Sound/Bgm00.img/RestNPeace.mp3", "bus":"Music", "volume":0.8, "fadeIn":1.0, "fadeOut":1.0, "loop":true},
		3: {"id":3, "name":"Boss战", "path":"", "bus":"Music", "volume":0.9, "fadeIn":0.5, "fadeOut":1.5, "loop":true},
		4: {"id":4, "name":"胜利", "path":"", "bus":"Music", "volume":1.0, "fadeIn":0.5, "fadeOut":0.5, "loop":false},
		5: {"id":5, "name":"失败", "path":"", "bus":"Music", "volume":0.8, "fadeIn":1.0, "fadeOut":1.0, "loop":false},
	}
	GMLogger.log_info("AudioManager: 使用内置默认 Music 配置（%d条）" % _music_config.size())


# ============================================
# SFX 播放
# ============================================

## 播放音效（按配置 ID）
## @param sfx_id: int - 音效配置 ID
## @param position: Vector2（可选）- 世界坐标，传入后使用位置音效
## @return Node（AudioStreamPlayer 或 AudioStreamPlayer2D）
func play_sfx(sfx_id: int, position: Vector2 = Vector2.ZERO) -> Node:
	var config: Dictionary = _sfx_config.get(sfx_id, {})
	if config.is_empty():
		return null

	var path: String = config.get("path", "")
	if path.is_empty():
		return null

	var stream: AudioStream = _get_stream(path)
	if stream == null:
		return null

	var bus_name: String = config.get("bus", "SFX")

	if position != Vector2.ZERO and config.get("maxDistance", 0) > 0:
		# 使用位置音效
		return _play_sfx_2d(stream, config, bus_name, position)
	else:
		# 使用非位置音效
		return _play_sfx_1d(stream, config, bus_name)


## 播放位置音效（世界坐标）
func _play_sfx_2d(stream: AudioStream, config: Dictionary, bus_name: String, position: Vector2) -> AudioStreamPlayer2D:
	var player := _sfx_2d_pool[_sfx_2d_next]
	_sfx_2d_next = (_sfx_2d_next + 1) % SFX_2D_POOL_SIZE

	# 如果有正在播放的循环音效，停止它
	if player.playing:
		player.stop()

	player.stream = stream
	player.bus = bus_name
	player.global_position = position
	player.volume_db = linear_to_db(config.get("volume", 1.0))
	player.max_distance = config.get("maxDistance", 1200.0)
	player.attenuation = config.get("attenuation", 1.0)

	var pitch := _random_pitch(config)
	player.pitch_scale = pitch

	player.play()
	return player


## 播放非位置音效（UI等）
func _play_sfx_1d(stream: AudioStream, config: Dictionary, bus_name: String) -> AudioStreamPlayer:
	var player := _sfx_1d_pool[_sfx_1d_next]
	_sfx_1d_next = (_sfx_1d_next + 1) % SFX_1D_POOL_SIZE

	if player.playing:
		player.stop()

	player.stream = stream
	player.bus = bus_name
	player.volume_db = linear_to_db(config.get("volume", 1.0))

	var pitch := _random_pitch(config)
	player.pitch_scale = pitch

	player.play()
	return player


func _random_pitch(config: Dictionary) -> float:
	var pitch_min: float = config.get("pitchMin", 1.0)
	var pitch_max: float = config.get("pitchMax", 1.0)
	if pitch_min >= pitch_max:
		return pitch_min
	return randf_range(pitch_min, pitch_max)


# ============================================
# 音乐播放
# ============================================

## 播放背景音乐（按配置 ID），自动淡入淡出
func play_music(music_id: int) -> void:
	if music_id == _current_music_id:
		return

	var config: Dictionary = _music_config.get(music_id, {})
	if config.is_empty():
		GMLogger.log_info("AudioManager: 未找到音乐配置 id=%d" % music_id)
		return

	var path: String = config.get("path", "")
	if path.is_empty():
		return

	var stream: AudioStream = _get_stream(path)
	if stream == null:
		return

	var fade_in: float = config.get("fadeIn", 1.0)
	var fade_out: float = _get_current_music_fade_out()
	var volume: float = config.get("volume", 0.8)

	# 如果当前有音乐在播放，执行淡出
	if _current_music_channel and _current_music_channel.playing:
		_fade_and_stop_channel(_current_music_channel, fade_out)
		await get_tree().create_timer(fade_out * 0.5).timeout

	# 切换通道
	var target_channel := _get_idle_music_channel()
	_current_music_id = music_id

	target_channel.stream = stream
	target_channel.bus = config.get("bus", "Music")
	target_channel.volume_db = linear_to_db(0.01)  # 起始几乎无声

	var loop_stream := target_channel.stream
	if loop_stream is AudioStreamWAV:
		loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if config.get("loop", true) else AudioStreamWAV.LOOP_DISABLED
	elif loop_stream is AudioStreamOggVorbis:
		loop_stream.loop = config.get("loop", true)

	target_channel.play()

	# 执行淡入
	_fade_channel_volume(target_channel, volume, fade_in)

	_swap_music_channels()
	_current_music_channel = target_channel
	_idle_music_channel = _get_other_channel(target_channel)


## 停止背景音乐（淡出）
func stop_music(fade_out: float = -1.0) -> void:
	if fade_out < 0:
		fade_out = _get_current_music_fade_out()

	_current_music_id = -1

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
	if _current_music_id < 0:
		return 0.5
	var config: Dictionary = _music_config.get(_current_music_id, {})
	return config.get("fadeOut", 1.0)


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
	# 交换当前/空闲通道引用
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
# 资源加载
# ============================================

func _get_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null

	if _stream_cache.has(path):
		return _stream_cache[path]

	var stream: AudioStream = load(path)
	if stream:
		_stream_cache[path] = stream
	return stream


# ============================================
# GameEvents 信号连接
# ============================================

func _connect_game_events() -> void:
	if not GameEvents:
		return

	var ge := GameEvents as Node
	# 经验拾取 → 拾取音效
	if ge.has_signal("experience_vial_collected"):
		ge.experience_vial_collected.connect(_on_experience_collected)

	# 能力升级 → 升级音效
	if ge.has_signal("ability_upgrade_added"):
		ge.ability_upgrade_added.connect(_on_ability_upgrade)


func _on_experience_collected(_exp_amount: int) -> void:
	# TODO: 替换为拾取经验的音效 ID
	pass


func _on_ability_upgrade(_upgrade, _current_upgrades: Dictionary) -> void:
	play_sfx(7)  # 升级音效


# ============================================
# 工具方法
# ============================================

## 预加载音效（避免首次播放时的卡顿）
func preload_sfx(sfx_id: int) -> void:
	var config: Dictionary = _sfx_config.get(sfx_id, {})
	var path: String = config.get("path", "")
	if not path.is_empty():
		_get_stream(path)


## 预加载音乐
func preload_music(music_id: int) -> void:
	var config: Dictionary = _music_config.get(music_id, {})
	var path: String = config.get("path", "")
	if not path.is_empty():
		_get_stream(path)


## 获取当前播放的音乐 ID（-1 表示无）
func get_current_music_id() -> int:
	return _current_music_id


## 判断音乐是否正在播放
func is_music_playing() -> bool:
	return _current_music_channel != null and _current_music_channel.playing
