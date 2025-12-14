extends Node3D

@onready var red_light: SpotLight3D = $RedSpotLight3D
@onready var blue_light: SpotLight3D = $BlueSpotLight3D

func _process(delta: float) -> void:
  # rotate camera pivot
  red_light.rotate_y(deg_to_rad(720) * delta)
  blue_light.rotate_y(deg_to_rad(720) * delta)
