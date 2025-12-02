# res://resources/plant_node_data_resource.gd
extends NodeDataResource
class_name PlantNodeDataResource

@export var scene_file_path: String = ""
@export var plant_type: String = ""
@export var growth_stage: int = 0
@export var growth_progress: float = 0.0
@export var planted_time: float = 0.0
@export var is_harvestable: bool = false
@export var saved_node_name: String = ""

# NEW: save the starting_day used by GrowthCycleComponent so progression persists
@export var saved_starting_day: int = 0
@export var saved_is_watered: bool = false

# --- Save ---
func _save_data(node: Node2D) -> void:
	# base saves node_path/global_position/parent_node_path
	super._save_data(node)

	# try to capture scene_file_path if node exposes it
	if node.has_method("get"):
		var sfp_val: Variant = node.get("scene_file_path")
		if sfp_val != null:
			scene_file_path = String(sfp_val)

	# find GrowthCycleComponent (preferred)
	var gc: Node = null
	if node.has_node("GrowthCycleComponent"):
		gc = node.get_node("GrowthCycleComponent")
	else:
		for c in node.get_children():
			if c is Node and (c.has_method("get_current_growth_state") or c.has_method("get_current_state") or c.has_method("get_growth_progress") or c.has_method("get_progress") or c.has_method("get_elapsed_time")):
				gc = c
				break

	# If growth component found, read relevant fields
	if gc != null:
		# current growth state
		var maybe_stage: Variant = null
		if gc.has_method("get_current_growth_state"):
			maybe_stage = gc.call("get_current_growth_state")
		elif gc.has_method("get_current_state"):
			maybe_stage = gc.call("get_current_state")
		elif gc.has_method("get"):
			maybe_stage = gc.get("current_growth_state") if gc.get("current_growth_state") != null else gc.get("current_state")
		if maybe_stage != null:
			growth_stage = int(maybe_stage)

		# saved_starting_day
		var maybe_start: Variant = null
		if gc.has_method("get") and gc.get("starting_day") != null:
			maybe_start = gc.get("starting_day")
		elif gc.has_method("get_starting_day"):
			maybe_start = gc.call("get_starting_day")
		if maybe_start != null:
			saved_starting_day = int(maybe_start)
		else:
			saved_starting_day = 0

		# is_watered
		var maybe_water: Variant = null
		if gc.has_method("get") and gc.get("is_watered") != null:
			maybe_water = gc.get("is_watered")
		elif gc.has_method("is_watered"):
			maybe_water = gc.call("is_watered")
		if maybe_water != null:
			saved_is_watered = bool(maybe_water)
			is_harvestable = saved_is_watered

		# growth_progress (if any)
		var maybe_prog: Variant = null
		if gc.has_method("get_growth_progress"):
			maybe_prog = gc.call("get_growth_progress")
		elif gc.has_method("get_progress"):
			maybe_prog = gc.call("get_progress")
		elif gc.has_method("get") and gc.get("growth_progress") != null:
			maybe_prog = gc.get("growth_progress")
		if maybe_prog != null:
			growth_progress = float(maybe_prog)

		# planted_time (if any)
		var maybe_planted: Variant = null
		if gc.has_method("get") and gc.get("planted_time") != null:
			maybe_planted = gc.get("planted_time")
		elif gc.has_method("get_planted_time"):
			maybe_planted = gc.call("get_planted_time")
		if maybe_planted != null:
			planted_time = float(maybe_planted)
	else:
		# fallback: read some properties directly from plant node
		if node.has_method("get"):
			var tmp: Variant = null
			tmp = node.get("growth_stage")
			if tmp != null:
				growth_stage = int(tmp)
			tmp = node.get("growth_progress")
			if tmp != null:
				growth_progress = float(tmp)
			tmp = node.get("planted_time")
			if tmp != null:
				planted_time = float(tmp)
			tmp = node.get("is_watered")
			if tmp != null:
				saved_is_watered = bool(tmp)
				is_harvestable = saved_is_watered
			tmp = node.get("starting_day")
			if tmp != null:
				saved_starting_day = int(tmp)
			tmp = node.get("seed_type")
			if tmp != null:
				plant_type = String(tmp)
			else:
				tmp = node.get("crop_type")
				if tmp != null:
					plant_type = String(tmp)

	saved_node_name = node.name
	print("[PlantNodeDataResource] Saved plant:", saved_node_name, " type:", plant_type, " stage:", growth_stage, " start_day:", saved_starting_day, " watered:", saved_is_watered)


# --- Helper: apply saved state into a node instance or original ---
func _apply_saved_properties_to_node(target: Node) -> void:
	if target == null:
		return

	# find growth component on target
	var gc_target: Node = null
	if target.has_node("GrowthCycleComponent"):
		gc_target = target.get_node("GrowthCycleComponent")
	else:
		for c in target.get_children():
			if c is Node and (c.has_method("set_current_growth_state") or c.has_method("set_state") or c.has_method("set_growth_stage") or c.has_method("set_growth_progress") or c.has_method("set_planted_time") or c.get_class() == "GrowthCycleComponent"):
				gc_target = c
				break

	# If growth component exists, restore starting_day, is_watered and current_growth_state
	if gc_target != null:
		# set starting_day if possible
		if gc_target.has_method("set"):
			# prefer direct property set for starting_day
			if gc_target.get("starting_day") != null:
				gc_target.set("starting_day", saved_starting_day)
			else:
				# try method names
				if gc_target.has_method("set_starting_day"):
					gc_target.call("set_starting_day", saved_starting_day)
		else:
			# try method form
			if gc_target.has_method("set_starting_day"):
				gc_target.call("set_starting_day", saved_starting_day)

		# set is_watered (boolean)
		if gc_target.has_method("set"):
			if gc_target.get("is_watered") != null:
				gc_target.set("is_watered", saved_is_watered)
			else:
				if gc_target.has_method("set_is_watered"):
					gc_target.call("set_is_watered", saved_is_watered)
		else:
			if gc_target.has_method("set_is_watered"):
				gc_target.call("set_is_watered", saved_is_watered)

		# set current growth state (prefer setter method if present, otherwise set property)
		if gc_target.has_method("set_current_growth_state"):
			gc_target.call("set_current_growth_state", growth_stage)
		elif gc_target.has_method("set_state"):
			gc_target.call("set_state", growth_stage)
		elif gc_target.has_method("set_growth_stage"):
			gc_target.call("set_growth_stage", growth_stage)
		else:
			# attempt to set property directly if available
			if gc_target.has_method("set"):
				# try common property names
				if gc_target.get("current_growth_state") != null:
					gc_target.set("current_growth_state", growth_stage)
				elif gc_target.get("current_state") != null:
					gc_target.set("current_state", growth_stage)
				else:
					# last resort
					gc_target.set("growth_stage", growth_stage) if gc_target.has_method("set") else null

		# attempt to restore other optional values
		if gc_target.has_method("set"):
			if gc_target.get("growth_progress") != null:
				gc_target.set("growth_progress", growth_progress)
			elif gc_target.get("progress") != null:
				gc_target.set("progress", growth_progress)
			if gc_target.get("planted_time") != null:
				gc_target.set("planted_time", planted_time)

	else:
		# no growth component found -> apply directly to target node if possible
		if target.has_method("set"):
			target.set("starting_day", saved_starting_day) if target.has_method("set") else null
			target.set("is_watered", saved_is_watered) if target.has_method("set") else null
			target.set("growth_stage", growth_stage) if target.has_method("set") else null
			target.set("growth_progress", growth_progress) if target.has_method("set") else null
			target.set("planted_time", planted_time) if target.has_method("set") else null

	# Update sprite frame immediately so visuals match
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

# --- Load ---
func _load_data(window: Window) -> void:
	var parent_node: Node = null
	if parent_node_path != null and String(parent_node_path) != "":
		parent_node = window.get_node_or_null(parent_node_path)

	# 1) instantiate scene if scene_file_path present
	if scene_file_path != null and String(scene_file_path) != "" and ResourceLoader.exists(scene_file_path):
		var packed: Resource = ResourceLoader.load(scene_file_path)
		if packed != null:
			var scene_instance: Node = packed.instantiate()
			if scene_instance is Node2D:
				(scene_instance as Node2D).global_position = global_position
			if parent_node != null:
				parent_node.add_child(scene_instance)
			_apply_saved_properties_to_node(scene_instance)
			print("[PlantNodeDataResource] Restored plant by instancing scene:", saved_node_name)
			return

	# 2) try to find original node by node_path and duplicate/update it
	if node_path != null and String(node_path) != "":
		var orig: Node = window.get_node_or_null(node_path)
		if orig != null:
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
			# fallback: update existing original node
			_apply_saved_properties_to_node(orig)
			print("[PlantNodeDataResource] Restored plant by updating existing node:", saved_node_name)
			return

	push_warning("[PlantNodeDataResource] Could not restore plant for node_path: %s (scene_file_path=%s)" % [str(node_path), str(scene_file_path)])
