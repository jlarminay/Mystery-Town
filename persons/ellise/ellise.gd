extends "../person.gd"

@export var character_name: String = "Ellise"

func choose_dialogue_entry(entries: Dictionary, options: Dictionary) -> Dictionary:
  if entries.is_empty():
    return {}

  # Fallback: first value in the dictionary
  var first_key = entries.keys()[0]
  return entries[first_key]

func on_dialogue_node_entered(entry: Dictionary) -> void:
  var node_id: String = entry.get("node_id", "")
  var event_id: String = entry.get("event_id", "")

  print("[Ellise] Dialogue node entered: %s with event_id: %s" % [node_id, event_id])

  if event_id == "":
    return  # No event to process

  if event_id == "first_meeting":
    print("[Ellise] First meeting event triggered on node %s" % node_id)
    Investigation.set_value("ellise_met", true)
