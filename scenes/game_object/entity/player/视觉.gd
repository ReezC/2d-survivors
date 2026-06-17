extends Node2D

@export var zmap_file:zmap

func _ready() -> void:
    print(zmap_file.get_layer_index("body"))