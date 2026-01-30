extends Control
class_name HealthBar

@export var 背景颜色: Color
@export var 填充颜色: Color

@onready var health_label: Label = $HealthLabel
@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	var 背景_style = progress_bar.get_theme_stylebox("background").duplicate()
	背景_style.bg_color = 背景颜色

	var 填充_style = progress_bar.get_theme_stylebox("fill").duplicate()
	填充_style.bg_color = 填充颜色

	progress_bar.add_theme_stylebox_override("background", 背景_style)
	progress_bar.add_theme_stylebox_override("fill", 填充_style)

func 更新生命条(当前生命值: int, 生命上限: int) -> void:
	progress_bar.max_value = 生命上限
	progress_bar.value = 当前生命值
	health_label.text = "%d" % 当前生命值


func _on_单位属性component_生命值变化(生命值属性:单位属性) -> void:
	更新生命条(owner.attribute_component.获取属性值("生命值"), owner.attribute_component.获取属性值("最大生命值"))
