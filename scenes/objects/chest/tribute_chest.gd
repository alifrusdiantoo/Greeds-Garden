# chest_tribute.gd
extends Node2D

var balloon_scene: PackedScene = preload("res://dialogue/game_dialogue_balloon.tscn")

@export var dialogue_start_command: String = "start_tribute_box"

# MULTI-ITEM tribute configuration (set in Inspector)
@export var tribute_items: Array = []        # Array of String item ids, e.g. ["corn","tomato","milk","egg"]
@export var tribute_targets: Array = []      # Array of int targets aligned with tribute_items

# node refs (adjust paths if different)
@onready var interactable_component: Node = $InteractableComponent
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interactable_label_component: Control = $InteractableLabelComponent

@export var tribute_id: String = ""          # unique id (if empty, node name will be used)

var in_range: bool = false
var is_chest_open: bool = false

func _ready() -> void:
	# connect interactable signals
	if interactable_component:
		if interactable_component.has_signal("interactable_activated"):
			interactable_component.interactable_activated.connect(Callable(self, "on_interactable_activated"))
		if interactable_component.has_signal("interactable_deactivated"):
			interactable_component.interactable_deactivated.connect(Callable(self, "on_interactable_deactivated"))
	if interactable_label_component:
		interactable_label_component.hide()

	# set tribute id default if empty
	if tribute_id == "":
		tribute_id = name

	# build items map from arrays (safeguard lengths)
	var items_map: Dictionary = {}
	var count_items: int = int(tribute_items.size())
	for i in range(count_items):
		var item_name: String = String(tribute_items[i])
		var target_val: int = 0
		if i < tribute_targets.size():
			target_val = int(tribute_targets[i])
		else:
			target_val = 1
		if item_name != "":
			items_map[item_name] = max(1, target_val)

	# register with TributeManager (provide current day)
	var current_day: int = 0
	if has_node("/root/DayAndNightCycleManager"):
		current_day = DayAndNightCycleManager.current_day
	if has_node("/root/TributeManager"):
		TributeManager.register_tribute(tribute_id, items_map, current_day)
	else:
		push_warning("TributeManager tidak ditemukan di /root; daftarkan sebagai Autoload (TributeManager).")

func on_interactable_activated() -> void:
	if interactable_label_component:
		interactable_label_component.show()
	in_range = true

func on_interactable_deactivated() -> void:
	if is_chest_open and animated_sprite_2d:
		animated_sprite_2d.play("chest_close")
	is_chest_open = false
	if interactable_label_component:
		interactable_label_component.hide()
	in_range = false
	# clear current tribute when closed
	if has_node("/root/TributeManager"):
		TributeManager.clear_current_tribute()

func _unhandled_input(event: InputEvent) -> void:
	if in_range and event.is_action_pressed("interact"):
		if interactable_label_component:
			interactable_label_component.hide()
		if animated_sprite_2d:
			animated_sprite_2d.play("chest_open")
		is_chest_open = true

		# set current open tribute so dialogue can call generic functions
		if has_node("/root/TributeManager"):
			TributeManager.set_current_tribute(tribute_id)
		else:
			push_warning("TributeManager tidak ditemukan; dialogue tidak akan tahu tribute yang dibuka.")

		# show balloon/dialogue (Game Dialogue plugin handles UI)
		if balloon_scene:
			var balloon: Node = balloon_scene.instantiate()
			get_tree().root.add_child(balloon)
			balloon.emotes_panel.hide()

			if balloon.has_method("start"):
				balloon.start(load("res://dialogue/conversations/chest_tribute.dialogue"), dialogue_start_command)
			else:
				push_warning("Balloon scene missing start() method.")
