extends Node

signal tribute_updated(tribute_id: String, paid: int, target: int)
signal tribute_message(msg: String)

# tributes[tribute_id] = {"items": { item_name: {"target":int, "paid":int}, ... }, "last_update_day": int}
var tributes: Dictionary = {}

const SAVE_PATH: String = "user://tribute.cfg"
const DAYS_PER_UPDATE: int = 7

var DayAndNightCycleManager: Node = null
var current_open_tribute: String = ""
var current_status_text: String = ""

@export var auto_persist: bool = false

# fuzzy configuration
@export var fuzzy_randomize_enabled: bool = true
@export var fuzziness_level: float = 0.6
@export var random_variation_range: float = 0.08
@export var fuzzy_min_multiplier: float = 0.90
@export var fuzzy_max_multiplier: float = 1.6
@export var deterministic_increase_rate: float = 0.15

func _ready() -> void:
	print("[TributeManager] READY: autoload under /root? ", get_tree().get_root().has_node("TributeManager"))
	DayAndNightCycleManager = get_tree().get_root().get_node_or_null("DayAndNightCycleManager")
	if DayAndNightCycleManager != null and DayAndNightCycleManager.has_signal("time_tick_day"):
		DayAndNightCycleManager.time_tick_day.connect(Callable(self, "_on_day_tick"))

# Persistence helpers (legacy)
func persist_now() -> void:
	_save()

func enable_auto_persist() -> void:
	auto_persist = true

func disable_auto_persist() -> void:
	auto_persist = false

func reset_persist_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No persist file to remove:", SAVE_PATH)
		return
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_warning("Could not open user:// dir to remove persist file.")
		return
	var filename: String = SAVE_PATH.get_file()
	var err: int = dir.remove(filename)
	if err != OK:
		push_warning("Failed removing persist file: %s (err %s)" % [SAVE_PATH, str(err)])
	else:
		print("Removed legacy persist file:", SAVE_PATH)

# Current tribute helpers and dialogue integration
func set_current_tribute(tribute_id: String) -> void:
	current_open_tribute = String(tribute_id)
	update_current_status_text(current_open_tribute)

func clear_current_tribute() -> void:
	current_open_tribute = ""
	current_status_text = ""

func emit_status_current() -> void:
	if current_open_tribute == "":
		_emit_and_log("Tidak ada peti upeti terbuka.")
		return
	emit_status(current_open_tribute)

func attempt_pay_current() -> String:
	if current_open_tribute == "":
		var m: String = "Tidak ada peti upeti terbuka."
		_emit_and_log(m)
		return m
	return attempt_pay_from_inventory(current_open_tribute)

func attempt_pay_current_and_update() -> String:
	var res: String = attempt_pay_current()
	if res == "Tidak ada item yang bisa disetor sekarang.":
		current_status_text = res
	elif res.findn("Setor") != -1:
		current_status_text = res
	else:
		update_current_status_text()
	emit_signal("tribute_message", current_status_text)
	return res

func update_current_status_text(tribute_id: String = "") -> void:
	var id: String = tribute_id
	if id == "":
		id = current_open_tribute
	if id == "":
		current_status_text = "Tidak ada peti upeti terbuka."
		emit_signal("tribute_message", current_status_text)
		return
	current_status_text = get_status_string(id)
	emit_signal("tribute_message", current_status_text)

# Register / Query
func register_tribute(tribute_id: String, items_map: Dictionary, current_day: int) -> void:
	if tributes.has(tribute_id):
		var t: Dictionary = tributes[tribute_id]
		for item_name in items_map.keys():
			if not t.items.has(item_name):
				t.items[item_name] = {"target": int(items_map[item_name]), "paid": 0}
		tributes[tribute_id] = t
		if auto_persist:
			_save()
		return

	var items_struct: Dictionary = {}
	for item_name in items_map.keys():
		items_struct[String(item_name)] = {"target": max(1, int(items_map[item_name])), "paid": 0}
	tributes[tribute_id] = {
		"items": items_struct,
		"last_update_day": int(current_day)
	}
	if auto_persist:
		_save()

func get_tribute(tribute_id: String) -> Dictionary:
	if not tributes.has(tribute_id):
		return {}
	return tributes[tribute_id].duplicate(true)

func get_status_string(tribute_id: String) -> String:
	if not tributes.has(tribute_id):
		return "Upeti tidak terdaftar."
	var t: Dictionary = tributes[tribute_id]
	var items: Dictionary = t.get("items", {})
	var parts: Array = []
	for item_name in items.keys():
		var info: Dictionary = items[item_name]
		var paid: int = int(info.get("paid", 0))
		var target: int = int(info.get("target", 0))
		parts.append("%s %d/%d" % [item_name, paid, target])
	return String(" • ").join(parts)

func _emit_and_log(msg: String) -> void:
	emit_signal("tribute_message", msg)
	var root: Node = get_tree().get_root()
	var gm_node: Node = root.get_node_or_null("GameDialogueManager")
	if gm_node != null:
		var cand_names: Array = ["action_show_text", "action_show_message", "action_add_text", "action_add_line", "show_text", "show_message"]
		for n in cand_names:
			if gm_node.has_method(n):
				gm_node.call_deferred(n, msg)
				break
	print("[TributeManager] " + msg)

func emit_status(tribute_id: String) -> void:
	var s: String = get_status_string(tribute_id)
	_emit_and_log(s)

# Payment logic
func attempt_pay_from_inventory(tribute_id: String) -> String:
	if not tributes.has(tribute_id):
		var errm: String = "Upeti tidak terdaftar."
		_emit_and_log(errm)
		return errm

	var t: Dictionary = tributes[tribute_id]
	var items: Dictionary = t.get("items", {})
	var summary_parts: Array = []
	var any_taken: bool = false

	var root: Node = get_tree().get_root()
	var inv_node: Node = root.get_node_or_null("InventoryManager")

	for item_name in items.keys():
		var info: Dictionary = items[item_name]
		var paid: int = int(info.get("paid", 0))
		var target: int = int(info.get("target", 0))
		var needed: int = max(0, target - paid)
		if needed <= 0:
			continue

		var available: int = 0
		if inv_node != null and inv_node.has_method("count_collectable"):
			available = inv_node.count_collectable(item_name)
		else:
			push_warning("InventoryManager not found; cannot collect item: %s" % item_name)
			available = 0

		if available <= 0:
			continue

		var to_take: int = min(available, needed)
		var removed: int = 0
		if inv_node != null and inv_node.has_method("remove_collectable"):
			removed = inv_node.remove_collectable(item_name, to_take)
		else:
			removed = 0

		removed = int(removed)
		if removed > 0:
			any_taken = true
			info.paid = int(paid) + removed
			items[item_name] = info
			summary_parts.append("Setor %d %s" % [removed, item_name])

	t.items = items
	tributes[tribute_id] = t
	if auto_persist:
		_save()

	if any_taken:
		emit_signal("tribute_updated", tribute_id, 0, 0)
		var status: String = get_status_string(tribute_id)
		var msg: String = String(", ").join(summary_parts) + ". Progress: " + status
		_emit_and_log(msg)
		if _is_tribute_completed(tribute_id):
			_emit_and_log("Upeti untuk %s telah terpenuhi!" % tribute_id)
		return msg
	else:
		var nomsg: String = "Tidak ada item yang bisa disetor sekarang."
		_emit_and_log(nomsg)
		return nomsg

func _is_tribute_completed(tribute_id: String) -> bool:
	if not tributes.has(tribute_id):
		return false
	var t: Dictionary = tributes[tribute_id]
	for item_name in t.items.keys():
		var info: Dictionary = t.items[item_name]
		if int(info.get("paid", 0)) < int(info.get("target", 0)):
			return false
	return true

# Fuzzy helpers
func _randf_seeded(seed: int, a: float, b: float) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(seed)
	return rng.randf_range(a, b)

func _compute_scarcity(tribute: Dictionary, item_name: String) -> float:
	if tribute == null:
		return 0.0
	var items: Dictionary = tribute.get("items", {})
	if items == null:
		return 0.0
	var info: Dictionary = items.get(item_name, null)
	if info == null:
		return 0.0
	var paid: float = float(info.get("paid", 0))
	var target: float = float(info.get("target", 1))
	if target <= 0.0:
		return 0.0
	var ratio: float = paid / target
	return clamp(1.0 - ratio, 0.0, 1.0)

func _fuzzy_multiplier_from_scarcity(scarcity: float) -> float:
	if scarcity < 0.3:
		return lerp(0.99, 1.03, scarcity / 0.3)
	elif scarcity < 0.7:
		return lerp(1.06, 1.18, (scarcity - 0.3) / 0.4)
	else:
		return lerp(1.20, 1.40, (scarcity - 0.7) / 0.3)

func _calculate_final_multiplier(tribute_id: String, item_name: String, checkpoint_index: int = 0) -> float:
	if not fuzzy_randomize_enabled:
		return 1.0 + deterministic_increase_rate

	if not tributes.has(tribute_id):
		return 1.0 + deterministic_increase_rate

	var tribute: Dictionary = tributes[tribute_id]
	var scarcity: float = _compute_scarcity(tribute, item_name)
	var fuzzy_central: float = _fuzzy_multiplier_from_scarcity(scarcity)

	var base_mult: float = 1.0 + deterministic_increase_rate
	var combined: float = lerp(base_mult, fuzzy_central, clamp(fuzziness_level, 0.0, 1.0))

	var day_seed: int = 0
	if DayAndNightCycleManager != null:
		var tmp_day_variant: Variant = DayAndNightCycleManager.get("current_day")
		if tmp_day_variant != null:
			day_seed = int(tmp_day_variant)

	var name_hash: int = abs(item_name.hash())
	var seed: int = int(day_seed) * 1000 + int(checkpoint_index) * 100 + int(name_hash % 997)

	var jitter_low: float = 1.0 - clamp(random_variation_range, 0.0, 1.0)
	var jitter_high: float = 1.0 + clamp(random_variation_range, 0.0, 1.0)
	var jitter: float = _randf_seeded(seed, jitter_low, jitter_high)

	var final_mult: float = combined * jitter
	final_mult = clamp(final_mult, fuzzy_min_multiplier, fuzzy_max_multiplier)
	return final_mult

func _apply_fuzzy_increase_to_tribute(tribute_id: String, checkpoint_index: int = 0) -> void:
	if not tributes.has(tribute_id):
		return
	var t: Dictionary = tributes[tribute_id]
	for item_name in t.items.keys():
		var info: Dictionary = t.items[item_name]
		var old_target: int = int(info.get("target", 0))
		if old_target <= 0:
			old_target = 1
		var mult: float = _calculate_final_multiplier(tribute_id, item_name, checkpoint_index)
		var new_target: int = int(ceil(float(old_target) * mult))
		if new_target <= old_target:
			new_target = old_target + 1
		info.target = new_target
		t.items[item_name] = info
	tributes[tribute_id] = t
	if auto_persist:
		_save()
	_emit_and_log("Upeti '%s' bertambah (fuzzy) pada checkpoint." % tribute_id)

# Day tick handler
func _on_day_tick(day: int) -> void:
	var changed: bool = false
	for id in tributes.keys():
		var t: Dictionary = tributes[id]
		var last: int = int(t.get("last_update_day", 0))
		var days_passed: int = int(day) - last
		if days_passed >= DAYS_PER_UPDATE:
			var intervals: int = days_passed / DAYS_PER_UPDATE
			for i in range(intervals):
				if not _is_tribute_completed(id):
					for item_name in t.items.keys():
						var info: Dictionary = t.items[item_name]
						info.paid = 0
						t.items[item_name] = info
					_emit_and_log("Upeti '%s' gagal dipenuhi pada checkpoint. Pembayaran direset ke 0." % id)
				_apply_fuzzy_increase_to_tribute(id, i)
			t.last_update_day = last + intervals * DAYS_PER_UPDATE
			tributes[id] = t
			changed = true
	if changed:
		if auto_persist:
			_save()

# Legacy save/load
func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for id in tributes.keys():
		var section_name: String = "tributes/" + String(id)
		var t: Dictionary = tributes[id]
		cfg.set_value(section_name, "last_update_day", int(t.get("last_update_day", 0)))
		for item_name in t.items.keys():
			var info: Dictionary = t.items[item_name]
			cfg.set_value(section_name, item_name + "/target", int(info.get("target", 0)))
			cfg.set_value(section_name, item_name + "/paid", int(info.get("paid", 0)))
	var err: int = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("Failed saving TributeManager to %s (err %s)" % [SAVE_PATH, str(err)])

func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(SAVE_PATH)
	if err != OK:
		return
	var sections: Array = cfg.get_sections()
	for sname in sections:
		var sn: String = String(sname)
		if not sn.begins_with("tributes/"):
			continue
		var id: String = sn.get_slice("/", 1)
		if id == "":
			continue
		var last_val: int = int(cfg.get_value(sn, "last_update_day", 0))
		var keys: Array = cfg.get_section_keys(sn)
		var items_struct: Dictionary = {}
		for key in keys:
			var parts: Array = String(key).split("/")
			if parts.size() < 2:
				continue
			var item_name: String = parts[0]
			var prop: String = parts[1]
			if not items_struct.has(item_name):
				items_struct[item_name] = {"target":0, "paid":0}
			var val_int: int = int(cfg.get_value(sn, key, 0))
			if prop == "target":
				items_struct[item_name].target = val_int
			elif prop == "paid":
				items_struct[item_name].paid = val_int
		tributes[id] = {"items": items_struct, "last_update_day": int(last_val)}

# Save API for save system
func get_save_dict() -> Dictionary:
	return tributes.duplicate(true)

func load_from_dict(data: Dictionary) -> void:
	if data == null:
		return
	tributes = data.duplicate(true)
	if current_open_tribute != "":
		update_current_status_text()
	print("[TributeManager] Tribute state loaded from SaveGame.")
