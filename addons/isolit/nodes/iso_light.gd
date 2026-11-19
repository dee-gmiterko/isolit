@tool
extends Node2D
class_name IsoLight

const BlendMode = IsoShaderLibrary.BlendMode

@export var enabled: bool = true
@export var color: Color = Color.WHITE
@export var energy: float = 1.0

@export_group("Advanced")
@export var blend_mode: BlendMode = BlendMode.ADD


func _enter_tree() -> void:
	add_to_group("iso_lights")


func _exit_tree() -> void:
	remove_from_group("iso_lights")
