extends Node3D

@onready var camera_pivot: Node3D = $CameraPivot


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  # rotate camera pivot
  camera_pivot.rotate_y(deg_to_rad(10) * delta)


func _on_play_button_pressed() -> void:
  # go to game scene
  get_tree().change_scene_to_file("res://world.tscn")


func _on_exit_button_pressed() -> void:
  # exit the game
  get_tree().quit()
