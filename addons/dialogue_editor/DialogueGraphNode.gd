@tool
extends GraphNode

## EDITOR ONLY: Visual node used in the dialogue editor panel.
## Do NOT add this to game scenes - use DialogueNode instead.
class_name DialogueGraphNode

var node_id: String = ""
var dialogue_text: String = ""
var character: String = ""
var node_type: String = "normal"  # "entry", "exit", or "normal"
var responses: Array = []  # Array of {text: String, next_node: String}
var response_conditions: Array = []  # Array parallel to responses: each is Array of {var_id, op, value}
var event_id: String = ""  # Optional custom event identifier

var type_label: Label
var type_dropdown: OptionButton
var char_label: Label
var dialogue_label: Label
var text_edit: TextEdit
var event_label: Label
var event_edit: LineEdit
var responses_label: Label
var add_response_btn: Button
var response_rows: Array = []
var response_spacers: Array = []

func _add_spacer(height: int = 8, parent: Node = null) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	if parent:
		parent.add_child(spacer)
	else:
		add_child(spacer)

func _init():
	node_id = str(Time.get_ticks_msec())
	name = node_id  # Set node name to match ID for connections
	title = "Dialogue Node"
	resizable = true
	size = Vector2(300, 200)

func setup(char_name: String):
	character = char_name
    
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	response_rows.clear()
    
	# Row 0: Type label
	type_label = Label.new()
	type_label.text = "Node Type:"
	add_child(type_label)
    
	# Row 1: Type dropdown
	type_dropdown = OptionButton.new()
	type_dropdown.add_item("Normal", 0)
	type_dropdown.add_item("Entry", 1)
	type_dropdown.add_item("Exit", 2)
	type_dropdown.selected = 0
	type_dropdown.item_selected.connect(_on_type_selected)
	add_child(type_dropdown)
        
	# Row 2: Dialogue label
	_add_spacer(8)
	dialogue_label = Label.new()
	dialogue_label.text = "Dialogue:"
	add_child(dialogue_label)
    
	# Row 3: Text edit
	text_edit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, 80)
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(_on_text_changed)
	add_child(text_edit)
	
	# Row 4: Event label
	_add_spacer(8)
	event_label = Label.new()
	event_label.text = "Event ID (optional):"
	add_child(event_label)
	
	# Row 5: Event edit
	event_edit = LineEdit.new()
	event_edit.placeholder_text = "e.g. learned_birthday, make_angry"
	event_edit.text_changed.connect(_on_event_changed)
	add_child(event_edit)
	
	# Row 6: Responses label
	_add_spacer(8)
	responses_label = Label.new()
	responses_label.text = "Responses:"
	add_child(responses_label)
	
	# Last: Add response button
	add_response_btn = Button.new()
	add_response_btn.text = "+ Add Response"
	add_response_btn.pressed.connect(_on_add_response)
	add_child(add_response_btn)
	
	# Setup slots
	_update_slots()

func _update_slots():
	# Clear all slots first
	clear_all_slots()
	
	# UI element order:
	# 0: Type label - INPUT
	# 1: Type dropdown
	# 2: Character label
	# 3: Dialogue label
	# 4: Text edit
	# 5: Response label
	# 6+: Response HBoxContainers (one per response) - OUTPUTS
	# Then: Add response button
	# Then: Effects container (label, rows, add button) — stays last
	
	# Slot 0: Type label - has input connection (entry point for this node)
	var has_input = (node_type != "entry")
	set_slot(0, has_input, 0, Color.CYAN, false, 0, Color.WHITE)
	
	# Slot 1: Type dropdown - no connections
	set_slot(1, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Slot 2: Spacer - no connections
	set_slot(2, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Slot 3: Dialogue label - no connections
	set_slot(3, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Slot 4: Text edit - ALWAYS has output if no responses (unless exit)
	# This is the "next dialogue" connection for linear flow
	if responses.size() == 0:
		var has_output = (node_type != "exit")
		set_slot(4, false, 0, Color.WHITE, has_output, 0, Color.GREEN)
	else:
		set_slot(4, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Slot 5: Spacer - no connections
	set_slot(5, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Slot 6: Response label - no connections
	set_slot(6, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Slots 7+: For each response, spacer then response row
	# Output ports on spacer slots to position them slightly above the response text
	var has_response_output = (node_type != "exit")
	for i in responses.size():
		# Spacer slot with output port
		set_slot(12 + i * 2, false, 0, Color.WHITE, has_response_output, 0, Color.GREEN)
		# Response row slot - no connections
		set_slot(12 + i * 2 + 1, false, 0, Color.WHITE, false, 0, Color.WHITE)
	
	# Add response button - no connections
	var add_resp_slot = 12 + responses.size() * 2
	set_slot(add_resp_slot, false, 0, Color.WHITE, false, 0, Color.WHITE)

func _on_type_selected(index: int):
	if index == 0:  # Normal
		node_type = "normal"
		title = "Dialogue Node"
		modulate = Color(1.0, 1.0, 1.0)
	elif index == 1:  # Entry
		node_type = "entry"
		title = "[ENTRY] Dialogue Node"
		modulate = Color(1.0, 1.0, 0.8)  # Slight yellow tint
	elif index == 2:  # Exit
		node_type = "exit"
		title = "[EXIT] Dialogue Node"
		modulate = Color(1.0, 0.8, 0.8)  # Slight red tint
	
	_update_slots()

func _on_text_changed():
	if text_edit:
		dialogue_text = text_edit.text

func _on_event_changed(new_text: String):
	event_id = new_text

func _on_add_response():
	var response_text = "Option %d" % (responses.size() + 1)
	responses.append({"text": response_text, "next_node": ""})
	response_conditions.append([])
	_rebuild_response_ui()
	_update_slots()

func _on_remove_response(index: int):
	responses.remove_at(index)
	if index >= 0 and index < response_conditions.size():
		response_conditions.remove_at(index)
	_rebuild_response_ui()
	_update_slots()

func _rebuild_response_ui():
	# Remove existing response rows
	for row in response_rows:
		if is_instance_valid(row):
			remove_child(row)
			row.queue_free()
	response_rows.clear()
	for sp in response_spacers:
		if is_instance_valid(sp):
			remove_child(sp)
			sp.queue_free()
	response_spacers.clear()
    
	# Rebuild response rows as direct children so ports align
	for i in responses.size():
		# Spacer row to nudge the port a bit lower
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		add_child(spacer)
		response_spacers.append(spacer)

		var response_box = HBoxContainer.new()
		response_box.custom_minimum_size = Vector2(0, 28)
		response_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        
		var response_edit = LineEdit.new()
		response_edit.text = responses[i]["text"]
		response_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var response_index = i
		response_edit.text_changed.connect(func(new_text):
			responses[response_index]["text"] = new_text
		)
		response_box.add_child(response_edit)
        
		var remove_btn = Button.new()
		remove_btn.text = "X"
		remove_btn.custom_minimum_size = Vector2(30, 0)
		var btn_index = i
		remove_btn.pressed.connect(func(): _on_remove_response(btn_index))
		response_box.add_child(remove_btn)

		# Conditions button
		var cond_btn = Button.new()
		# Ensure conditions array is sized
		while response_conditions.size() <= i:
			response_conditions.append([])
		var cond_count = response_conditions[i].size()
		cond_btn.text = "Cond (%d)" % cond_count
		cond_btn.custom_minimum_size = Vector2(65, 0)
		var cond_index = i
		cond_btn.pressed.connect(func(): _open_conditions_editor(cond_index))
		response_box.add_child(cond_btn)
		
		# Insert response rows before the add button (which is last child)
		add_child(response_box)
		response_rows.append(response_box)
	
	# Adjust node size based on content
	size.y = 230 + (responses.size() * 36)

	_update_slots()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _get_investigation_singleton() -> Object:
	# In-game (play) the autoload should exist as a singleton
	if Engine.has_singleton("Investigation"):
		return Engine.get_singleton("Investigation")

	# In editor, autoloads are not instantiated. Try to load and instantiate manually.
	var debug_msgs: Array = []
	var autoload_path = ProjectSettings.get_setting("autoload/Investigation", "")
	debug_msgs.append("autoload/Investigation = %s" % autoload_path)
	if typeof(autoload_path) == TYPE_STRING and autoload_path != "":
		var cleaned = autoload_path
		# Strip leading/trailing '*' that Godot uses to mark singleton scripts
		if cleaned.begins_with("*"):
			cleaned = cleaned.substr(1, cleaned.length() - 1)
		if cleaned.ends_with("*"):
			cleaned = cleaned.left(cleaned.length() - 1)
		autoload_path = cleaned
		debug_msgs.append("cleaned path = %s" % cleaned)
		var exists = ResourceLoader.exists(cleaned)
		debug_msgs.append("Resource exists: %s" % str(exists))
		if exists:
			var res = ResourceLoader.load(cleaned)
			debug_msgs.append("Resource type: %s" % typeof(res))
			if res is PackedScene:
				var inst = (res as PackedScene).instantiate()
				push_warning("Investigation autoload instantiated from PackedScene: %s" % cleaned)
				return inst
			elif res is Script:
				push_warning("Investigation autoload instantiated from Script: %s" % cleaned)
				return (res as Script).new()

	# Only emit debug if nothing was returned
	for msg in debug_msgs:
		push_warning(msg)
	return null

func _get_investigation_variables() -> Array:
	var names: Array = []
	var inv = _get_investigation_singleton()
	if inv:
		if inv.has_method("list_variables"):
			names = inv.list_variables()
		elif inv.has_method("get_all_keys"):
			names = inv.get_all_keys()
		elif inv.has_method("get_state"):
			var state = inv.get_state()
			if typeof(state) == TYPE_DICTIONARY:
				names = state.keys()
		elif inv.has_method("get_variables"):
			var vars_dict = inv.get_variables()
			if typeof(vars_dict) == TYPE_DICTIONARY:
				names = vars_dict.keys()
		elif inv.has_method("keys"):
			names = inv.keys()

	if names.size() > 1:
		names.sort()
	return names

func _open_conditions_editor(resp_index: int):
	while response_conditions.size() <= resp_index:
		response_conditions.append([])

	var conditions: Array = response_conditions[resp_index].duplicate(true)
	var variable_names: Array = _get_investigation_variables()
	var op_options: Array = ["==", "!=", ">=", "<=", ">", "<"]

	var dialog := ConfirmationDialog.new()
	dialog.title = "Response Conditions"
	dialog.exclusive = true
	add_child(dialog)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(520, 320)
	dialog.add_child(root)

	var info := Label.new()
	if variable_names.is_empty():
		info.text = "No Investigation singleton or variables found."
	else:
		info.text = "Variables loaded: %d" % variable_names.size()
	root.add_child(info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)

	var add_btn := Button.new()
	add_btn.text = "+ Add Condition"
	root.add_child(add_btn)

	var rebuild_rows: Callable = func():
		pass
	
	rebuild_rows = func():
		_clear_children(rows)
		for i in conditions.size():
			var cond = conditions[i]
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var var_label := Label.new()
			var_label.text = "Var:"
			row.add_child(var_label)

			var var_opt := OptionButton.new()
			var_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if variable_names.is_empty():
				var_opt.add_item("(no variables found)")
				var_opt.disabled = true
			else:
				for name in variable_names:
					var_opt.add_item(name)
				var selected_var = cond.get("var_id", "")
				var sel_index = variable_names.find(selected_var)
				if sel_index == -1:
					sel_index = 0
				var_opt.selected = sel_index
				cond["var_id"] = variable_names[sel_index]
			var var_idx = i
			var_opt.item_selected.connect(func(idx):
				if not variable_names.is_empty():
					conditions[var_idx]["var_id"] = variable_names[idx]
			)
			row.add_child(var_opt)

			var op_label := Label.new()
			op_label.text = "Op:"
			row.add_child(op_label)

			var op_opt := OptionButton.new()
			for op in op_options:
				op_opt.add_item(op)
			var selected_op = op_options.find(cond.get("op", "=="))
			if selected_op == -1:
				selected_op = 0
			op_opt.selected = selected_op
			var op_idx = i
			op_opt.item_selected.connect(func(idx):
				conditions[op_idx]["op"] = op_options[idx]
			)
			row.add_child(op_opt)

			var val_label := Label.new()
			val_label.text = "Value:"
			row.add_child(val_label)

			var val_edit := LineEdit.new()
			val_edit.text = str(cond.get("value", ""))
			val_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var val_idx = i
			val_edit.text_changed.connect(func(new_text):
				conditions[val_idx]["value"] = new_text
			)
			row.add_child(val_edit)

			var remove_btn := Button.new()
			remove_btn.text = "X"
			remove_btn.custom_minimum_size = Vector2(28, 0)
			var rem_idx = i
			remove_btn.pressed.connect(func():
				if rem_idx >= 0 and rem_idx < conditions.size():
					conditions.remove_at(rem_idx)
					rebuild_rows.call()
			)
			row.add_child(remove_btn)

			rows.add_child(row)

	add_btn.pressed.connect(func():
		var default_var = ""
		if not variable_names.is_empty():
			default_var = variable_names[0]
		conditions.append({
			"var_id": default_var,
			"op": "==",
			"value": ""
		})
		rebuild_rows.call()
	)

	dialog.confirmed.connect(func():
		print("[DialogueGraphNode] Saving conditions for response %d: %s" % [resp_index, str(conditions)])
		response_conditions[resp_index] = conditions.duplicate(true)
		print("[DialogueGraphNode] response_conditions is now: %s" % str(response_conditions))
		_rebuild_response_ui()
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	rebuild_rows.call()
	dialog.popup_centered()

func get_data() -> Dictionary:
	return {
		"id": node_id,
		"text": dialogue_text,
		"character": character,
		"node_type": node_type,
		"responses": responses,
		"response_conditions": response_conditions,
		"position": [position_offset.x, position_offset.y],
		"event_id": event_id
	}

func set_data(data: Dictionary):
	node_id = data.get("id", node_id)
	name = node_id  # Update node name to match loaded ID
	dialogue_text = data.get("text", "")
	character = data.get("character", "")
	node_type = data.get("node_type", "normal")
	responses = data.get("responses", [])
	response_conditions = data.get("response_conditions", [])
	event_id = data.get("event_id", "")
	
	# Load position from array format
	var pos_data = data.get("position", [0, 0])
	if typeof(pos_data) == TYPE_ARRAY and pos_data.size() >= 2:
		position_offset = Vector2(pos_data[0], pos_data[1])
	else:
		position_offset = Vector2.ZERO
	
	if text_edit:
		text_edit.text = dialogue_text
	
	if event_edit:
		event_edit.text = event_id
	
	if type_dropdown:
		if node_type == "entry":
			type_dropdown.selected = 1
		elif node_type == "exit":
			type_dropdown.selected = 2
		else:
			type_dropdown.selected = 0
	
	# Update node type and rebuild UI
	_on_type_selected(type_dropdown.selected if type_dropdown else 0)
	_rebuild_response_ui()
