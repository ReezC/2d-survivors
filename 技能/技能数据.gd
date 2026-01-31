extends Resource
class_name 技能数据

@export var 技能ID: int
@export var 技能图标: Texture2D
@export var 技能名称: String
@export_multiline var 技能描述: String
@export var 冷却时间: float = 0.0

## 技能逻辑实际就是创建buff实例所需要的数据，以json储存，读取为字典运行
@export_file("*.json") var 技能逻辑配置文件: String


var 技能逻辑: Dictionary
