class_name CharacterBone extends Node2D
## 角色骨骼节点 —— 通过 change_bone_position() 修改位置并广播 bone_position_changed 信号
##
## 挂在 body 骨骼根节点下，由 VisualItemPart.set_bone() 创建。
## VisualItemPart 初始化时绑定父骨骼的 bone_position_changed 信号，
## 当骨骼位置变化时自动同步自身位置。

signal bone_position_changed(new_position: Vector2)

## 修改骨骼位置并广播信号，让所有绑定此骨骼的部件同步自身位置
func change_bone_position(pos: Vector2) -> void:
	self.position = pos
	bone_position_changed.emit(pos)
