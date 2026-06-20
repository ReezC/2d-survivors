extends Node2D

@export var zmap_file: zmap


func _ready() -> void:
	if zmap_file == null:
		push_warning("视觉节点缺少 zmap_file 引用")
		return
	# 按 zmap 层级排序子节点顺序（z_index = 0，不污染 actor 间排序）
	reorder_children_by_zmap()


## 按 zmap 层级排序子节点：zmap 枚举中越靠前 → 子节点 index 越大 → 渲染在上层
## 不使用 z_index，保持所有子节点 z_index = 0，仅靠节点顺序控制部件间遮挡
func reorder_children_by_zmap() -> void:
	if zmap_file == null:
		return

	# 收集子节点及其 zmap 层级索引
	var child_layers: Array[Dictionary] = []
	for child in get_children():
		var layer: zmap.Layer
		if child is VisualItemPart:
			layer = child.z
		else:
			var idx := zmap_file.get_layer_index_by_name(child.name)
			if idx == -1:
				# push_warning("子节点 '%s' 未在 zmap.Layer 枚举中找到，且没有 z 属性" % child.name)
				continue
			layer = zmap.Layer.values()[idx]

		var layer_idx := zmap_file.get_layer_index(layer)
		child.z_index = 0  # 不使用 z_index，避免污染 actor 间排序
		child_layers.append({"node": child, "layer_idx": layer_idx})

	# 按 layer_idx 降序排列（layer_idx 大的在下层，layer_idx 小的在上层）
	child_layers.sort_custom(func(a, b): return a.layer_idx > b.layer_idx)

	# 按排序结果移动节点（index 0 在底层，index 最大在上层）
	for i in child_layers.size():
		var child: Node = child_layers[i].node
		move_child(child, i)
