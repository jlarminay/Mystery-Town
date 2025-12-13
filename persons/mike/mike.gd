extends "../person.gd"

@export var character_name: String = "Mike"

func choose_dialogue_entry(entries: Dictionary, options: Dictionary) -> Dictionary:
  if entries.is_empty():
    return {}

  # entries keyed by event_id (or node_id); use direct lookups when possible
  var met: bool = Investigation.get_value("mike_met")

  if not met and entries.has("first_meeting"):
    return entries["first_meeting"]

  if met and entries.has("second_meeting"):
    return entries["second_meeting"]

  # Fallback: first value in the dictionary
  var first_key = entries.keys()[0]
  return entries[first_key]

func on_dialogue_node_entered(entry: Dictionary) -> void:
  var node_id: String = entry.get("node_id", "")
  var event_id: String = entry.get("event_id", "")

  print("[Mike] Dialogue node entered: %s with event_id: %s" % [node_id, event_id])

  if event_id == "":
    return  # No event to process

  if event_id == "first_meeting":
    print("[Mike] First meeting event triggered on node %s" % node_id)
    Investigation.set_value("mike_met", true)
