extends Node2D

var balloon_scene = preload("res://dialogue/game_dialogue_balloon.tscn")

var corn_harvest_scene = preload("res://scenes/objects/plants/corn_harvest.tscn")
var tomato_harvest_scene = preload("res://scenes/objects/plants/tomato_harvest.tscn")

@export var dialogue_start_command: String
@export var food_drop_height: int = 40
@export var reward_output_radius: int = 20
@export var output_reward_scenes: Array[PackedScene] = []

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var feed_component: FeedComponent = $FeedComponent
@onready var reward_marker: Marker2D = $RewardMarker
@onready var interactable_label_component: Control = $InteractableLabelComponent

var in_range: bool
var is_chest_open: bool

func _ready() -> void:
	interactable_component.interactable_activated.connect(on_interactable_activated)
	interactable_component.interactable_deactivated.connect(on_interactable_deactivated)
	interactable_label_component.hide()

func on_interactable_activated() -> void:
	interactable_label_component.show()
	in_range = true

func on_interactable_deactivated() -> void:
	if is_chest_open:
		animated_sprite_2d.play("chest_close")
	
	is_chest_open = false
	interactable_label_component.hide()
	in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if in_range:
		if event.is_action_pressed("interact"):
			interactable_label_component.hide()
			animated_sprite_2d.play("chest_open")
			is_chest_open = true
			
			# create some dialogue
			var balloon: BaseGameDialogueBalloon = balloon_scene.instantiate()
			get_tree().current_scene.add_child(balloon)
			balloon.start(load("some dialogue script file here"), dialogue_start_command)
