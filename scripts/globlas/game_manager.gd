extends Node

var game_menu_screen = preload("res://scenes/ui/game_menu_screen.tscn")

func _ready() -> void:
	var tm = get_tree().get_root().get_node_or_null("TributeManager")
	if tm != null:
		tm.connect("tribute_executed", Callable(self, "_on_tribute_executed"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("game_menu"):
		show_game_menu_screen()

func start_new_game() -> void:
	# optional: clear persisted tribute and level saves
	var sgm = SaveGameManager
	if sgm.has_method("reset_all_saves"):
		sgm.reset_all_saves()
	elif sgm.has_method("reset_persist_file"):
		sgm.reset_persist_file()

	# remove existing main scene if present to avoid leftover Camera2D etc.
	var root = get_tree().get_root()
	var main_scene_node = root.get_node_or_null("MainScene")
	if main_scene_node != null:
		main_scene_node.queue_free()

	# wait one frame so frees actually happen (helps prevent camera zoom issues)
	await get_tree().process_frame

	# load fresh scenes but DO NOT call SaveGameManager.load_game()
	SceneManager.load_main_scene_container()
	SceneManager.load_level("Level1")

	# enable saving for next playthrough
	if has_node("/root/SaveGameManager"):
		SaveGameManager.allow_save_game = true

	# optionally, if you need to set initial gameplay state, do it here
	print("[GameManager] start_new_game() executed: fresh Level1 loaded")



func start_game() -> void:
	SceneManager.load_main_scene_container()
	SceneManager.load_level("Level1")
	SaveGameManager.load_game()
	SaveGameManager.allow_save_game = true
	
func  exit_game() -> void:
	get_tree().quit()
	
func show_game_menu_screen() -> void:
	var game_menu_screen_instance = game_menu_screen.instantiate()
	get_tree().root.add_child(game_menu_screen_instance)

func on_tribute_executed(tribute_id: String) -> void:
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
