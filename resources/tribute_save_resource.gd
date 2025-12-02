# tribute_save_resource.gd
extends Resource
class_name TributeSaveResource

# disimpan oleh SaveLevelDataComponent (Resource must be savable)
@export var tributes: Dictionary = {}  # will contain copy of TributeManager.tributes
@export var saved_node_name: String = "" # optional: name of node that created this entry

# Called by SaveDataComponent._save_data(parent_node)
# Should return a Resource that represents saved data (usually self or duplicate)
func _save_data(parent_node: Node) -> Resource:
	# take a deep copy of current TributeManager data (if available)
	# Use Engine.has_singleton to avoid errors if autoload not registered yet
	if Engine.has_singleton("TributeManager"):
		var tm = TributeManager
		# deep copy
		tributes = tm.tributes.duplicate(true)
	else:
		# fallback: keep existing stored data
		tributes = tributes.duplicate(true)
	saved_node_name = str(parent_node.name)
	# return a duplicate so SaveLevelDataComponent can duplicate again safely if needed
	return duplicate(true)

# Called when loading: SaveLevelDataComponent will loop saved resources and call _load_data(root_node)
# root_node is the tree root (as SaveLevelDataComponent uses)
func _load_data(root_node: Node) -> void:
	# If TributeManager exists, inject tributes into it
	if Engine.has_singleton("TributeManager"):
		var tm = TributeManager
		# Replace existing tribute entries with loaded data.
		tm.tributes = tributes.duplicate(true)
		# After replacing, ensure TributeManager internal state consistent:
		# e.g., update current_status_text if any tribute is currently open
		if tm.current_open_tribute != "":
			tm.update_current_status_text()
	else:
		# If TributeManager not registered as autoload, only warn (do not error)
		push_warning("TributeManager not present during load; tribute data stored in resource.")
