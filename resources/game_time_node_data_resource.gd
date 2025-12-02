# res://resources/game_time_node_data_resource.gd
extends NodeDataResource
class_name GameTimeNodeDataResource

@export var saved_day: int = 1
@export var saved_hour: int = 12
@export var saved_minute: int = 30
@export var saved_time: float = 0.0
@export var saved_node_name: String = ""

# Keep signature compatible with base NodeDataResource which expects Node2D
func _save_data(node: Node2D) -> void:
	var root: Node = null
	if node != null:
		var tree: SceneTree = node.get_tree()
		if tree != null:
			root = tree.get_root()

	# fallback: engine main loop root
	if root == null:
		var ml: Object = Engine.get_main_loop()
		if ml is SceneTree:
			var tree2: SceneTree = ml as SceneTree
			root = tree2.get_root()

	if root == null:
		push_warning("[GameTimeNodeDataResource] No root to take time snapshot from.")
		return

	var dn: Node = root.get_node_or_null("DayAndNightCycleManager")
	if dn == null:
		push_warning("[GameTimeNodeDataResource] DayAndNightCycleManager not found; leaving defaults.")
		return

	# try read precise time float if available
	var maybe_time: Variant = dn.get("time")
	if maybe_time != null:
		saved_time = float(maybe_time)
	else:
		# fallback: try read initial_* and compute if possible
		var iday_var: Variant = dn.get("initial_day")
		var ihour_var: Variant = dn.get("initial_hour")
		var imin_var: Variant = dn.get("initial_minute")
		if iday_var != null and ihour_var != null and imin_var != null:
			var iday: int = int(iday_var)
			var ihour: int = int(ihour_var)
			var imin: int = int(imin_var)
			var minutes_total: int = iday * 24 * 60 + ihour * 60 + imin
			var gmd_var: Variant = dn.get("GAME_MINUTE_DURATION")
			if gmd_var != null:
				var gmd_float: float = float(gmd_var)
				saved_time = float(minutes_total) * gmd_float
			else:
				saved_time = 0.0

	# read current day/minute if available
	var maybe_day: Variant = dn.get("current_day")
	if maybe_day != null:
		saved_day = int(maybe_day)
	var maybe_min: Variant = dn.get("current_minute")
	if maybe_min != null:
		saved_minute = int(maybe_min)
		# derive hour from minutes-of-day
		var derived_hour: int = int(saved_minute / 60) % 24
		saved_hour = derived_hour

	# save node name (use GDScript conditional expression)
	saved_node_name = node.name if node != null else ""

	print("[GameTimeNodeDataResource] Saved time snapshot: time=%f day=%d hour=%d minute=%d" % [saved_time, saved_day, saved_hour, saved_minute])


# Load snapshot; window is root node passed from SaveLevelDataComponent
func _load_data(window: Window) -> void:
	var root: Node = null
	if window != null:
		root = window as Node
	else:
		var ml: Object = Engine.get_main_loop()
		if ml is SceneTree:
			var tree2: SceneTree = ml as SceneTree
			root = tree2.get_root()

	if root == null:
		push_warning("[GameTimeNodeDataResource] No scene root to restore time.")
		return

	var dn: Node = root.get_node_or_null("DayAndNightCycleManager")
	if dn == null:
		push_warning("[GameTimeNodeDataResource] DayAndNightCycleManager not found during load.")
		return

	# Preferred: set time float if manager supports it, then recalc
	var has_time_prop: Variant = dn.get("time")
	if has_time_prop != null:
		dn.set("time", saved_time)
		# try call recalc method if exists
		if dn.has_method("recalculate_time"):
			dn.call_deferred("recalculate_time")
		else:
			# fallback: set initial_* and call set_initial_time()
			if dn.get("initial_day") != null:
				dn.set("initial_day", saved_day)
			if dn.get("initial_hour") != null:
				dn.set("initial_hour", saved_hour)
			if dn.get("initial_minute") != null:
				dn.set("initial_minute", saved_minute)
			if dn.has_method("set_initial_time"):
				dn.call_deferred("set_initial_time")
	else:
		# no time prop, set initial_* and call set_initial_time()
		if dn.get("initial_day") != null:
			dn.set("initial_day", saved_day)
		if dn.get("initial_hour") != null:
			dn.set("initial_hour", saved_hour)
		if dn.get("initial_minute") != null:
			dn.set("initial_minute", saved_minute)
		if dn.has_method("set_initial_time"):
			dn.call_deferred("set_initial_time")

	print("[GameTimeNodeDataResource] Restored time request: time=%f day=%d hour=%d minute=%d" % [saved_time, saved_day, saved_hour, saved_minute])
