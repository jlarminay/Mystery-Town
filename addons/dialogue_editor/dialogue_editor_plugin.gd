@tool
extends EditorPlugin

var panel: Panel = null

func _enter_tree():
	var panel_scene = preload("res://addons/dialogue_editor/dialogue_editor_panel.tscn")
	panel = panel_scene.instantiate()
	add_control_to_bottom_panel(panel, "Dialogue Editor")

func _exit_tree():
	remove_control_from_bottom_panel(panel)
