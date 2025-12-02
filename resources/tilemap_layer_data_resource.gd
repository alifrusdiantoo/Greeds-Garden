# TileMapLayerDataResource.gd
class_name TileMapLayerDataResource
extends NodeDataResource

@export var tilemap_layer_used_cells: Array[Vector2i] = []
@export var terrain_set: int = 0
@export var terrain: int = 3

func _save_data(node: Node2D) -> void:
	# call parent to save common fields (global_position, node_path, parent_node_path)
	super._save_data(node)

	# Node should be TileMapLayer or subclass; use safe cast
	var tilemap_layer: Node = node
	if tilemap_layer == null:
		push_warning("[TileMapLayerDataResource] _save_data called with null node.")
		tilemap_layer_used_cells = []
		return

	# If the node has method get_used_cells, call it safely
	if tilemap_layer.has_method("get_used_cells"):
		var cells_raw: Array = tilemap_layer.call("get_used_cells")
		# ensure type: convert values to Vector2i if needed
		var cells_out: Array[Vector2i] = []
		for c in cells_raw:
			if typeof(c) == TYPE_VECTOR2:
				# convert Vector2 to Vector2i by rounding/floor
				cells_out.append(Vector2i(int(c.x), int(c.y)))
			elif typeof(c) == TYPE_VECTOR2I:
				cells_out.append(c)
			else:
				# ignore unexpected types
				pass
		tilemap_layer_used_cells = cells_out
	else:
		# fallback: empty
		tilemap_layer_used_cells = []

	print("[TileMapLayerDataResource] Saved", tilemap_layer_used_cells.size(), "used cells for node:", node.name)


func _load_data(window: Window) -> void:
	# find the original node instance by node_path
	if node_path == null or String(node_path) == "":
		push_warning("[TileMapLayerDataResource] node_path empty; cannot restore tilemap layer.")
		return

	var scene_node: Node = window.get_node_or_null(node_path)
	if scene_node == null:
		push_warning("[TileMapLayerDataResource] scene node not found for path: %s" % str(node_path))
		return

	# ensure this node supports set_cells_terrain_connect
	if scene_node.has_method("set_cells_terrain_connect"):
		scene_node.call("set_cells_terrain_connect", tilemap_layer_used_cells, int(terrain_set), int(terrain), true)
		print("[TileMapLayerDataResource] Restored", tilemap_layer_used_cells.size(), "cells on", node_path)
	else:
		push_warning("[TileMapLayerDataResource] scene node does not implement set_cells_terrain_connect: %s" % str(node_path))
