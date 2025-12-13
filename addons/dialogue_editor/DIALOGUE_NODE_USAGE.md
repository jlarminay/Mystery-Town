# DialogueNode Usage Guide

## Overview
`DialogueNode` is a flexible node you can add to any scene (characters, NPCs, objects) to handle dialogue. It provides signals for all dialogue events and callbacks for custom logic.

## Basic Setup

1. Add a `DialogueNode` to your character scene
2. Set the `character_name` to match the character in your dialogue editor
3. Set `dialogue_file` to point to your dialogues folder (e.g., `res://dialogues/_manifest.json`)
4. Optionally enable `auto_start` to begin dialogue when the scene loads

## Simple Example

```gdscript
extends CharacterBody2D

@onready var dialogue = $DialogueNode

func _ready():
	# Connect to dialogue signals
	dialogue.dialogue_line_shown.connect(_on_dialogue_shown)
	dialogue.response_selected.connect(_on_response_selected)
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	dialogue.node_entered.connect(_on_node_entered)

func interact():
	if not dialogue.is_active():
		dialogue.start_dialogue()

func _on_dialogue_shown(character: String, text: String, node_id: String):
	# Display the dialogue in your UI
	DialogueUI.show_text(text)
	
	# Check if there are responses
	var responses = dialogue.get_current_responses()
	if responses.is_empty():
		# Linear dialogue - show a continue button
		DialogueUI.show_continue_button()
	else:
		# Show response options
		DialogueUI.show_responses(responses)

func _on_response_selected(response_text: String, index: int):
	print("Player chose: ", response_text)

func _on_dialogue_ended(character: String):
	DialogueUI.hide()
	print("Dialogue with ", character, " ended")

func _on_node_entered(node_id: String, node_data: Dictionary):
	# Perfect place for sprite changes, animations, camera moves, etc.
	if node_data.get("text", "").contains("angry"):
		$Sprite.play("angry")
	elif node_data.get("text", "").contains("happy"):
		$Sprite.play("happy")
```

## Advanced: Custom Response Visibility

Instead of just checking variables, you can run custom logic:

```gdscript
func _ready():
	# Set custom callback for response visibility
	dialogue.response_visibility_callback = _can_show_response
	dialogue.start_dialogue()

func _can_show_response(response_index: int, response_data: Dictionary) -> bool:
	# Custom logic - check inventory, quest state, time of day, etc.
	var text = response_data.get("text", "")
	
	if text.contains("buy sword"):
		return PlayerInventory.gold >= 100
	
	if text.contains("about the quest"):
		return QuestManager.has_active_quest("main_quest_1")
	
	if text.contains("good morning"):
		return TimeManager.is_morning()
	
	# Default to true if no special conditions
	return true
```

## Advanced: Custom Condition Validation

Override variable condition checking with your own logic:

```gdscript
func _ready():
	dialogue.custom_condition_validator = _validate_condition
	dialogue.start_dialogue()

func _validate_condition(var_id: String, op: String, expected_value) -> bool:
	# You can access any game state here
	match var_id:
		"player_level":
			return _compare_level(op, int(expected_value))
		"has_key":
			return PlayerInventory.has_item("gold_key")
		"reputation":
			return _compare_reputation(op, int(expected_value))
		_:
			# Fallback to default variable checking
			var current = DialogueRuntime.get_variable_value(var_id)
			return dialogue._compare_values(current, op, expected_value)

func _compare_level(op: String, expected: int) -> bool:
	var level = PlayerStats.level
	match op:
		"==": return level == expected
		">=": return level >= expected
		">": return level > expected
	return false
```

## Signals Reference

### `dialogue_started(character: String, dialogue_id: String)`
Emitted when dialogue begins.

### `dialogue_line_shown(character: String, text: String, node_id: String)`
Emitted when a dialogue line is displayed. Use this to update your UI.

### `response_selected(response_text: String, response_index: int)`
Emitted when the player selects a response.

### `dialogue_ended(character: String)`
Emitted when dialogue reaches an exit node or has no more connections.

### `node_entered(node_id: String, node_data: Dictionary)`
Emitted when entering a new node, **before** the text is shown. Perfect for:
- Changing character sprites/animations
- Playing sound effects
- Camera movements
- Spawning objects
- Any other scene changes

### `variables_changed(changed_vars: Dictionary)`
Emitted when a node's "On Enter: Set Variables" effects are applied. Dictionary contains `{var_id: new_value}`.

## Methods

### `start_dialogue(entry_node_id: String = "")`
Start dialogue from an entry node. If `entry_node_id` is empty, uses the first entry node found.

### `get_current_responses() -> Array`
Returns available responses for the current node. Each item is `{index, text, data}`.

### `select_response(response_index: int)`
Choose a response and advance to the next node.

### `advance()`
Advance to the next node in linear dialogue (no responses).

### `end_dialogue()`
Manually end the dialogue.

### `is_active() -> bool`
Check if dialogue is currently running.

## Example: Conditional Dialogue with Actions

```gdscript
extends NPC

@onready var dialogue = $DialogueNode
@onready var sprite = $AnimatedSprite2D

func _ready():
	dialogue.node_entered.connect(_on_node_entered)
	dialogue.dialogue_line_shown.connect(_on_dialogue_shown)
	dialogue.variables_changed.connect(_on_variables_changed)

func _on_node_entered(node_id: String, node_data: Dictionary):
	# Change sprite based on dialogue content or node ID
	var text = node_data.get("text", "")
	
	if "angry" in text.to_lower():
		sprite.play("angry")
		$AudioPlayer.play_sound("npc_angry")
	elif "happy" in text.to_lower():
		sprite.play("happy")
		$AudioPlayer.play_sound("npc_laugh")
	else:
		sprite.play("talk")

func _on_dialogue_shown(character: String, text: String, node_id: String):
	UI.show_dialogue_box(character, text)
	
	var responses = dialogue.get_current_responses()
	if responses.size() > 0:
		UI.show_response_buttons(responses)
	else:
		UI.show_continue_button()

func _on_variables_changed(changed_vars: Dictionary):
	# React to variable changes
	if "npc_trust" in changed_vars:
		var trust = int(changed_vars["npc_trust"])
		if trust >= 50:
			unlock_special_shop()

func _on_ui_response_clicked(index: int):
	dialogue.select_response(index)

func _on_ui_continue_clicked():
	dialogue.advance()
```
