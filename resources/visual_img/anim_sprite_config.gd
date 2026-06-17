class_name AnimSpriteConfig extends Resource

@export var name: String
@export_file var sprite_path: String
## Sprite的Offset，实际取反运算
@export var origin: Vector2

## 骨骼点位映射，key为骨骼名称。若骨骼名不存在，则以value创建骨骼；若存在，则使当前参考坐标-value
@export var map: Dictionary[String, Vector2]

## 当前帧的z层级
@export var z: zmap.Layer

### 暂不用
# @export var group: String