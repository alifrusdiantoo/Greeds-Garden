# res://resources/plant_node_data_resource.gd
extends NodeDataResource
class_name PlantNodeDataResource

@export var scene_file_path: String = ""    # optional, may be empty
@export var plant_type: String = ""        # optional type/id of crop
@export var growth_stage: int = 0
@export var growth_progress: float = 0.0
@export var planted_time: float = 0.0
@export var is_harvestable: bool = false
@export var saved_node_name: String = ""

# --- Save ---
func _save_data(node: Node2D) -> void:
	# record node_path/global_position/parent_node_path via base class
	super._save_data(node)

	# attempt to read a possible scene_file_path from node
	if node.has_method("get"):
		var sfp_val: Variant = node.get("scene_file_path")
		if sfp_val != null:
			scene_file_path = String(sfp_val)

	# 1) Try to read from a GrowthCycleComponent child (preferred)
	var gc: Node = null
	if node.has_node("GrowthCycleComponent"):
		gc = node.get_node("GrowthCycleComponent")
	else:
		# search children for something that looks like GrowthCycleComponent (has get_current_growth_state)
		for c in node.get_children():
			if c is Node and (c.has_method("get_current_growth_state") or c.has_method("get_current_state")):
				gc = c
				break

	if gc != null:
		# try method get_current_growth_state()
		var maybe_gs: Variant = null
		if gc.has_method("get_current_growth_state"):
			maybe_gs = gc.call("get_current_growth_state")
		elif gc.has_method("get_current_state"):
			maybe_gs = gc.call("get_current_state")

		if maybe_gs != null:
			growth_stage = int(maybe_gs)

		# try to read is_watered or similar
		var maybe_watered: Variant = null
		if gc.has_method("get"):
			maybe_watered = gc.get("is_watered")
			if maybe_watered != null:
				is_harvestable = bool(maybe_watered)

		# growth_progress
		var maybe_progress: Variant = null
		if gc.has_method("get"):
			maybe_progress = gc.get("growth_progress")
			if maybe_progress != null:
				growth_progress = float(maybe_progress)

		# planted_time
		var maybe_planted: Variant = null
		if gc.has_method("get"):
			maybe_planted = gc.get("planted_time")
			if maybe_planted != null:
				planted_time = float(maybe_planted)

	# 2) If no growth component found, attempt to read properties directly from node
	if gc == null and node.has_method("get"):
		var tmp: Variant = null
		tmp = node.get("growth_stage")
		if tmp != null:
			growth_stage = int(tmp)
		else:
			tmp = node.get("growth_state")
			if tmp != null:
				growth_stage = int(tmp)

		tmp = node.get("growth_progress")
		if tmp != null:
			growth_progress = float(tmp)

		tmp = node.get("planted_time")
		if tmp != null:
			planted_time = float(tmp)

		tmp = node.get("is_harvestable")
		if tmp != null:
			is_harvestable = bool(tmp)

		tmp = node.get("seed_type")
		if tmp != null:
			plant_type = String(tmp)
		else:
			tmp = node.get("crop_type")
			if tmp != null:
				plant_type = String(tmp)

	saved_node_name = node.name
	print("[PlantNodeDataResource] Saved plant:", saved_node_name, " type:", plant_type, " stage:", growth_stage)


# --- Helper to apply saved properties to an instantiated node or existing node ---
func _apply_saved_properties_to_node(target: Node) -> void:
	if target == null:
		return

	# 1) If there's a GrowthCycleComponent child, try to set its internal state
	var gc_target: Node = null
	if target.has_node("GrowthCycleComponent"):
		gc_target = target.get_node("GrowthCycleComponent")
	else:
		for c in target.get_children():
			if c is Node and (c.has_method("set_current_growth_state") or c.has_method("set_state") or c.has_method("set_growth_stage")):
				gc_target = c
				break

	if gc_target != null:
		# try various setter methods
		if gc_target.has_method("set_current_growth_state"):
			gc_target.call("set_current_growth_state", growth_stage)
		elif gc_target.has_method("set_state"):
			gc_target.call("set_state", growth_stage)
		elif gc_target.has_method("set_growth_stage"):
			gc_target.call("set_growth_stage", growth_stage)
		else:
			# try setting property directly
			if gc_target.has_method("set"):
				# set common props defensively
				if gc_target.get("current_state") != null:
					gc_target.set("current_state", growth_stage)
				else:
					gc_target.set("growth_stage", growth_stage)

		# set other optional properties
		if gc_target.has_method("set"):
			if gc_target.get("is_watered") != null:
				gc_target.set("is_watered", is_harvestable)
			gc_target.set("growth_progress", growth_progress)
			gc_target.set("planted_time", planted_time)

	# 2) Update the sprite frame directly so visual state matches immediately
	var sprite_node: Node = null
	if target.has_node("Sprite2D"):
		sprite_node = target.get_node("Sprite2D")
	else:
		for c in target.get_children():
			if c is Sprite2D:
				sprite_node = c
				break

	if sprite_node != null and sprite_node is Sprite2D:
		var offset_val: Variant = null
		if target.has_method("get"):
			offset_val = target.get("start_tomato_frame_offset")
		var offset: int = 0
		if offset_val != null:
			offset = int(offset_val)
		(sprite_node as Sprite2D).frame = growth_stage + offset

	# 3) If no GrowthCycleComponent found, try setting properties on target directly
	if gc_target == null and target.has_method("set"):
		target.set("growth_stage", growth_stage)
		target.set("growth_progress", growth_progress)
		target.set("planted_time", planted_time)
		target.set("is_harvestable", is_harvestable)
		if plant_type != "":
			target.set("seed_type", plant_type)
			target.set("crop_type", plant_type)
		# also update sprite if possible
		if sprite_node != null and sprite_node is Sprite2D:
			(sprite_node as Sprite2D).frame = growth_stage


# --- Load ---
func _load_data(window: Window) -> void:
	# target parent where to add plant instances
	var parent_node: Node = null
	if parent_node_path != null and String(parent_node_path) != "":
		parent_node = window.get_node_or_null(parent_node_path)

	# 1) If scene_file_path is available -> instantiate
	var scene_instance: Node = null
	if scene_file_path != null and String(scene_file_path) != "" and ResourceLoader.exists(scene_file_path):
		var packed: Resource = ResourceLoader.load(scene_file_path)
		if packed != null:
			scene_instance = packed.instantiate()
			if scene_instance is Node2D:
				(scene_instance as Node2D).global_position = global_position
			if parent_node != null:
				parent_node.add_child(scene_instance)
			_apply_saved_properties_to_node(scene_instance)
			print("[PlantNodeDataResource] Restored plant by instancing scene:", saved_node_name)
			return

	# 2) Try to find original node by node_path and duplicate or update it
	if node_path != null and String(node_path) != "":
		var orig: Node = window.get_node_or_null(node_path)
		if orig != null:
			# try to duplicate original node (deep)
			if orig.has_method("duplicate"):
				var dup: Node = orig.duplicate(true)
				if dup != null:
					if dup is Node2D:
						(dup as Node2D).global_position = global_position
					if parent_node != null:
						parent_node.add_child(dup)
					else:
						var p: Node = orig.get_parent()
						if p != null:
							p.add_child(dup)
					_apply_saved_properties_to_node(dup)
					print("[PlantNodeDataResource] Restored plant by duplicating original node:", saved_node_name)
					return
			# fallback: apply properties to existing original node
			_apply_saved_properties_to_node(orig)
			print("[PlantNodeDataResource] Restored plant by updating existing node:", saved_node_name)
			return

	# 3) Could not restore
	push_warning("[PlantNodeDataResource] Could not restore plant for node_path: %s (scene_file_path=%s)" % [str(node_path), str(scene_file_path)])
