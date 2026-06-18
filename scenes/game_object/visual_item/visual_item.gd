extends Node2D
## 纸娃娃动画配置
# @export var img_resource: VisualImg
@export var now_z: zmap.Layer = zmap.Layer.body

## res://config/_animconfig_animconfig/
@export_file("*.json")  var 动画帧配置文件 : String
@export var icon: Texture2D

func 获取骨骼global_position(bone_name: String) -> Vector2:
    return Vector2.ZERO ## TODO: 纸娃娃骨骼位置获取，暂时返回(0,0)