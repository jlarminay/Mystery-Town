# Simple DialogueNode Usage

## What Each Component Does

### DialogueRuntime (Autoload Singleton)
- **Purpose**: Loads all dialogue data files at game start
- **Location**: Autoload as `/root/DialogueRuntime`
- **Usage**: You rarely interact with it directly - DialogueNode uses it automatically

### DialogueNode (Attach to Characters/NPCs)
- **Purpose**: Handles dialogue flow for ONE character
- **Signals**: Tells you when dialogue updates, ends, or player chooses responses
- **Usage**: Attach this to each NPC/character that has dialogue

### DialogueGraphNode (Editor Only)
- **Purpose**: Visual node in the dialogue editor - NOT used at runtime
- **Usage**: Only used when creating dialogues in the editor panel

---

## Quick Setup Example

### 1. Add DialogueNode to Your Character

Open your character scene (e.g., `mike.tscn`) and add a `DialogueNode` as a child:

```
mike (StaticBody3D)
├─ CollisionShape3D
├─ Sprite3D
├─ Label3D
└─ DialogueNode  <-- Add this
```

### 2. Configure DialogueNode Properties

In the Inspector for DialogueNode, set:
- **Character Name**: `Mike` (must match name in dialogue editor)
- **Dialogue File**: Leave empty (DialogueRuntime loads all dialogues automatically)
- **Auto Start**: `false` (start dialogue manually when player interacts)

### 3. Connect to DialogueNode in Your Script

```gdscript
# mike.gd
extends StaticBody3D

@onready var dialogue_node = $DialogueNode
@onready var label = $Label3D

var player: CharacterBody3D
var distance: float = 0.0

func _ready() -> void:
	# Connect to dialogue signals
	dialogue_node.dialogue_line_shown.connect(_on_dialogue_shown)
	dialogue_node.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_node.node_entered.connect(_on_node_entered)
	
	player = get_tree().current_scene.get_node_or_null("player")

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	
	# Face the player
	var origin := global_transform.origin
	var target := player.global_transform.origin
	target.y = origin.y
	look_at(target, Vector3.UP)
	rotate_y(PI)
	rotation.x = 0.0
	
	# Calculate distance
	distance = origin.distance_to(player.global_transform.origin)
	label.text = "Distance: %.2f" % distance
	
	# Show interact prompt when close
	if distance < 2.0:
		player.show_interact_prompt(self)
	elif distance < 3.0:
		player.show_interact_prompt(null)

# Called when player presses interact button
func interact() -> void:
	if not dialogue_node.is_active():
		dialogue_node.start_dialogue()

# Called when dialogue text is shown
func _on_dialogue_shown(character: String, text: String, node_id: String) -> void:
	print("Mike says: ", text)
	
	# Check if this node has response options
	var responses = dialogue_node.get_current_responses()
	if responses.is_empty():
		# Linear dialogue - player will advance by pressing a button
		# You'd typically show a "Continue" button in your UI here
		pass
	else:
		# Show response buttons in your UI
		for resp in responses:
			print("  Option %d: %s" % [resp.index, resp.text])

# Called when dialogue ends
func _on_dialogue_ended(character: String) -> void:
	print("Dialogue with ", character, " ended")
	# Hide dialogue UI, return control to player, etc.

# Called when entering a dialogue node (before text is shown)
# Perfect for changing sprites/animations
func _on_node_entered(node_id: String, node_data: Dictionary) -> void:
	var text = node_data.get("text", "").to_lower()
	
	# Change sprite based on dialogue content
	if "angry" in text or "mad" in text:
		# $Sprite.play("angry")
		pass
	elif "happy" in text or "smile" in text:
		# $Sprite.play("happy")
		pass
	else:
		# $Sprite.play("neutral")
		pass
```

### 4. Player Script Integration

Your player script needs to handle the interact prompt and trigger the interaction:

```gdscript
# player.gd (simplified example)
extends CharacterBody3D

var current_interact_target = null

func show_interact_prompt(target) -> void:
	current_interact_target = target
	if target:
		# Show "Press E to talk" UI
		pass
	else:
		# Hide interact prompt
		pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if current_interact_target and current_interact_target.has_method("interact"):
			current_interact_target.interact()
```

### 5. UI Integration (Dialogue Display)

You'll want to create a UI that listens to the dialogue signals:

```gdscript
# dialogue_ui.gd
extends CanvasLayer

@onready var text_label = $Panel/TextLabel
@onready var response_container = $Panel/ResponseContainer
@onready var continue_button = $Panel/ContinueButton

var active_dialogue_node: DialogueNode = null

func show_dialogue(dialogue_node: DialogueNode) -> void:
	active_dialogue_node = dialogue_node
	
	# Connect signals
	dialogue_node.dialogue_line_shown.connect(_on_line_shown)
	dialogue_node.dialogue_ended.connect(_on_ended)
	
	show()

func _on_line_shown(character: String, text: String, node_id: String) -> void:
	text_label.text = text
	
	# Clear old responses
	for child in response_container.get_children():
		child.queue_free()
	
	# Check for responses
	var responses = active_dialogue_node.get_current_responses()
	if responses.is_empty():
		# Show continue button for linear dialogue
		continue_button.show()
	else:
		continue_button.hide()
		# Create response buttons
		for resp in responses:
			var button = Button.new()
			button.text = resp.text
			var index = resp.index
			button.pressed.connect(func(): _on_response_chosen(index))
			response_container.add_child(button)

func _on_response_chosen(index: int) -> void:
	if active_dialogue_node:
		active_dialogue_node.select_response(index)

func _on_continue_pressed() -> void:
	if active_dialogue_node:
		active_dialogue_node.advance()

func _on_ended(character: String) -> void:
	hide()
	active_dialogue_node = null
```

---

## Summary

1. **DialogueRuntime** = Autoload that loads all dialogue files (you don't touch this much)
2. **DialogueNode** = Attach to each character/NPC, configure with their name
3. Connect to DialogueNode signals in your character script
4. Call `dialogue_node.start_dialogue()` when player interacts
5. Display text and responses in your UI based on signals

That's it! The dialogue editor creates the flow, DialogueNode runs it, and you just respond to the signals.
