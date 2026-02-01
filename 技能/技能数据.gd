extends Resource
class_name 技能数据

@export var 技能ID: int
@export var 技能名称: String
@export var 技能图标: Texture2D
@export_multiline var 技能描述: String


@export_group("逻辑参数")
@export var 技能类型: 技能类型枚举 = 技能类型枚举.主动技能
## 技能逻辑实际就是创建buff实例所需要的数据，以json储存，读取为字典运行
@export_file("*.json") var 技能逻辑配置文件: String


@export_group("主动技能预制参数")
## 该配置仅主动技能生效,会被 技能逻辑配置文件 的配置覆盖
@export var 冷却时间: float = 0.0
## 该配置仅主动技能生效,会被 技能逻辑配置文件 的配置覆盖
@export var 触发范围: float = 0.0



enum 技能类型枚举 {
	主动技能,## 被技能AI调用释放
	被动技能,## 在SkillManager初始化时，激活其buff逻辑
}

var 技能逻辑: Dictionary = {}

# @export var 手动配置技能逻辑:技能本体_skillData


func 解析技能配置() -> void:
	if 技能逻辑配置文件 != "":
		var file = FileAccess.open(技能逻辑配置文件, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			var json = JSON.parse_string(json_text)
			技能逻辑 = json

func 获取技能CD():
	if 技能逻辑.has("CD"):
		return 技能逻辑["CD"]
	return 冷却时间

func 获取技能触发范围():
	if 技能逻辑.has("skillTriggerRange"):
		return 技能逻辑["skillTriggerRange"]
	return 触发范围
