extends NodeDataResource
class_name TributeNodeDataResource

@export var tributes: Dictionary = {}
@export var saved_node_name: String = ""

func _save_data(node: Node2D) -> void:
	print("[TributeNodeDataResource] Saving tribute snapshot from node:", node.name)

	var tree: SceneTree = node.get_tree()
	if tree != null:
		var root: Node = tree.get_root()
		var tm_node: Node = root.get_node_or_null("TributeManager")
		if tm_node != null:
			if tm_node.has_method("get_save_dict"):
				tributes = tm_node.get_save_dict()
			else:
				var tmp_tributes: Variant = tm_node.get("tributes")
				if tmp_tributes != null:
					tributes = tmp_tributes.duplicate(true)
				else:
					tributes = {}
		else:
			tributes = tributes.duplicate(true)
	else:
		push_warning("[TributeNodeDataResource] Node has no SceneTree; skipping TributeManager snapshot.")
		tributes = tributes.duplicate(true)

	saved_node_name = node.name

func _load_data(window: Window) -> void:
	print("[TributeNodeDataResource] Loading tribute data from save file.")

	var root: Node = null
	if window != null:
		root = window as Node
	else:
		var main_loop: Object = Engine.get_main_loop()
		if main_loop is SceneTree:
			var tree2: SceneTree = main_loop as SceneTree
			root = tree2.get_root()

	if root != null:
		var tm_node: Node = root.get_node_or_null("TributeManager")
		if tm_node != null:
			if tm_node.has_method("load_from_dict"):
				tm_node.load_from_dict(tributes)
			else:
				var existing_var: Variant = tm_node.get("tributes")
				if existing_var != null:
					tm_node.set("tributes", tributes.duplicate(true))
					if tm_node.has_method("update_current_status_text"):
						tm_node.update_current_status_text()
			print("[TributeNodeDataResource] Tribute data injected to TributeManager (root node).")
			return
		else:
			push_warning("[TributeNodeDataResource] TributeManager not found under root during load.")
	else:
		push_warning("[TributeNodeDataResource] Could not determine scene root during load; data retained in resource.")
