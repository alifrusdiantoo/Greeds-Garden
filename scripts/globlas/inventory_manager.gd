extends Node

# inventory map: item_name -> count
var inventory: Dictionary = {}

signal inventory_changed

func _ready() -> void:
	# nothing for now
	pass

# add a single collectable (legacy)
func add_collectable(collectable_name: String, amount: int = 1) -> void:
	if collectable_name == null or collectable_name == "":
		return
	if inventory.get(collectable_name) == null:
		inventory[collectable_name] = amount
	else:
		inventory[collectable_name] += amount
	emit_signal("inventory_changed")

# remove up to `amount` collectables, return how many actually removed
func remove_collectable(collectable_name: String, amount: int = 1) -> int:
	if collectable_name == null or collectable_name == "":
		return 0
	if inventory.get(collectable_name) == null:
		inventory[collectable_name] = 0
	var current: int = int(inventory[collectable_name])
	if current <= 0:
		return 0
	var to_remove: int = min(current, amount)
	current -= to_remove
	inventory[collectable_name] = current
	emit_signal("inventory_changed")
	return to_remove

# count items
func count_collectable(collectable_name: String) -> int:
	if inventory.get(collectable_name) == null:
		return 0
	return int(inventory[collectable_name])

# return deep copy of whole inventory (for saving)
func get_all() -> Dictionary:
	return inventory.duplicate(true)

# load inventory from dict (overwrite current)
func load_from_dict(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	inventory = data.duplicate(true)
	emit_signal("inventory_changed")

# convenience: clear inventory
func clear_inventory() -> void:
	inventory.clear()
	emit_signal("inventory_changed")
