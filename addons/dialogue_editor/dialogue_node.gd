@tool
extends Node
class_name DialogueNode

## Minimal, stateless dialogue helper.
## Provide character_name via inspector dropdown (reads dialogues/_manifest.json).
var character_name: String = ""

## Optional: Set this to a callable that takes (var_id, op, value) and returns bool
## This allows custom validation beyond simple variable checks
var custom_condition_validator: Callable

## Optional: Set this to a callable that takes (response_index, response_data) and returns bool
## This allows dynamic response visibility based on your game state
var response_visibility_callback: Callable

func _get_runtime() -> Node:
  # Support multiple autoload names to avoid name collision issues
  var rt = get_node_or_null("/root/DialogueRuntime")
  if rt:
    return rt
  # Fallback to alternative name if autoload was registered differently
  rt = get_node_or_null("/root/DialogueRuntimeSingleton")
  if rt:
    return rt
  push_error("DialogueRuntime singleton not found! Add Autoload as 'DialogueRuntime' or 'DialogueRuntimeSingleton'.")
  return null

func _get_property_list() -> Array:
  var properties = []
  
  # Try to load manifest directly to get character list
  var manifest_path = "res://dialogues/_manifest.json"
  var hint_string = ""
  
  if FileAccess.file_exists(manifest_path):
    var manifest_file = FileAccess.open(manifest_path, FileAccess.READ)
    if manifest_file:
      var manifest_content = manifest_file.get_as_text()
      manifest_file.close()
      var manifest = JSON.parse_string(manifest_content)
      if typeof(manifest) == TYPE_DICTIONARY:
        var characters = manifest.get("characters", [])
        for char_data in characters:
          if hint_string != "":
            hint_string += ","
          hint_string += char_data.get("name", "")
  
  if hint_string != "":
    properties.append({
      "name": "character_name",
      "type": TYPE_STRING,
      "usage": PROPERTY_USAGE_DEFAULT,
      "hint": PROPERTY_HINT_ENUM,
      "hint_string": hint_string
    })
  else:
    # No characters available, show as regular string
    properties.append({
      "name": "character_name",
      "type": TYPE_STRING,
      "usage": PROPERTY_USAGE_DEFAULT
    })
  
  return properties



## Stateless API: Get all entry points given optional event filter and external state
## Returns a dictionary keyed by event_id (or node_id if missing) with values:
## { node_id, character, event_id, text, responses }, responses are { index, text, data }
func get_all_entry_points(options: Dictionary = {}) -> Dictionary:
  var char = options.get("character", character_name)
  if char == "":
    push_error("No character selected!")
    return {}
  var rt = _get_runtime()
  if not rt:
    return {}
  var data = rt.load_character_dialogue(char)
  if data.is_empty():
    push_error("Failed to load dialogue for character: " + char)
    return {}

  var event_filter: String = options.get("event_id", "")
  var entries: Dictionary = {}

  for node_id in data.get("nodes", {}).keys():
    var node = data["nodes"][node_id]
    if node.get("node_type") != "entry":
      continue
    if event_filter != "" and node.get("event_id", "") != event_filter:
      continue
    var responses = _collect_available_responses(node)
    var key = node.get("event_id", "")
    if key == "":
      key = node_id
    elif entries.has(key):
      # Avoid collisions when multiple entries share the same event_id
      key = "%s_%s" % [key, node_id]
    entries[key] = {
      "node_id": node_id,
      "character": char,
      "event_id": node.get("event_id", ""),
      "text": node.get("text", ""),
      "responses": responses
    }

  return entries

## Process the current node (apply effects, show dialogue, etc.)
## Stateless API: Get next dialogue given current node and optional response index
## Inputs: { character, current_node_id, response_index: int | null }
## Returns: same shape as get_entry_point; empty dict means end or invalid
func get_next_dialogue(params: Dictionary) -> Dictionary:
  var char = params.get("character", character_name)
  if char == "":
    return {}
  var rt = _get_runtime()
  if not rt:
    return {}
  var data = rt.load_character_dialogue(char)
  if data.is_empty():
    return {}
  var curr_id: String = params.get("current_node_id", "")
  if curr_id == "":
    return {}
  var resp_index = params.get("response_index", null)
  var connections = data.get("connections", [])
  var target_port = (resp_index if typeof(resp_index) != TYPE_NIL and int(resp_index) >= 0 else 0)
  var next_id = ""
  for conn in connections:
    if conn.get("from_node", "") == curr_id and int(conn.get("from_port", 0)) == target_port:
      next_id = conn.get("to_node", "")
      break
  if next_id == "":
    return {}
  var node = data.get("nodes", {}).get(next_id, {})
  if node.is_empty():
    return {}
  var responses = _collect_available_responses(node)
  return {
    "node_id": next_id,
    "character": char,
    "event_id": node.get("event_id", ""),
    "text": node.get("text", ""),
    "responses": responses
  }


## Helper: Collect available responses for a node (stateless)
func _collect_available_responses(node_data: Dictionary) -> Array:
  var responses = node_data.get("responses", [])
  var response_conditions = node_data.get("response_conditions", [])
  var out = []
  for i in responses.size():
    var response = responses[i]
    var response_text = response.get("text", "")
    print("[DialogueNode] Checking response [%d]: '%s'" % [i, response_text])
    
    if response_visibility_callback.is_valid():
      var visible = response_visibility_callback.call(i, response)
      print("  - visibility_callback returned: %s" % visible)
      if not visible:
        print("  - Response hidden by callback")
        continue
    
    var conditions = response_conditions[i] if i < response_conditions.size() else []
    print("  - Found %d condition(s)" % conditions.size())
    if conditions.size() > 0:
      for cond in conditions:
        print("    - Raw condition: %s" % str(cond))
    var conditions_met = _check_conditions(conditions, response_text)
    
    if conditions_met:
      print("  - Response AVAILABLE")
      out.append({
        "index": i,
        "text": response_text,
        "data": response
      })
    else:
      print("  - Response HIDDEN (conditions not met)")
  return out

## Check if conditions are met
func _check_conditions(conditions: Array, response_text: String = "") -> bool:
  if conditions.is_empty():
    return true
  
  # Use custom_condition_validator if provided
  if custom_condition_validator.is_valid():
    for cond in conditions:
      var var_id = cond.get("var_id", "")
      var op = cond.get("op", "==")
      var expected_value = cond.get("value", "")
      var result = custom_condition_validator.call(var_id, op, expected_value)
      print("    - Condition: %s %s %s = %s" % [var_id, op, expected_value, result])
      if not result:
        return false
    return true
  
  # Default: use Investigation singleton
  var investigation = get_node_or_null("/root/Investigation")
  if not investigation:
    push_warning("[DialogueNode] No custom_condition_validator and Investigation singleton not found!")
    return true  # Fail open
  
  for cond in conditions:
    var var_id = cond.get("var_id", "")
    var op = cond.get("op", "==")
    var expected_value = cond.get("value", "")
    
    var current_value = investigation.get_value(var_id)
    if current_value == null:
      print("    - Condition: %s not found in Investigation = false" % var_id)
      return false
    
    # Convert string "true"/"false" to boolean if needed
    var expected = expected_value
    if expected_value == "true":
      expected = true
    elif expected_value == "false":
      expected = false
    
    var result = _compare_values(current_value, op, expected)
    print("    - Condition: %s (=%s) %s %s = %s" % [var_id, str(current_value), op, str(expected), result])
    if not result:
      return false
  
  return true

## Compare values based on operator
func _compare_values(current, op: String, expected) -> bool:
  # Try numeric comparison first
  if str(current).is_valid_float() and str(expected).is_valid_float():
    var curr_num = float(str(current))
    var exp_num = float(str(expected))
    match op:
      "==": return curr_num == exp_num
      "!=": return curr_num != exp_num
      ">=": return curr_num >= exp_num
      "<=": return curr_num <= exp_num
      ">": return curr_num > exp_num
      "<": return curr_num < exp_num
  
  # String comparison
  var curr_str = str(current)
  var exp_str = str(expected)
  match op:
    "==": return curr_str == exp_str
    "!=": return curr_str != exp_str
    ">=": return curr_str >= exp_str
    "<=": return curr_str <= exp_str
    ">": return curr_str > exp_str
    "<": return curr_str < exp_str
  
  return false

## Select a response by index
## Find the next connected node (utility for get_next_dialogue if needed elsewhere)
func _find_connected_node(from_node: String, response_index: int, connections: Array) -> String:
  var target_port = response_index if response_index >= 0 else 0
  for conn in connections:
    if conn[0] == from_node and conn[1] == target_port:
      return conn[2]
  return ""
