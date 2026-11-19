@tool
@icon("res://addons/isolit/icons/iso_directional_light.svg")
extends IsoLight
class_name IsoDirectionalLight

## Parallel light across the whole scene.

@export var direction: Vector3 = Vector3(-1.0, -1.0, -1.0)
