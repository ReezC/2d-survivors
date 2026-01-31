extends Control
class_name HealthBar

@export var 背景颜色: Color
@export var 填充颜色: Color

@export var 伤害颜色: Color = Color(1.0, 0.2, 0.2)  # 红色，用于显示伤害动画
@export var 动画速度: float = 200.0  # 血条减少速度（每秒减少的值）
@export var 动画延迟: float = 0   # 开始动画前的延迟时间（秒）

@onready var health_label: Label = $HealthLabel
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var damage_bar: ProgressBar = $DamageBar  # 添加一个伤害显示条



var 当前显示生命值: float = 0.0
var 目标生命值: float = 0.0
var 最大生命值: float = 0.0
var 动画计时器: float = 0.0
var 是否正在动画: bool = false
var 动画延迟计时器: float = 0.0
var 是否等待延迟: bool = false


@export var 启用数字跳动: bool = true
@export var 数字跳动幅度: float = 2.0
@export var 数字跳动速度: float = 1.0
var 数字跳动计时器: float = 0.0
var 原始标签位置: Vector2



func _ready() -> void:
	# 设置主血条样式
	var 背景_style = progress_bar.get_theme_stylebox("background").duplicate()
	# 背景_style.bg_color = 背景颜色
	
	var 填充_style = progress_bar.get_theme_stylebox("fill").duplicate()
	填充_style.bg_color = 填充颜色
	
	# 设置伤害条样式
	var 伤害背景_style = damage_bar.get_theme_stylebox("background").duplicate()
	伤害背景_style.bg_color = 背景颜色

	var 伤害填充_style = damage_bar.get_theme_stylebox("fill").duplicate()
	伤害填充_style.bg_color = 伤害颜色

	progress_bar.add_theme_stylebox_override("background", 背景_style)
	progress_bar.add_theme_stylebox_override("fill", 填充_style)
	damage_bar.add_theme_stylebox_override("background", 伤害背景_style)
	damage_bar.add_theme_stylebox_override("fill", 伤害填充_style)
	# 伤害背景_style.bg_color = Color.TRANSPARENT  # 透明背景

	
	
	# 初始化数值
	damage_bar.max_value = progress_bar.max_value
	damage_bar.value = progress_bar.value
	当前显示生命值 = progress_bar.value
	目标生命值 = progress_bar.value
	最大生命值 = progress_bar.max_value


	原始标签位置 = health_label.position

func _process(delta: float) -> void:
	if 是否正在动画:
		_更新动画(delta)
	elif 是否等待延迟:
		_更新延迟计时器(delta)
	
	# 数字跳动效果
	if 启用数字跳动 and 是否正在动画:
		_更新数字跳动(delta)

func 更新生命条(当前生命值: int, 生命上限: int) -> void:
	# 更新最大生命值
	最大生命值 = 生命上限
	progress_bar.max_value = 生命上限
	damage_bar.max_value = 生命上限
	
	var 之前生命值 = 目标生命值
	目标生命值 = 当前生命值
	
	# 立即更新主血条和标签
	progress_bar.value = 当前生命值
	health_label.text = "%d" % 当前生命值
	
	# 如果生命值减少，启动伤害动画
	if 当前生命值 < 之前生命值:
		开始伤害动画(之前生命值, 当前生命值)
	elif 当前生命值 > 之前生命值:
		# 如果是治疗，立即更新伤害条
		damage_bar.value = 当前生命值
		当前显示生命值 = 当前生命值
	# 注意：如果生命值相等，什么都不做

func 开始伤害动画(之前生命值: float, 新生命值: float):
	# 设置当前显示值为之前的生命值
	当前显示生命值 = 之前生命值
	damage_bar.value = 之前生命值
	
	# 启动延迟计时器
	是否等待延迟 = true
	动画延迟计时器 = 动画延迟

func _更新延迟计时器(delta: float):
	动画延迟计时器 -= delta
	if 动画延迟计时器 <= 0:
		是否等待延迟 = false
		是否正在动画 = true
		
		# 计算需要减少的总量
		var 需要减少量 = 当前显示生命值 - 目标生命值
		if 需要减少量 > 0:
			# 根据减少量调整动画速度，减少量越大动画越快
			var 调整后速度 = 动画速度 + (需要减少量 * 0.5)
			# 确保不会太快
			动画速度 = min(调整后速度, 动画速度 * 3)

func _更新动画(delta: float):
	if 当前显示生命值 > 目标生命值:
		# 计算这帧要减少的值
		var 减少量 = 动画速度 * delta
		当前显示生命值 = max(目标生命值, 当前显示生命值 - 减少量)
		damage_bar.value = 当前显示生命值
		
		# 如果到达目标值，结束动画
		if 当前显示生命值 <= 目标生命值:
			结束动画()
	else:
		结束动画()

func 结束动画():
	是否正在动画 = false
	是否等待延迟 = false
	damage_bar.value = 目标生命值
	当前显示生命值 = 目标生命值
	# 重置动画速度到原始值（如果需要，可以在类变量中保存原始值）

	# 重置标签位置
	health_label.position = 原始标签位置

# 可以添加一个立即结束动画的方法
func 立即结束动画():
	是否正在动画 = false
	是否等待延迟 = false
	当前显示生命值 = 目标生命值
	damage_bar.value = 目标生命值

# 添加一个重置方法
func 重置():
	是否正在动画 = false
	是否等待延迟 = false
	当前显示生命值 = progress_bar.value
	目标生命值 = progress_bar.value
	damage_bar.value = progress_bar.value

func _on_单位属性component_生命值变化(生命值属性:单位属性) -> void:
	更新生命条(owner.attribute_component.获取属性值("生命值"), owner.attribute_component.获取属性值("生命上限"))


func _更新数字跳动(delta: float):
	数字跳动计时器 += delta
	var 跳动偏移 = sin(数字跳动计时器 * 数字跳动速度) * 数字跳动幅度
	health_label.position = 原始标签位置 - Vector2(0, 跳动偏移)
