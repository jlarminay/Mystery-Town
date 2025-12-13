@tool
extends Panel

@onready var character_list: ItemList = $HSplitContainer/VBoxContainer/CharacterList
@onready var add_button: Button = $HSplitContainer/VBoxContainer/AddButton
@onready var remove_button: Button = $HSplitContainer/VBoxContainer/RemoveButton
@onready var save_button: Button = $HSplitContainer/VBoxContainer/SaveButton
@onready var graph_edit: GraphEdit = $HSplitContainer/GraphEdit

var character_list_data := []  # Array of {uid: String, name: String}
var character_dialogues := {}  # Dictionary of uid -> {nodes: {}, connections: []}
var active_character_uid: String = ""  # Currently selected character UID

func _ready():
  print("[DialogueEditor] _ready() called")
  print("[DialogueEditor] CharacterList node: ", character_list)
  print("[DialogueEditor] CharacterList visible: ", character_list.visible if character_list else "NULL")
  print("[DialogueEditor] CharacterList size: ", character_list.size if character_list else "NULL")
  
  # Connect button signals
  add_button.pressed.connect(_on_add_character)
  remove_button.pressed.connect(_on_remove_character)
  save_button.pressed.connect(_on_save_pressed)
  
  # Enable item editing on the character list
  character_list.item_activated.connect(_on_character_activated)
  character_list.item_selected.connect(_on_character_selected)

  # Auto-load persisted data if available
  load_from_file()

  # Setup graph edit
  if graph_edit:
    graph_edit.connection_request.connect(_on_connection_request)
    graph_edit.disconnection_request.connect(_on_disconnection_request)
    graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
    graph_edit.popup_request.connect(_on_popup_request)
    graph_edit.connection_to_empty.connect(_on_connection_to_empty)
    graph_edit.connection_from_empty.connect(_on_connection_from_empty)
    
    # Enable right-click on connections
    graph_edit.right_disconnects = true
    
    # Add right-click menu to create nodes
    graph_edit.gui_input.connect(_on_graph_input)
  
  print("[DialogueEditor] Signals connected")

func _on_add_character():
  print("[DialogueEditor] Add button pressed!")
  var uid = "char_" + str(Time.get_ticks_msec())
  var name = "Character_%d" % (character_list_data.size() + 1)
  
  var char_data = {"uid": uid, "name": name}
  character_list_data.append(char_data)
  character_list.add_item(name)
  
  print("[DialogueEditor] Added character: ", name, " (UID: ", uid, ")")
  print("[DialogueEditor] CharacterList item count: ", character_list.item_count)
  
  # Select the newly added item
  character_list.select(character_list.item_count - 1)
  
  # Initialize dialogue data for this character
  character_dialogues[uid] = {"nodes": {}, "connections": []}
  
  active_character_uid = uid
  _load_character_graph()
  
  # Auto-save after change
  save_to_file()

func _on_remove_character():
  print("[DialogueEditor] Remove button pressed!")
  var selected = character_list.get_selected_items()
  if selected.size() == 0:
    print("[DialogueEditor] No character selected")
    return
  var index = selected[0]
  var char_data = character_list_data[index]
  var uid = char_data["uid"]
  
  # Remove character's dialogue data (file will be deleted on save)
  if character_dialogues.has(uid):
    character_dialogues.erase(uid)
  
  character_list_data.remove_at(index)
  character_list.remove_item(index)
  print("[DialogueEditor] Removed character: ", char_data["name"], " (UID: ", uid, ")")
  
  # Auto-save after change (cleanup happens here)
  save_to_file()

func _on_save_pressed():
  print("[DialogueEditor] Manual save triggered")
  if active_character_uid != "":
    _save_character_graph()
  save_to_file()
  print("[DialogueEditor] Save complete!")

func _on_character_activated(index: int):
  print("[DialogueEditor] Character activated at index: ", index)
  # Show a dialog to rename the character
  var dialog = AcceptDialog.new()
  dialog.title = "Rename Character"
  dialog.dialog_hide_on_ok = false
  
  var vbox = VBoxContainer.new()
  var label = Label.new()
  label.text = "Enter new name:"
  vbox.add_child(label)
  
  var line_edit = LineEdit.new()
  line_edit.text = character_list_data[index]["name"]
  line_edit.custom_minimum_size = Vector2(200, 0)
  vbox.add_child(line_edit)
  
  dialog.add_child(vbox)
  dialog.confirmed.connect(func():
    var new_name = line_edit.text.strip_edges()
    if new_name != "" and new_name != character_list_data[index]["name"]:
      character_list_data[index]["name"] = new_name
      character_list.set_item_text(index, new_name)
      print("[DialogueEditor] Renamed character to: ", new_name)
      # Auto-save after rename
      save_to_file()
    dialog.queue_free()
  )
  dialog.canceled.connect(func():
    dialog.queue_free()
  )
  
  add_child(dialog)
  dialog.popup_centered()
  line_edit.grab_focus()
  line_edit.select_all()

func _on_character_selected(index: int):
  if index >= 0 and index < character_list_data.size():
    var new_uid = character_list_data[index]["uid"]
    if new_uid != active_character_uid:
      # Save current character's graph
      if active_character_uid != "":
        _save_character_graph()
        # Auto-save on character switch
        save_to_file()
      
      active_character_uid = new_uid
      print("[DialogueEditor] Switched to character: ", character_list_data[index]["name"], " (UID: ", new_uid, ")")
      
      # Load new character's graph
      _load_character_graph()

func _save_character_graph():
  if active_character_uid == "":
    return
  
  if not character_dialogues.has(active_character_uid):
    character_dialogues[active_character_uid] = {"nodes": {}, "connections": []}
  
  # Save all nodes for this character
  var char_data = character_dialogues[active_character_uid]
  char_data["nodes"] = {}
  
  for child in graph_edit.get_children():
    if child is DialogueGraphNode:
      var node_data = child.get_data()
      char_data["nodes"][child.node_id] = node_data
  
  # Save connections
  char_data["connections"] = graph_edit.get_connection_list()
  
  print("[DialogueEditor] Saved %d nodes for UID %s" % [char_data["nodes"].size(), active_character_uid])

func _load_character_graph():
  # Clear current graph
  _clear_graph()
  
  if active_character_uid == "":
    return
  
  # Initialize if needed
  if not character_dialogues.has(active_character_uid):
    character_dialogues[active_character_uid] = {"nodes": {}, "connections": []}
    return
  
  # Get character name for display
  var char_name = _get_character_name_by_uid(active_character_uid)
  
  var char_data = character_dialogues[active_character_uid]
  
  # Load nodes
  for node_id in char_data["nodes"]:
    var node_data = char_data["nodes"][node_id]
    var node = DialogueGraphNode.new()
    node.setup(char_name)
    node.set_data(node_data)
    graph_edit.add_child(node)
  
  # Wait for nodes to be added to scene tree before connecting
  await get_tree().process_frame
  
  # Load connections
  for conn in char_data["connections"]:
    graph_edit.connect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
  
  print("[DialogueEditor] Loaded %d nodes for UID %s" % [char_data["nodes"].size(), active_character_uid])

func _get_character_name_by_uid(uid: String) -> String:
  for char_data in character_list_data:
    if char_data["uid"] == uid:
      return char_data["name"]
  return "Unknown"

func _clear_graph():
  # Remove all nodes from graph
  for child in graph_edit.get_children():
    if child is DialogueGraphNode:
      child.queue_free()
  
  # Clear all connections
  graph_edit.clear_connections()

# Graph editing functions
func _on_graph_input(event: InputEvent):
  if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
    # Right-click to add new dialogue node
    _create_dialogue_node(graph_edit.get_local_mouse_position())

func _create_dialogue_node(at_position: Vector2):
  if character_list_data.size() == 0:
    print("[DialogueEditor] No characters available. Add a character first.")
    return
  
  if active_character_uid == "":
    print("[DialogueEditor] No character selected. Select a character first.")
    return
  
  var char_name = _get_character_name_by_uid(active_character_uid)
  
  var node = DialogueGraphNode.new()
  node.setup(char_name)
  node.position_offset = (at_position + graph_edit.scroll_offset) / graph_edit.zoom
  graph_edit.add_child(node)
  
  print("[DialogueEditor] Created dialogue node for %s: %s" % [char_name, node.node_id])
  
  # Auto-save after node creation
  _save_character_graph()
  save_to_file()

func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int):
  graph_edit.connect_node(from_node, from_port, to_node, to_port)
  print("[DialogueEditor] Connected: %s:%d -> %s:%d" % [from_node, from_port, to_node, to_port])
  
  # Auto-save after connection change
  _save_character_graph()
  save_to_file()

func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int):
  graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
  print("[DialogueEditor] Disconnected: %s:%d -> %s:%d" % [from_node, from_port, to_node, to_port])
  
  # Auto-save after connection change
  _save_character_graph()
  save_to_file()

func _on_delete_nodes_request(nodes: Array):
  for node_name in nodes:
    for child in graph_edit.get_children():
      if child is DialogueGraphNode and child.name == node_name:
        print("[DialogueEditor] Deleted node: ", child.node_id)
        child.queue_free()
        break
  
  # Auto-save after node deletion
  _save_character_graph()
  save_to_file()

func _on_popup_request(position: Vector2):
  # Show context menu at position (for future enhancements)
  pass

func _on_connection_to_empty(from_node: String, from_port: int, release_position: Vector2):
  # User dragged from a port and released on empty space (for future enhancements)
  pass

func _on_connection_from_empty(to_node: String, to_port: int, release_position: Vector2):
  # User dragged to a port from empty space (for future enhancements)
  pass

func get_dialogue_data() -> Dictionary:
  # Save current character's graph first
  if active_character_uid != "":
    _save_character_graph()
  
  return {
    "characters": character_list_data,
    "character_dialogues": character_dialogues
  }

func save_to_file(base_dir: String = "res://dialogues/") -> bool:
  # Save current character's graph first
  if active_character_uid != "":
    _save_character_graph()
  
  # Ensure directory exists
  if not DirAccess.dir_exists_absolute(base_dir):
    var err = DirAccess.make_dir_recursive_absolute(base_dir)
    if err != OK:
      push_error("[DialogueEditor] Failed to create directory: " + base_dir)
      return false
  
  # Build set of valid UIDs from manifest
  var valid_uids: Dictionary = {}
  for char_data in character_list_data:
    valid_uids[char_data["uid"]] = true
  
  # Clean up orphaned JSON files that don't match any character in manifest
  var dir := DirAccess.open(base_dir)
  if dir:
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
      if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "_manifest.json":
        # Extract UID from filename (remove .json extension)
        var uid := file_name.substr(0, file_name.length() - 5)
        if not valid_uids.has(uid):
          var orphan_path := base_dir + file_name
          print("[DialogueEditor] Deleting orphaned file: ", orphan_path)
          var err := DirAccess.remove_absolute(orphan_path)
          if err != OK:
            push_warning("[DialogueEditor] Failed to delete %s (error %d)" % [orphan_path, err])
          else:
            print("[DialogueEditor] Successfully deleted ", orphan_path)
      file_name = dir.get_next()
    dir.list_dir_end()
  else:
    push_warning("[DialogueEditor] Could not open directory for cleanup: ", base_dir)
  
  # Save character manifest with UID/name mappings
  var manifest := {
    "characters": character_list_data
  }
  var manifest_json := JSON.stringify(manifest, "\t")
  var manifest_file := FileAccess.open(base_dir + "_manifest.json", FileAccess.WRITE)
  if manifest_file == null:
    push_error("[DialogueEditor] Failed to write manifest")
    return false
  manifest_file.store_string(manifest_json)
  manifest_file.close()
  
  # Save each character's dialogue to separate file using UID
  for uid in character_dialogues:
    var char_data: Dictionary = character_dialogues[uid]
    var char_json := JSON.stringify(char_data, "\t")
    var char_path :String = base_dir + uid + ".json"
    var char_file := FileAccess.open(char_path, FileAccess.WRITE)
    if char_file == null:
      push_error("[DialogueEditor] Failed to write " + char_path)
      continue
    char_file.store_string(char_json)
    char_file.close()
  
  print("[DialogueEditor] Saved %d character dialogue files to %s" % [character_dialogues.size(), base_dir])
  return true

func load_dialogue_data(data: Dictionary):
  # Clear everything
  _clear_graph()
  character_dialogues.clear()
  active_character_uid = ""
  
  # Load characters
  character_list_data = data.get("characters", [])
  character_list.clear()
  for char_data in character_list_data:
    character_list.add_item(char_data["name"])
  
  # Load character dialogue data
  character_dialogues = data.get("character_dialogues", {})
  
  # If there are characters, select the first one
  if character_list_data.size() > 0:
    character_list.select(0)
    active_character_uid = character_list_data[0]["uid"]
    _load_character_graph()

func load_from_file(base_dir: String = "res://dialogues/") -> bool:
  if not DirAccess.dir_exists_absolute(base_dir):
    push_warning("[DialogueEditor] Dialogues directory not found: " + base_dir)
    return false
  
  # Load manifest
  var manifest_path := base_dir + "_manifest.json"
  if not FileAccess.file_exists(manifest_path):
    push_warning("[DialogueEditor] Manifest file not found: " + manifest_path)
    return false
  
  var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
  if manifest_file == null:
    push_error("[DialogueEditor] Failed to open manifest")
    return false
  var manifest_content := manifest_file.get_as_text()
  manifest_file.close()
  var manifest := JSON.parse_string(manifest_content)
  if typeof(manifest) != TYPE_DICTIONARY:
    push_error("[DialogueEditor] Invalid manifest format")
    return false
  
  # Clear everything
  _clear_graph()
  character_dialogues.clear()
  active_character_uid = ""
  
  # Load character list with UID mappings
  character_list_data = manifest.get("characters", [])
  character_list.clear()
  for char_data in character_list_data:
    character_list.add_item(char_data["name"])
  
  # Load each character's dialogue file using UID
  for char_data in character_list_data:
    var uid: String = char_data["uid"]
    var char_path: String = base_dir + uid + ".json"
    if not FileAccess.file_exists(char_path):
      push_warning("[DialogueEditor] Character file not found: " + char_path)
      character_dialogues[uid] = {"nodes": {}, "connections": []}
      continue
    
    var char_file := FileAccess.open(char_path, FileAccess.READ)
    if char_file == null:
      push_error("[DialogueEditor] Failed to open " + char_path)
      character_dialogues[uid] = {"nodes": {}, "connections": []}
      continue
    var char_content := char_file.get_as_text()
    char_file.close()
    var dialogue_data := JSON.parse_string(char_content)
    if typeof(dialogue_data) != TYPE_DICTIONARY:
      push_error("[DialogueEditor] Invalid format in " + char_path)
      character_dialogues[uid] = {"nodes": {}, "connections": []}
      continue
    character_dialogues[uid] = dialogue_data
  
  # If there are characters, select the first one
  if character_list_data.size() > 0:
    character_list.select(0)
    active_character_uid = character_list_data[0]["uid"]
    _load_character_graph()
  
  print("[DialogueEditor] Loaded %d character dialogue files from %s" % [character_dialogues.size(), base_dir])
  return true
