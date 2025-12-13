extends Node

# Central state dictionary so you don't have to update helper lists
var state := {
  "bobby_met": false,
  "dog_met": false,
	"mike_met": false,
  "mike_borrowed_money": false,
  "mike_hates_similar_name": false,
  "dave_met": false,
  "dave_skipped_promotion": false,
  "dave_hates_jokes": false,
  "ellise_met": false,
  "ellise_insurance_money": false,
  "ellise_hates_snoring": false,
}

# Return variable names for tools like the dialogue editor
func list_variables() -> Array:
	return state.keys()

# Return values as a dictionary
func get_variables() -> Dictionary:
	return state

# Optional helpers if you want external code to get/set by key
func get_value(key: String):
	return state.get(key, null)

func set_value(key: String, value) -> void:
	state[key] = value