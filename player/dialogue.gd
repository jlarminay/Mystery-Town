extends Control

@onready var speaker_label: Label = $SpeakerLabel
@onready var dialogue_label: Label = $DialogueLabel
@onready var response_scroll: ScrollContainer = $ResponseScroll
@onready var response_container: VBoxContainer = $ResponseScroll/ResponseContainer
@onready var continue_button: Button = $ContinueButton

# Cached state for the current conversation
var active_dialogue_node: DialogueNode = null
var current_responses: Array = []
var speaker: Node = null

func _ready() -> void:
  # Connect UI events and start hidden
  continue_button.pressed.connect(_on_continue_pressed)
  hide_dialogue()

func show_dialogue() -> void:
  visible = true

func hide_dialogue() -> void:
  visible = false
  active_dialogue_node = null
  speaker = null
  current_responses.clear()
  _clear_response_buttons()

func set_dialogue(dialogue: String) -> void:
  visible = true
  speaker_label.text = speaker.character_name if speaker != null else "???"
  dialogue_label.text = dialogue

## Begin a dialogue session with a DialogueNode using stateless API
func begin(node: DialogueNode, opts: Dictionary = {}, speaker_ref: Node = null) -> void:
  active_dialogue_node = node
  speaker = speaker_ref  # remember who is talking so we can callback per node
  show_dialogue()
  
  var options = opts.duplicate()
  if not options.has("character"):
    options["character"] = node.character_name
  var entries: Dictionary = node.get_all_entry_points(options)
  if entries.is_empty():
    print("[Dialogue] No entry found for ", options["character"])
    return

  var entry_keys: Array = entries.keys()
  if entry_keys.size() == 1:
    _render_entry(entries[entry_keys[0]])
    return

  # Allow speaker to choose; fallback to first entry
  var chosen: Dictionary = {}
  if speaker and speaker.has_method("choose_dialogue_entry"):
    chosen = speaker.choose_dialogue_entry(entries, options)
  if chosen.is_empty():
    chosen = entries[entry_keys[0]]

  _render_entry(chosen)


func _render_entry(entry: Dictionary) -> void:
  # Update labels and remember node id
  _set_current_node_id(entry.get("node_id", ""))
  set_dialogue(entry.text)
  current_responses = entry.responses
  _clear_response_buttons()
  
  # Resolve event_id (already included on entry; fallback to runtime if missing)
  var event_id: String = entry.get("event_id", "")
  if event_id == "" and active_dialogue_node:
    var rt = active_dialogue_node._get_runtime()
    if rt:
      var node_data = rt.get_dialogue_node(entry.character, entry.get("node_id", ""))
      event_id = node_data.get("event_id", "")
  if speaker and speaker.has_method("on_dialogue_node_entered"):
    # Pass full entry (node_id, character, event_id, text, responses)
    speaker.on_dialogue_node_entered(entry)
  
  if current_responses.size() > 0:
    # Show response buttons
    continue_button.visible = false
    response_scroll.visible = true
    for i in range(current_responses.size()):
      var r = current_responses[i]
      var btn = Button.new()
      btn.text = r.text
      btn.pressed.connect(_on_response_selected.bind(r.index))
      response_container.add_child(btn)
  else:
    # Show continue button for linear dialogue
    response_scroll.visible = false
    continue_button.visible = true

## Select a response by index (stateless next)
func select(index: int) -> void:
  if active_dialogue_node == null:
    return
  var params = {
    "character": active_dialogue_node.character_name,
    "current_node_id": _current_node_id(),
    "response_index": index
  }
  var next = active_dialogue_node.get_next_dialogue(params)
  if next.is_empty():
    print("[Dialogue] End reached.")
    end()
    return
  _render_entry(next)

## Advance linear dialogue (no response)
func advance() -> void:
  if active_dialogue_node == null:
    return
  var params = {
    "character": active_dialogue_node.character_name,
    "current_node_id": _current_node_id()
  }
  var next = active_dialogue_node.get_next_dialogue(params)
  if next.is_empty():
    print("[Dialogue] End reached.")
    end()
    return
  _render_entry(next)

func end() -> void:
  hide_dialogue()
  # Signal parent that dialogue ended naturally
  if get_parent().has_method("_on_dialogue_ended"):
    get_parent()._on_dialogue_ended()

## Track current node id from last render (stored on label metadata)
func _current_node_id() -> String:
  var id = dialogue_label.get_meta("node_id") if dialogue_label.has_meta("node_id") else ""
  return String(id)

func _set_current_node_id(id: String) -> void:
  dialogue_label.set_meta("node_id", id)

func _clear_response_buttons() -> void:
  for child in response_container.get_children():
    child.queue_free()

func _on_response_selected(index: int) -> void:
  # Button callback to pick a response
  select(index)

func _on_continue_pressed() -> void:
  # Button callback to advance linear dialogue
  advance()
