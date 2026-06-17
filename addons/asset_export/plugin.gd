@tool
extends EditorPlugin


const PLUGIN_NAME := "AssetExport"
const DOCK_NAME := "资产导出"

var dock: Control


func _enter_tree() -> void:
	dock = preload("res://addons/asset_export/export_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)


func _exit_tree() -> void:
	remove_control_from_docks(dock)
	if is_instance_valid(dock):
		dock.queue_free()
