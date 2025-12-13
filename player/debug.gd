extends Control

@onready var knowledge:Label = $Knowledge

func _process(_delta: float) -> void:
  knowledge.text = ''
  var text : String = ''

  if Investigation.get_value('mike_met'):
    text += "- You have met Mike.\n"
  if Investigation.get_value('ellise_met'):
    text += "- You have met Ellise.\n"
  if Investigation.get_value('bobby_met'):
    text += "- You have met Bobby.\n"
  if Investigation.get_value('dog_met'):
    text += "- You have met Dog.\n"

  knowledge.text = text
