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
	# collect nodes
	var nodes: Array = get_tree().get_nodes_in_group("save_data_component")

	# create new game data resource
	game_data_resource = SaveGameDataResource.new()

	# --- 1) Add GameTime snapshot FIRST (so it's loaded first later) ---
	var root_node: Node = get_tree().get_root()
	var dn_node: Node = root_node.get_node_or_null("DayAndNightCycleManager")
	if dn_node != null:
		var time_script := preload("res://resources/game_time_node_data_resource.gd")
		var time_res := time_script.new() as NodeDataResource
		# pick a Node2D context: prefer parent of this component
		var context_node: Node2D = null
		if get_parent() != null and get_parent() is Node2D:
			context_node = get_parent() as Node2D
		else:
			# fallback to root child if available
			if root_node.get_child_count() > 0 and root_node.get_child(0) is Node2D:
				context_node = root_node.get_child(0) as Node2D
		if context_node != null:
			time_res._save_data(context_node)
		else:
			# still attempt using a null-safe call by creating but not populating
			push_warning("[SaveLevelDataComponent] No Node2D context found for GameTime snapshot; snapshot may be empty.")
		# insert at index 0 to prioritize loading
		game_data_resource.save_data_nodes.insert(0, time_res.duplicate(true))
		print("[SaveLevelDataComponent] Added GameTime snapshot to save.")
	else:
		print("[SaveLevelDataComponent] DayAndNightCycleManager not found; skipping time snapshot.")

	# --- 2) Collect resources from SaveDataComponents ---
	if nodes.size() > 0:
		for comp in nodes:
			if comp == null:
				continue
			if not comp.has_method("collect_save_resources"):
				push_warning("[SaveLevelDataComponent] Node %s missing collect_save_resources()" % str(comp.name))
				continue
			var resources: Array = comp.collect_save_resources()
			if resources == null:
				continue
			for r in resources:
				if r == null:
					continue
				var final_res: NodeDataResource = r.duplicate(true)
				game_data_resource.add_node_resource(final_res)
				print("[SaveLevelDataComponent] Added resource from node:", comp.name, " type:", str(final_res.get_class()))

	# --- 3) Add TributeManager snapshot once (if autoload present under root) ---
	var tm_node: Node = root_node.get_node_or_null("TributeManager")
	if tm_node != null:
		var tnr_script := preload("res://resources/tribute_node_data_resource.gd")
		var tnr := tnr_script.new() as NodeDataResource
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

	# --- Diagnostic: list what will be saved ---
	print("[DIAG] save_data_component count:", nodes.size())
	for n in nodes:
		var node_name := str(n.name)
		var inv_res = null
		var trib_res = null
		if n.has_method("get"):
			if n.has_method("get") and n.get("inventory_resource") != null:
				inv_res = n.get("inventory_resource")
			if n.has_method("get") and n.get("tribute_resource") != null:
				trib_res = n.get("tribute_resource")
		print("[DIAG] Node:", node_name, " inventory_resource:", str(inv_res), " tribute_resource:", str(trib_res))
		if inv_res != null:
			print("    -> inv_res script:", str(inv_res.get_script()), " resource_path:", str(inv_res.resource_path))
		if trib_res != null:
			print("    -> trib_res script:", str(trib_res.get_script()), " resource_path:", str(trib_res.resource_path))

	# End save_node_data

func save_game() -> void:
	# ensure folder
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

	# 1) FIRST load GameTime resources so DayAndNightCycleManager state restored early
	for resource in game_data_resource.save_data_nodes:
		if resource is Resource and resource is GameTimeNodeDataResource:
			resource._load_data(root_node)

	# 2) THEN load all other resources (inventory, tribute, tilemap, scene, etc.)
	for resource in game_data_resource.save_data_nodes:
		if resource is Resource and resource is NodeDataResource and not (resource is GameTimeNodeDataResource):
			resource._load_data(root_node)

	print("[SaveLevelDataComponent] Load completed.")
