@tool
extends Resource
class_name StoryResource

@export var text: String

func _init(p_text: String = ""):
    text = p_text
