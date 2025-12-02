# SaveGameDataResource.gd
class_name SaveGameDataResource
extends Resource

# typed exported array of NodeDataResource
@export var save_data_nodes: Array[NodeDataResource] = []

# helper: add a node resource (already duplicated if caller ingin)
func add_node_resource(res: NodeDataResource) -> void:
	if res == null:
		return
	save_data_nodes.append(res)

# helper: clear all
func clear_nodes() -> void:
	save_data_nodes.clear()

# helper: convenience factory that returns a deep duplicate of this resource (if needed)
func duplicate_deep() -> SaveGameDataResource:
	var copy: SaveGameDataResource = SaveGameDataResource.new()
	for r in save_data_nodes:
		if r != null:
			copy.save_data_nodes.append(r.duplicate(true))
	return copy
