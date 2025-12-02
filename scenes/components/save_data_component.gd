class_name SaveDataComponent
extends Node

@onready var parent_node: Node2D = get_parent() as Node2D

@export var inventory_resource: Resource
@export var tribute_resource: Resource

func _ready() -> void:
	add_to_group("save_data_component")

func collect_save_resources() -> Array:
	var result: Array = []

	# INVENTORY: if inventory_resource present & implements _save_data -> use it
	var used_inv: bool = false
	if inventory_resource != null:
		# try to call duplicate snapshot
		var inv_copy: Resource = inventory_resource.duplicate(true)
		if inv_copy is Object and inv_copy.has_method("_save_data"):
			inv_copy._save_data(parent_node)
			result.append(inv_copy)
			used_inv = true
		else:
			# if resource is generic NodeDataResource (or doesn't implement _save_data),
			# we'll fallback to programmatic InventoryNodeDataResource below
			used_inv = false

	# Fallback: create InventoryNodeDataResource programmatically if needed
	if not used_inv:
		# try to create snapshot from InventoryManager
		var root: Node = get_tree().get_root()
		var inv_node: Node = root.get_node_or_null("InventoryManager")
		if inv_node != null:
			# instantiate InventoryNodeDataResource script and call _save_data
			var inv_res_script = preload("res://resources/inventory_node_data_resource.gd")
			var inv_snapshot = inv_res_script.new()
			if inv_snapshot.has_method("_save_data"):
				inv_snapshot._save_data(parent_node)
				result.append(inv_snapshot)
				print("[SaveDataComponent] Fallback inventory snapshot created for node:", name)
		else:
			# no InventoryManager found; nothing to save
			pass

	# TRIBUTE: if resource present
	if tribute_resource != null:
		var trib_copy: Resource = tribute_resource.duplicate(true)
		if trib_copy is Object and trib_copy.has_method("_save_data"):
			trib_copy._save_data(parent_node)
			result.append(trib_copy)

	return result
