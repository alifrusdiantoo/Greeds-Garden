extends Node

var allow_save_game: bool

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		save_game()

func save_game() -> void:
	var save_level_data_component: SaveLevelDataComponent = get_tree().get_first_node_in_group("save_level_data_component")
	
	if save_level_data_component != null:
		save_level_data_component.save_game()

func load_game() -> void:
	await get_tree().process_frame
	
	var save_level_data_component: SaveLevelDataComponent = get_tree().get_first_node_in_group("save_level_data_component")
	
	if save_level_data_component != null:
		save_level_data_component.load_game()

func reset_all_saves() -> void:
	# remove all files under user://game_data/
	var save_dir_path := "user://game_data"
	if DirAccess.dir_exists_absolute(save_dir_path):
		var dir := DirAccess.open(save_dir_path)
		if dir != null:
			dir.list_dir_begin()
			var fname := dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					var fullp := save_dir_path + "/" + fname
					var err := dir.remove(fname)
					if err != OK:
						push_warning("Failed to remove save file: %s (err %s)" % [fullp, str(err)])
					else:
						print("[SaveGameManager] Removed save file:", fullp)
				fname = dir.get_next()
			dir.list_dir_end()
			# optionally remove the dir itself (may fail on some platforms)
			# DirAccess.remove(save_dir_path)  # skip for cross-platform safety
	# remove tribute persist as well (if TributeManager wrote it)
	var tribute_path := "user://tribute.cfg"
	if FileAccess.file_exists(tribute_path):
		var d := DirAccess.open("user://")
		if d != null:
			var name := tribute_path.get_file()
			var err2 := d.remove(name)
			if err2 != OK:
				push_warning("Failed to remove tribute persist file: %s (err %s)" % [tribute_path, str(err2)])
			else:
				print("[SaveGameManager] Removed tribute persist file:", tribute_path)
	print("[SaveGameManager] reset_all_saves() done.")
