extends NodeDataResource
class_name InventoryNodeDataResource

@export var items: Dictionary = {}
@export var saved_node_name: String = ""

# node: node yang memanggil save (mis. player atau level root)
func _save_data(node: Node2D) -> void:
	# ambil dari InventoryManager autoload di root
	var root: Node = node.get_tree().get_root()
	var inv_node: Node = root.get_node_or_null("InventoryManager")
	if inv_node != null and inv_node.has_method("get_all"):
		var snapshot: Dictionary = inv_node.get_all()
		if snapshot != null:
			items = snapshot.duplicate(true)
		else:
			items = {}
	else:
		# fallback: kosongkan
		items = {}
	saved_node_name = node.name
	print("[InventoryNodeDataResource] Saved inventory snapshot with", items.size(), "entries.")

func _load_data(window: Window) -> void:
	# window is root node passed from SaveLevelDataComponent
	var root: Node = null
	if window != null:
		root = window as Node
	else:
		var main_loop := Engine.get_main_loop()
		if main_loop is SceneTree:
			root = (main_loop as SceneTree).get_root()
	if root == null:
		push_warning("[InventoryNodeDataResource] No root available to load inventory.")
		return

	var inv_node: Node = root.get_node_or_null("InventoryManager")
	if inv_node != null and inv_node.has_method("load_from_dict"):
		inv_node.load_from_dict(items)
		print("[InventoryNodeDataResource] Loaded inventory into InventoryManager with", items.size(), "entries.")
	else:
		push_warning("[InventoryNodeDataResource] InventoryManager not found or missing load_from_dict().")
