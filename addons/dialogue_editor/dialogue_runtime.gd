@tool
extends Node

## ⚠️ WARNING: This is an AUTOLOAD singleton. Do NOT add to scenes manually!
## Configure this in Project Settings > Autoload as /root/DialogueRuntime
## It automatically loads all dialogue data files at game start.
class_name DialogueRuntime

var data: Dictionary = {}
var character_dialogues: Dictionary = {}  # UID -> dialogue data
var character_names: Dictionary = {}  # UID -> name mapping

func _ready():
	# Load dialogue data on startup (works in editor too)
	load_from_file()

func load_from_file(base_dir: String = "res://dialogues/") -> bool:
	if not DirAccess.dir_exists_absolute(base_dir):
		push_warning("[DialogueRuntime] Dialogues directory not found: " + base_dir)
		return false
	
	# Load manifest
	var manifest_path := base_dir + "_manifest.json"
	if not FileAccess.file_exists(manifest_path):
		push_warning("[DialogueRuntime] Manifest file not found: " + manifest_path)
		return false
	
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if manifest_file == null:
		push_error("[DialogueRuntime] Failed to open manifest")
		return false
	var manifest_content := manifest_file.get_as_text()
	manifest_file.close()
	var manifest := JSON.parse_string(manifest_content)
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("[DialogueRuntime] Invalid manifest format")
		return false
	
	# Initialize data structure
	var char_list = manifest.get("characters", [])
	data = {"characters": char_list, "character_dialogues": {}}
	character_dialogues.clear()
	character_names.clear()
	
	# Build UID -> name mapping
	for char_data in char_list:
		var uid = char_data["uid"]
		var name = char_data["name"]
		character_names[uid] = name
	
	# Load each character's dialogue file using UID
	for char_data in char_list:
		var uid: String = char_data["uid"]
		var char_path := base_dir + uid + ".json"
		if not FileAccess.file_exists(char_path):
			push_warning("[DialogueRuntime] Character file not found: " + char_path)
			character_dialogues[uid] = {"nodes": {}, "connections": []}
			continue
		
		var char_file := FileAccess.open(char_path, FileAccess.READ)
		if char_file == null:
			push_error("[DialogueRuntime] Failed to open " + char_path)
			character_dialogues[uid] = {"nodes": {}, "connections": []}
			continue
		var char_content := char_file.get_as_text()
		char_file.close()
		var dialogue_data := JSON.parse_string(char_content)
		if typeof(dialogue_data) != TYPE_DICTIONARY:
			push_error("[DialogueRuntime] Invalid format in " + char_path)
			character_dialogues[uid] = {"nodes": {}, "connections": []}
			continue
		character_dialogues[uid] = dialogue_data
	
	data["character_dialogues"] = character_dialogues
	print("[DialogueRuntime] Loaded %d character dialogue files from %s" % [character_dialogues.size(), base_dir])
	return true

func is_loaded() -> bool:
	return character_dialogues.size() > 0

func get_characters() -> Array:
	return data.get("characters", [])

# Get character name by UID
func get_character_name(uid: String) -> String:
	return character_names.get(uid, "")

# Get character UID by name
func get_character_uid(name: String) -> String:
	for uid in character_names:
		if character_names[uid] == name:
			return uid
	return ""

# Check if character exists by UID or name
func has_character(character: String) -> bool:
	# Try as UID first
	if character_dialogues.has(character):
		return true
	# Try as name
	var uid = get_character_uid(character)
	return uid != "" and character_dialogues.has(uid)

# Get character UID (accepts either UID or name)
func _resolve_character(character: String) -> String:
	if character_dialogues.has(character):
		return character  # Already a UID
	return get_character_uid(character)  # Try to resolve from name

func get_nodes(character: String) -> Dictionary:
	var uid = _resolve_character(character)
	if uid == "" or not character_dialogues.has(uid):
		return {}
	return character_dialogues[uid].get("nodes", {})

func get_connections(character: String) -> Array:
	var uid = _resolve_character(character)
	if uid == "" or not character_dialogues.has(uid):
		return []
	return character_dialogues[uid].get("connections", [])

func get_entry_nodes(character: String) -> Array:
	var nodes := get_nodes(character)
	var entries := []
	for node_id in nodes.keys():
		var n: Dictionary = nodes[node_id]
		if n.get("node_type", "normal") == "entry":
			entries.append(node_id)
	return entries

func get_dialogue_node(character: String, node_id: String) -> Dictionary:
	var nodes := get_nodes(character)
	return nodes.get(node_id, {})

# Load full character dialogue data (for DialogueNode)
func load_character_dialogue(character: String) -> Dictionary:
	var uid = _resolve_character(character)
	if uid == "" or not character_dialogues.has(uid):
		return {}
	return character_dialogues[uid]

func get_node_text(character: String, node_id: String) -> String:
	return get_dialogue_node(character, node_id).get("text", "")

# Returns next node for linear flow (when there are no responses)
func get_next_linear(character: String, node_id: String) -> String:
	var conns := get_connections(character)
	var next := ""
	for c in conns:
		if c.get("from_node", c.get("from", "")) == node_id:
			# Choose the lowest from_port as linear next
			var from_port := int(c.get("from_port", 0))
			if next == "" or from_port < int(get_connections(character)[0].get("from_port", 0)):
				next = c.get("to_node", c.get("to", ""))
	return next

# Returns array of responses: [{ text: String, to_node: String }]
func get_response_targets(character: String, node_id: String) -> Array:
	var node := get_dialogue_node(character, node_id)
	var responses := node.get("responses", [])
	var conns := get_connections(character)
	# Map connections from this node by from_port
	var out_by_port: Dictionary = {}
	for c in conns:
		if c.get("from_node", c.get("from", "")) == node_id:
			out_by_port[int(c.get("from_port", 0))] = c.get("to_node", c.get("to", ""))
	
	var result := []
	# Ports increase with response index; try to match in order
	var ports := out_by_port.keys()
	ports.sort() # ascending
	var port_index := 0
	for i in range(responses.size()):
		var to_node := ""
		if port_index < ports.size():
			to_node = out_by_port[ports[port_index]]
			port_index += 1
		result.append({
			"text": responses[i].get("text", ""),
			"to_node": to_node
		})
	return result

# Convenience: return either linear next or responses depending on node contents
func get_next(character: String, node_id: String) -> Dictionary:
	var node := get_dialogue_node(character, node_id)
	var resp := node.get("responses", [])
	if resp.size() == 0:
		return { "type": "linear", "to_node": get_next_linear(character, node_id) }
	else:
		return { "type": "responses", "options": get_response_targets(character, node_id) }
