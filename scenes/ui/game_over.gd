extends CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# prefer action map
		if Input.is_action_just_pressed("ui_accept") or event.keycode == KEY_SPACE:
			var gm = get_tree().get_root().get_node_or_null("GameManager")
			if gm != null and gm.has_method("start_new_game"):
				gm.call_deferred("start_new_game")
			else:
				# fallback: go to menu or reload level directly
				get_tree().change_scene_to_file("res://scenes/ui/game_menu_screen.tscn")
			# free this game over layer if it's a separate node instance
			queue_free()
