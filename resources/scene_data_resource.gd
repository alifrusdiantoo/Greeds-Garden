# SceneDataResource.gd
class_name SceneDataResource
extends NodeDataResource

@export var node_name: String = ""
@export var scene_file_path: String = ""

func _save_data(node: Node2D) -> void:
	super._save_data(node)

	# save node info
	node_name = node.name if node != null else ""
	# if node has scene_file_path property, prefer resource's exported path; otherwise leave as-is
	# (we assume the exported scene_file_path was set when resource was created)
	# nothing else to do here

func _load_data(window: Window) -> void:
	# parent_node_path/ node_path come from base NodeDataResource
	var parent_node: Node = null
	var scene_node: Node = null

	# ensure parent_node_path is valid
	if parent_node_path != null and String(parent_node_path) != "":
		parent_node = window.get_node_or_null(parent_node_path)

	# instantiate scene if scene_file_path is valid
	if scene_file_path != null and String(scene_file_path) != "":
		# check resource exists
		if ResourceLoader.exists(scene_file_path):
			var scene_file_resource: PackedScene = ResourceLoader.load(scene_file_path)
			if scene_file_resource != null:
				scene_node = scene_file_resource.instantiate() as Node2D
			else:
				push_warning("[SceneDataResource] Failed to load PackedScene at path: %s" % scene_file_path)
		else:
			push_warning("[SceneDataResource] scene_file_path does not exist: %s" % scene_file_path)

	# add node to parent if both exist
	if parent_node != null and scene_node != null:
		# ensure scene_node is Node2D to assign global_position
		if scene_node is Node2D:
			(scene_node as Node2D).global_position = global_position
		parent_node.add_child(scene_node)
		print("[SceneDataResource] Instantiated scene %s as child of %s" % [scene_file_path, str(parent_node.name)])
	else:
		# warn if something missing
		if parent_node == null:
			push_warning("[SceneDataResource] parent_node not found for parent_node_path: %s" % str(parent_node_path))
		if scene_node == null:
			push_warning("[SceneDataResource] scene_node not instantiated for scene_file_path: %s" % str(scene_file_path))
