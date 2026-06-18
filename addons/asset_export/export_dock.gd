@tool
extends VBoxContainer

## 资产文件夹路径
@export_dir var asset_folder: String = "res://assets":
	set(v):
		asset_folder = v
		if is_instance_valid(asset_path_edit):
			asset_path_edit.text = v

## 生成文件的路径
@export_global_dir var output_path: String = "res://asset_list.csv":
	set(v):
		output_path = v
		if is_instance_valid(output_path_edit):
			output_path_edit.text = v

## 文件格式勾选
@export var check_png: bool = true
@export var check_ogg: bool = true
@export var check_wav: bool = true
@export var check_mp3: bool = true

var asset_path_edit: LineEdit
var output_path_edit: LineEdit
var png_check: CheckBox
var ogg_check: CheckBox
var wav_check: CheckBox
var mp3_check: CheckBox
var export_btn: Button
var status_label: Label


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# ---- 资产文件夹路径 ----
	var folder_label := Label.new()
	folder_label.text = "资产文件夹路径:"
	add_child(folder_label)

	var folder_hbox := HBoxContainer.new()
	add_child(folder_hbox)

	asset_path_edit = LineEdit.new()
	asset_path_edit.text = asset_folder
	asset_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asset_path_edit.text_changed.connect(func(t: String): asset_folder = t)
	folder_hbox.add_child(asset_path_edit)

	var folder_btn := Button.new()
	folder_btn.text = "..."
	folder_btn.pressed.connect(_on_select_asset_folder)
	folder_hbox.add_child(folder_btn)

	# ---- 文件格式 ----
	var format_label := Label.new()
	format_label.text = "文件格式:"
	add_child(format_label)

	var format_hbox := HBoxContainer.new()
	add_child(format_hbox)

	png_check = CheckBox.new()
	png_check.text = "png"
	png_check.button_pressed = check_png
	png_check.toggled.connect(func(b: bool): check_png = b)
	format_hbox.add_child(png_check)

	ogg_check = CheckBox.new()
	ogg_check.text = "ogg"
	ogg_check.button_pressed = check_ogg
	ogg_check.toggled.connect(func(b: bool): check_ogg = b)
	format_hbox.add_child(ogg_check)

	wav_check = CheckBox.new()
	wav_check.text = "wav"
	wav_check.button_pressed = check_wav
	wav_check.toggled.connect(func(b: bool): check_wav = b)
	format_hbox.add_child(wav_check)

	mp3_check = CheckBox.new()
	mp3_check.text = "mp3"
	mp3_check.button_pressed = check_mp3
	mp3_check.toggled.connect(func(b: bool): check_mp3 = b)
	format_hbox.add_child(mp3_check)

	# ---- 生成文件路径 ----
	var output_label := Label.new()
	output_label.text = "生成文件路径:"
	add_child(output_label)

	var output_hbox := HBoxContainer.new()
	add_child(output_hbox)

	output_path_edit = LineEdit.new()
	output_path_edit.text = output_path
	output_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_path_edit.text_changed.connect(func(t: String): output_path = t)
	output_hbox.add_child(output_path_edit)

	var output_btn := Button.new()
	output_btn.text = "..."
	output_btn.pressed.connect(_on_select_output_file)
	output_hbox.add_child(output_btn)

	# ---- 导出按钮 ----
	export_btn = Button.new()
	export_btn.text = "导出"
	export_btn.pressed.connect(_on_export)
	add_child(export_btn)

	# ---- 状态标签 ----
	status_label = Label.new()
	add_child(status_label)


func _get_selected_extensions() -> PackedStringArray:
	var exts := PackedStringArray()
	if check_png:
		exts.append("png")
	if check_ogg:
		exts.append("ogg")
	if check_wav:
		exts.append("wav")
	if check_mp3:
		exts.append("mp3")
	return exts


func _on_select_asset_folder() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.current_dir = asset_folder
	dialog.dir_selected.connect(func(path: String):
		asset_folder = path
		asset_path_edit.text = path
	)
	add_child(dialog)
	dialog.popup_centered_ratio()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.dir_selected.connect(func(_p: String): dialog.queue_free())


func _on_select_output_file() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = output_path.get_base_dir()
	dialog.current_file = output_path.get_file()
	dialog.add_filter("*.csv", "CSV 文件")
	dialog.file_selected.connect(func(path: String):
		output_path = path
		output_path_edit.text = path
	)
	add_child(dialog)
	dialog.popup_centered_ratio()
	dialog.close_requested.connect(dialog.queue_free)
	dialog.file_selected.connect(func(_p: String): dialog.queue_free())


func _on_export() -> void:
	if asset_folder.is_empty():
		status_label.text = "错误: 请设置资产文件夹路径"
		return

	if not DirAccess.dir_exists_absolute(asset_folder):
		status_label.text = "错误: 资产文件夹不存在: " + asset_folder
		return

	var exts := _get_selected_extensions()
	if exts.is_empty():
		status_label.text = "错误: 请至少勾选一种文件格式"
		return

	if output_path.is_empty():
		status_label.text = "错误: 请设置生成文件路径"
		return

	# 收集所有匹配的文件
	var files: Array[Dictionary] = []
	_collect_files(asset_folder, exts, files)

	if files.is_empty():
		status_label.text = "警告: 未找到匹配的文件"
		return

	# 写入 CSV
	var csv := _build_csv(files)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		status_label.text = "错误: 无法写入文件: " + output_path
		return

	file.store_string(csv)
	file.close()

	status_label.text = "导出完成! 共 %d 个文件 → %s" % [files.size(), output_path]
	print("[AssetExport] 导出完成: %d 个文件 → %s" % [files.size(), output_path])


func _collect_files(folder: String, exts: PackedStringArray, out_files: Array) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path := folder.path_join(file_name)

		if dir.current_is_dir():
			_collect_files(full_path, exts, out_files)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in exts:
				out_files.append({
					"path": full_path,
					"type": ext,
				})

		file_name = dir.get_next()

	dir.list_dir_end()


func _build_csv(files: Array) -> String:
	# 第一行：中文注释表头
	var csv := "ath,type\n"
	# 第二行：英文字段名
	csv += "path,type\n"
	# 数据行
	for f in files:
		csv += "%s,%s\n" % [f["path"], f["type"]]
	return csv
