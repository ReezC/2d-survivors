extends Node2D

@export var zmap_file: zmap


func _ready() -> void:
	if zmap_file == null:
		push_warning("视觉节点缺少 zmap_file 引用")
		return

	# 为每个子节点按 now_z 属性获取 zmap 中的索引来分配 z_index
	# zmap index 越小 → 显示在越上方 → z_index 越大
	var total_layers := zmap_file.get_layer_count()
	for child in get_children():
		var layer: zmap.Layer
		# 优先使用子节点的 now_z 属性
		if child.has_method("get") and "now_z" in child:
			layer = child.now_z
		else:
			# 回退到通过名称查找
			var idx := zmap_file.get_layer_index_by_name(child.name)
			if idx == -1:
				push_warning("子节点 '%s' 未在 zmap.Layer 枚举中找到，且没有 now_z 属性" % child.name)
				continue
			layer = zmap.Layer.values()[idx]

		var idx := zmap_file.get_layer_index(layer)
		# index 越小 z_index 越大，用 total_layers - idx 实现反序
		child.z_index = total_layers - idx
