@tool
@icon("res://addons/isolit/icons/iso_spot_light.svg")
extends IsoPositionalLight
class_name IsoSpotLight

@export var aim_world: Vector3 = Vector3(0.0, 0.0, -1.0)

@export_group("Cone")
## Outer half-angle from the aim direction to the cone edge, in degrees.
@export_range(0.0, 90.0) var spot_angle: float = 30.0
## 0 = hard cone edge, 1 = fades all the way from the center.
@export_range(0.0, 1.0) var spot_softness: float = 0.5
