class_name VisualItem extends Resource
## 角色装备/外观部件定义
## 动画帧配置由 WZ 导出脚本自动生成，路径由 id 推导

## 装备 ID（如 "00002000"、"01302000"），对应 WZ Character 目录
@export var id: String

## 显示名称
@export var item_name: String

## 图标（背包/装备栏显示用）
@export var icon: Texture2D

## 默认动画动作名（如 "stand1"）
@export var default_action: String = "stand1"


## 获取动画配置 JSON 路径（convention over configuration）
func get_anim_config_path() -> String:
	return "res://config/_animconfig_animconfig/" + id + ".json"
