# SaveLevelDataComponent.gd
class_name SaveLevelDataComponent
extends Node

var level_scene_name: String
var save_game_data_path: String = "user://game_data/"
var save_file_name: String = "save_%s_game_data.tres"
var game_data_resource: SaveGameDataResource

func _ready() -> void:
	add_to_group("save_level_data_component")
	level_scene_name = get_parent().name

func save_node_data() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("save_data_component")

	# create new game data resource
	game_data_resource = SaveGameDataResource.new()

	# collect from all save_data components
	if nodes.size() > 0:
		for comp in nodes:
			# expect comp to be SaveDataComponent
			if comp == null:
				continue
			if not comp.has_method("collect_save_resources"):
				push_warning("[SaveLevelDataComponent] Node %s does not implement collect_save_resources()" % str(comp.name))
				continue
			var resources: Array = comp.collect_save_resources()
			for r in resources:
				if r == null:
					continue
				# append duplicated final snapshot to game_data_resource
				var final_res: NodeDataResource = r.duplicate(true)
				game_data_resource.add_node_resource(final_res)
				print("[SaveLevelDataComponent] Added resource from node:", comp.name, " type:", final_res)

	# Add TributeManager snapshot once (if autoload present under root)
	var root: Node = get_tree().get_root()
	var tm_node: Node = root.get_node_or_null("TributeManager")
	if tm_node != null:
		# create tribute resource programmatically
		var tnr_script = preload("res://resources/tribute_node_data_resource.gd")
		var tnr: NodeDataResource = tnr_script.new()
		if tm_node.has_method("get_save_dict"):
			tnr.tributes = tm_node.get_save_dict()
		else:
			var maybe_tributes: Variant = tm_node.get("tributes")
			if maybe_tributes != null:
				tnr.tributes = maybe_tributes.duplicate(true)
			else:
				tnr.tributes = {}
		tnr.saved_node_name = "TributeManager_autosave_snapshot"
		game_data_resource.add_node_resource(tnr.duplicate(true))
		print("[SaveLevelDataComponent] Added TributeManager snapshot to save.")
	else:
		print("[SaveLevelDataComponent] TributeManager not found under /root; skipping snapshot.")
		
	# Diagnostic: list all save_data_component nodes and their assigned resources
	print("[DIAG] save_data_component count:", nodes.size())
	for n in nodes:
		var node_name = str(n.name)
		var inv_res = null
		var trib_res = null
		if n.has_method("get"):
			# attempt read fields safely
			if n.has_method("get") and n.get("inventory_resource") != null:
				inv_res = n.get("inventory_resource")
			if n.has_method("get") and n.get("tribute_resource") != null:
				trib_res = n.get("tribute_resource")
		print("[DIAG] Node:", node_name, " inventory_resource:", str(inv_res), " tribute_resource:", str(trib_res))
		if inv_res != null:
			print("    -> inv_res script:", inv_res.get_script(), " resource_path:", inv_res.resource_path)
		if trib_res != null:
			print("    -> trib_res script:", trib_res.get_script(), " resource_path:", trib_res.resource_path)

func save_game() -> void:
	if !DirAccess.dir_exists_absolute(save_game_data_path):
		DirAccess.make_dir_absolute(save_game_data_path)

	var level_save_file_name: String = save_file_name % level_scene_name

	print("[SaveLevelDataComponent] Saving to:", save_game_data_path + level_save_file_name)

	# build game_data_resource
	save_node_data()

	var result: int = ResourceSaver.save(game_data_resource, save_game_data_path + level_save_file_name)
	print("[SaveLevelDataComponent] Save result:", result)

func load_game() -> void:
	var level_save_file_name: String = save_file_name % level_scene_name
	var save_game_path: String = save_game_data_path + level_save_file_name

	print("[SaveLevelDataComponent] Loading game from:", save_game_path)

	if !FileAccess.file_exists(save_game_path):
		print("[SaveLevelDataComponent] Save file not found.")
		return

	game_data_resource = ResourceLoader.load(save_game_path) as SaveGameDataResource

	if game_data_resource == null:
		push_error("[SaveLevelDataComponent] Failed to load save file.")
		return

	var root_node: Window = get_tree().root

	for resource in game_data_resource.save_data_nodes:
		if resource is Resource and resource is NodeDataResource:
			resource._load_data(root_node)

	print("[SaveLevelDataComponent] Load completed.")
