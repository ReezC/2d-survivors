class_name VisualImg extends Resource



@export var id: String 

## 装备位
@export var islot: ISLOT.islot_enum 

## 视觉位
@export_flags("Bd","Hd","Cp","Fc","H1","H2","H3","H4","H5","H6","Hs","Hf","Hb","Af","Ay","As","Ae") var vslot 

## 动画配置
@export var anim_config: Array[AnimConfig] = []

