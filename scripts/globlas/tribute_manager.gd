extends Node

var balloon_scene: PackedScene = preload("res://dialogue/game_dialogue_balloon.tscn")

signal tribute_updated(tribute_id: String, paid: int, target: int)
signal tribute_message(msg: String)
signal tribute_executed(tribute_id: String)

var tributes: Dictionary = {}

const SAVE_PATH: String = "user://tribute.cfg"
const INCREASE_RATE: float = 0.15
const DAYS_PER_UPDATE: int = 7

var DayAndNightCycleManager: Node = null
var current_open_tribute: String = ""
var current_status_text: String = ""

@export var auto_persist: bool = false

func _ready() -> void:
	DayAndNightCycleManager = get_node_or_null("/root/DayAndNightCycleManager")
	# optionally load legacy file if desired (comment out if you don't want auto-load)
	# _load()
	if DayAndNightCycleManager != null and DayAndNightCycleManager.has_signal("time_tick_day"):
		DayAndNightCycleManager.time_tick_day.connect(Callable(self, "_on_day_tick"))


# Persistence helpers
func persist_now() -> void:
	_save()

func enable_auto_persist() -> void:
	auto_persist = true

func disable_auto_persist() -> void:
	auto_persist = false

func reset_persist_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No persist file to remove: ", SAVE_PATH)
		return

	var dir = DirAccess.open("user://")
	if dir == null:
		push_warning("Could not open user:// directory to remove persist file.")
		return

	var filename: String = SAVE_PATH.get_file()
	var err: int = dir.remove(filename)
	if err != OK:
		push_warning("Failed removing persist file: %s (err %s)" % [SAVE_PATH, str(err)])
	else:
		print("Removed legacy persist file: ", SAVE_PATH)


# Current tribute helpers
func set_current_tribute(tribute_id: String) -> void:
	current_open_tribute = String(tribute_id)
	update_current_status_text(current_open_tribute)

func clear_current_tribute() -> void:
	current_open_tribute = ""
	current_status_text = ""

func emit_status_current() -> void:
	if current_open_tribute == "":
		var m: String = "Tidak ada peti upeti terbuka."
		_emit_and_log(m)
		return
	emit_status(current_open_tribute)

func attempt_pay_current() -> String:
	if current_open_tribute == "":
		var m2: String = "Tidak ada peti upeti terbuka."
		_emit_and_log(m2)
		return m2
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


# Register / query
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
		"last_update_day": int(current_day),
		"fail_count": 0
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
	var fc: int = int(t.get("fail_count", 0))
	if fc > 0:
		parts.append("[Gagal: %d]" % fc)
	return String(" • ").join(parts)


func _emit_and_log(msg: String) -> void:
	emit_signal("tribute_message", msg)
	if has_node("/root/GameDialogueManager"):
		var gm = GameDialogueManager
		var cand_names: Array = ["action_show_text", "action_show_message", "action_add_text", "action_add_line", "show_text", "show_message"]
		for n in cand_names:
			if gm.has_method(n):
				gm.call_deferred(n, msg)
				break
	print("[TributeManager] " + msg)

func emit_status(tribute_id: String) -> void:
	var s: String = get_status_string(tribute_id)
	_emit_and_log(s)


# Payment
func attempt_pay_from_inventory(tribute_id: String) -> String:
	if not tributes.has(tribute_id):
		var errm: String = "Upeti tidak terdaftar."
		_emit_and_log(errm)
		return errm

	var t: Dictionary = tributes[tribute_id]
	var items: Dictionary = t.get("items", {})
	var summary_parts: Array = []
	var any_taken: bool = false

	for item_name in items.keys():
		var info: Dictionary = items[item_name]
		var paid: int = int(info.get("paid", 0))
		var target: int = int(info.get("target", 0))
		var needed: int = max(0, target - paid)
		if needed <= 0:
			continue

		var available: int = 0
		if has_node("/root/InventoryManager"):
			available = InventoryManager.count_collectable(item_name)
		else:
			push_warning("InventoryManager not found; cannot collect item: %s" % item_name)
			available = 0

		if available <= 0:
			continue

		var to_take: int = min(available, needed)
		var removed: int = 0
		if has_node("/root/InventoryManager"):
			removed = InventoryManager.remove_collectable(item_name, to_take)
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
			var tt: Dictionary = tributes[tribute_id]
			tt.fail_count = 0
			tributes[tribute_id] = tt
			if auto_persist:
				_save()
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
		var info = t.items[item_name]
		if int(info.get("paid", 0)) < int(info.get("target", 0)):
			return false
	return true


# Day tick
func _on_day_tick(day: int) -> void:
	var changed: bool = false
	for id in tributes.keys():
		var t: Dictionary = tributes[id]
		var last: int = int(t.get("last_update_day", 0))
		var days_passed: int = int(day) - last
		if days_passed >= DAYS_PER_UPDATE:
			var intervals: int = int(days_passed / DAYS_PER_UPDATE)
			var balloon: Node = balloon_scene.instantiate()
			get_tree().root.add_child(balloon)
			balloon.emotes_panel.hide()
			for i in intervals:
				if not _is_tribute_completed(id):
					for item_name in t.items.keys():
						var info = t.items[item_name]
						info.paid = 0
						t.items[item_name] = info
					var fc: int = int(t.get("fail_count", 0)) + 1
					t.fail_count = fc
					_emit_and_log("Upeti '%s' gagal dipenuhi pada checkpoint. Pembayaran direset ke 0. (Gagal ke-%d)" % [id, fc])

					if fc == 1:
						if balloon.has_method("start"):
							balloon.start(load("res://dialogue/conversations/warning_tribute.dialogue"), "first_warning")
						else:
							push_warning("Balloon scene missing start() method.")
						_emit_and_log("Peringatan pertama untuk upeti '%s' — selesaikan segera." % id)
					elif fc == 2:
						if balloon.has_method("start"):
							balloon.start(load("res://dialogue/conversations/warning_tribute.dialogue"), "second_warning")
						else:
							push_warning("Balloon scene missing start() method.")
						_emit_and_log("Peringatan terakhir untuk upeti '%s' — ini kesempatan terakhir!" % id)
					elif fc >= 3:
						if balloon.has_method("start"):
							balloon.start(load("res://dialogue/conversations/warning_tribute.dialogue"), "execution")
						else:
							push_warning("Balloon scene missing start() method.")
						_emit_and_log("Upeti '%s' gagal dipenuhi sebanyak 3 kali. Menjalankan hukuman..." % id)
						_execute_tribute_penalty(id)
				else:
					if balloon.has_method("start"):
						balloon.start(load("res://dialogue/conversations/warning_tribute.dialogue"), "completed")
					else:
						push_warning("Balloon scene missing start() method.")
					_emit_and_log("Upeti '%s' gagal dipenuhi sebanyak 3 kali. Menjalankan hukuman..." % id)
					t.fail_count = 0

				for item_name in t.items.keys():
					var info2 = t.items[item_name]
					var old_target: int = int(info2.get("target", 0))
					var new_target: int = int(ceil(float(old_target) * (1.0 + INCREASE_RATE)))
					if new_target <= old_target:
						new_target = old_target + 1
					info2.target = new_target
					t.items[item_name] = info2

			t.last_update_day = last + intervals * DAYS_PER_UPDATE
			tributes[id] = t
			changed = true
	if changed:
		if auto_persist:
			_save()


# Execution / penalty
func _execute_tribute_penalty(tribute_id: String) -> void:
	_clear_all_saves()
	_emit_and_log("Hukuman diterapkan untuk upeti '%s'. Semua data permainan dihapus. Game over." % tribute_id)
	emit_signal("tribute_executed", tribute_id)

	var root = get_tree().get_root()
	var gm = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("on_tribute_executed"):
		gm.call_deferred("on_tribute_executed", tribute_id)


# Clear saves (fixed)
func _clear_all_saves() -> void:
	# remove tribute persist
	if FileAccess.file_exists(SAVE_PATH):
		var dir0: DirAccess = DirAccess.open("user://")
		if dir0 != null:
			var filename0: String = SAVE_PATH.get_file()
			var err0: int = dir0.remove(filename0)
			if err0 != OK:
				push_warning("Failed to remove tribute persist file: %s (err %s)" % [SAVE_PATH, str(err0)])
			else:
				print("[TributeManager] Removed persist file: ", SAVE_PATH)

	# remove all saved level files inside user://game_data/
	var save_dir_path: String = "user://game_data"
	if DirAccess.dir_exists_absolute(save_dir_path):
		var dir: DirAccess = DirAccess.open(save_dir_path)
		if dir != null:
			dir.list_dir_begin()
			var fname: String = dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					var fullp: String = save_dir_path + "/" + fname
					var err: int = dir.remove(fname)
					if err != OK:
						push_warning("Failed to remove save file: %s (err %s)" % [fullp, str(err)])
					else:
						print("[TributeManager] Removed save file: ", fullp)
				fname = dir.get_next()
			dir.list_dir_end()
			# Do not attempt to remove the directory itself here to avoid platform-specific issues.
			print("[TributeManager] Finished clearing files in: ", save_dir_path)


# Save / Load (file)
func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for id in tributes.keys():
		var section_name: String = "tributes/" + String(id)
		var t: Dictionary = tributes[id]
		cfg.set_value(section_name, "last_update_day", int(t.get("last_update_day", 0)))
		cfg.set_value(section_name, "fail_count", int(t.get("fail_count", 0)))
		for item_name in t.items.keys():
			var info = t.items[item_name]
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
		var last_val = cfg.get_value(sn, "last_update_day", 0)
		var fail_val = cfg.get_value(sn, "fail_count", 0)
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
			var val = cfg.get_value(sn, key, 0)
			if prop == "target":
				items_struct[item_name].target = int(val)
			elif prop == "paid":
				items_struct[item_name].paid = int(val)
		tributes[id] = {"items": items_struct, "last_update_day": int(last_val), "fail_count": int(fail_val)}
