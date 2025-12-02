extends Node2D

var balloon_scene = preload("res://dialogue/game_dialogue_balloon.tscn")

@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var interactable_label_component: Control = $InteractableLabelComponent

var in_range: bool
var tools_panel: Node = null

func _ready() -> void:
	tools_panel = _get_tools_panel()
	interactable_component.interactable_activated.connect(on_interactable_activated)
	interactable_component.interactable_deactivated.connect(on_interactable_deactivated)
	interactable_label_component.hide()
	
	GameDialogueManager.give_crops_seeds.connect(on_give_crop_seeds)

func on_interactable_activated() -> void:
	interactable_label_component.show()
	in_range = true

func on_interactable_deactivated() -> void:
	interactable_label_component.hide()
	in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if in_range and event.is_action_pressed("interact"):
		var balloon = balloon_scene.instantiate()
		get_tree().root.add_child(balloon)

		if tools_panel == null:
			tools_panel = _get_tools_panel()

		if tools_panel and tools_panel.is_tool_enabled(DataTypes.Tools.TillGround):
			balloon.start(load("res://dialogue/conversations/guide.dialogue"), "continue")
		else:
			balloon.start(load("res://dialogue/conversations/guide.dialogue"), "start")
			

func on_give_crop_seeds() -> void:
	ToolManager.enable_tool_button(DataTypes.Tools.TillGround)
	ToolManager.enable_tool_button(DataTypes.Tools.WaterCrops)
	ToolManager.enable_tool_button(DataTypes.Tools.PlantCorn)
	ToolManager.enable_tool_button(DataTypes.Tools.PlantTomato)

func _get_tools_panel():
	var panels = get_tree().get_nodes_in_group("ToolsPanel")
	return panels[0] if panels.size() > 0 else null
