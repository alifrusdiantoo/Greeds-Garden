# SaveDataComponent.gd
# Multi-resource SaveDataComponent with auto-detection for tilemap layers and plants
class_name SaveDataComponent
extends Node

@onready var parent_node: Node2D = get_parent() as Node2D

# Multi save resource slots (exported)
@export var inventory_resource: Resource
@export var tribute_resource: Resource

# Legacy single resource slot (backwards-compatible)
@export var save_data_resource: Resource

# Additional resource slots (array) for arbitrary NodeDataResource instances (TileMapLayer, SceneData, Plant, etc.)
@export var other_resources: Array[Resource] = []

func _ready() -> void:
	add_to_group("save_data_component")

# Collect snapshots from all configured resources. Returns Array[NodeDataResource]
func collect_save_resources() -> Array:
	var result: Array = []

	# --- 1) inventory_resource (preferred) ---
	if inventory_resource != null:
		var inv_copy: Resource = inventory_resource.duplicate(true)
		if inv_copy != null and inv_copy is Object and inv_copy.has_method("_save_data"):
			# ensure we pass a Node2D context
			var context_node_inv: Node2D = parent_node
			if context_node_inv == null:
				# try scene root child as fallback
				var root_node: Node = get_tree().get_root()
				if root_node.get_child_count() > 0 and root_node.get_child(0) is Node2D:
					context_node_inv = root_node.get_child(0) as Node2D
			if context_node_inv != null:
				inv_copy._save_data(context_node_inv)
			else:
				# still call but may be unsafe; call only if method present
				inv_copy._save_data(parent_node) if parent_node != null else null
		result.append(inv_copy)

	# --- 2) tribute_resource ---
	if tribute_resource != null:
		var trib_copy: Resource = tribute_resource.duplicate(true)
		if trib_copy != null and trib_copy is Object and trib_copy.has_method("_save_data"):
			var context_node_trib: Node2D = parent_node
			if context_node_trib == null:
				var rt: Node = get_tree().get_root()
				if rt.get_child_count() > 0 and rt.get_child(0) is Node2D:
					context_node_trib = rt.get_child(0) as Node2D
			if context_node_trib != null:
				trib_copy._save_data(context_node_trib)
			else:
				trib_copy._save_data(parent_node) if parent_node != null else null
		result.append(trib_copy)

	# --- 3) legacy single save_data_resource (backwards-compatible) ---
	if save_data_resource != null:
		var legacy_copy: Resource = save_data_resource.duplicate(true)
		if legacy_copy != null and legacy_copy is Object and legacy_copy.has_method("_save_data"):
			var context_legacy: Node2D = parent_node
			if context_legacy == null:
				var rt2: Node = get_tree().get_root()
				if rt2.get_child_count() > 0 and rt2.get_child(0) is Node2D:
					context_legacy = rt2.get_child(0) as Node2D
			if context_legacy != null:
				legacy_copy._save_data(context_legacy)
			else:
				legacy_copy._save_data(parent_node) if parent_node != null else null
		result.append(legacy_copy)

	# --- 4) other_resources array (for tilemap layers, scene nodes, plants, etc.) ---
	if other_resources != null:
		for r in other_resources:
			if r == null:
				continue
			var r_copy: Resource = r.duplicate(true)
			if r_copy != null and r_copy is Object and r_copy.has_method("_save_data"):
				# pass parent_node as context
				if parent_node != null:
					r_copy._save_data(parent_node)
				else:
					# fallback: try root child
					var root_alt: Node = get_tree().get_root()
					if root_alt.get_child_count() > 0 and root_alt.get_child(0) is Node2D:
						r_copy._save_data(root_alt.get_child(0) as Node2D)
			result.append(r_copy)

	# --- 5) Auto-detect common types if nothing collected yet or to complement existing ---
	# Auto-snapshot TileMapLayer if parent_node appears to be a tilemap layer (has get_used_cells)
	if parent_node != null and parent_node.has_method("get_used_cells"):
		# create runtime snapshot resource
		var tml_script: Script = preload("res://resources/tilemap_layer_data_resource.gd")
		if tml_script != null:
			var tml_res: Resource = tml_script.new()
			if tml_res != null and tml_res is Object and tml_res.has_method("_save_data"):
				tml_res._save_data(parent_node)
				result.append(tml_res)
				print("[SaveDataComponent] Auto-created TileMapLayer snapshot for node:", parent_node.name)

	# --- improved auto-detect plant nodes (replace previous plant auto-detect block) ---
	if parent_node != null:
		# If parent_node itself looks like a plant, snapshot it (same as before)
		var is_plant_self: bool = false
		if parent_node.has_method("get") and parent_node.get("growth_stage") != null:
			is_plant_self = true
		if not is_plant_self and (parent_node.is_in_group("crops") or parent_node.is_in_group("plant")):
			is_plant_self = true

		if is_plant_self:
			var plant_script := preload("res://resources/plant_node_data_resource.gd")
			var plant_res_self := plant_script.new()
			plant_res_self._save_data(parent_node)
			result.append(plant_res_self)
			print("[SaveDataComponent] Auto-saved plant snapshot for node (self):", parent_node.name)
		else:
			# parent looks like a container: iterate children
			for child in parent_node.get_children():
				if not (child is Node2D):
					continue
				var child_node: Node2D = child as Node2D

				# Heuristics to decide if child_node is a plant:
				var looks_like_plant: bool = false

				# 1) child exposes growth_stage directly (old style)
				if child_node.has_method("get") and child_node.get("growth_stage") != null:
					looks_like_plant = true

				# 2) child is in group "crops" or "plant"
				if not looks_like_plant and (child_node.is_in_group("crops") or child_node.is_in_group("plant")):
					looks_like_plant = true

				# 3) IMPORTANT: child has a child GrowthCycleComponent or a child with growth methods
				if not looks_like_plant:
					# check for named node
					if child_node.has_node("GrowthCycleComponent"):
						looks_like_plant = true
					else:
						# search child's children for a growth component method
						for gc_candidate in child_node.get_children():
							if gc_candidate is Node and (gc_candidate.has_method("get_current_growth_state") or gc_candidate.has_method("get_current_state")):
								looks_like_plant = true
								break

				# If heuristics matched, create PlantNodeDataResource for this child
				if looks_like_plant:
					var plant_script2 := preload("res://resources/plant_node_data_resource.gd")
					if plant_script2 != null:
						var plant_res_child: Resource = plant_script2.new()
						if plant_res_child != null and plant_res_child is Object and plant_res_child.has_method("_save_data"):
							# pass the child node itself so node_path refers to the actual plant node
							plant_res_child._save_data(child_node)
							result.append(plant_res_child)
							print("[SaveDataComponent] Auto-saved plant snapshot for child:", child_node.name)

	return result
