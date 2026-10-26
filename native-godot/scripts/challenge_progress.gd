extends RefCounted
## Offline, deterministic progression for Jelly sculpture challenges.
## A completion rewards XP once. Replays may improve personal best and
## stars but cannot infinitely farm the same level for XP.
const PATH := "user://jelly-sculpture-progress-v1.json"
const TEMP_PATH := PATH + ".tmp"
const BACKUP_PATH := PATH + ".bak"

static func fresh() -> Dictionary:
    return {"schema": 1, "unlocked": 0, "completed": {}, "xp": 0}

static func compare(entries: Array[Dictionary], target: Dictionary) -> Dictionary:
    var actual: Dictionary = {}
    for piece in entries:
        var row: int = int(piece["row"])
        var col: int = int(piece["col"])
        var layer: int = int(piece["layer"])
        var length: int = int(piece["length"]) + 1
        var turned: bool = posmod(int(piece["turns"]), 2) != 0
        for k in range(length):
            var at: String = "%d:%d:%d" % [
                row + (k if turned else 0),
                col + (0 if turned else k), layer]
            actual[at] = int(piece["color"])
    var target_cells: Dictionary = target["cells"]
    var matched := 0
    var wrong := 0
    for key in actual:
        if target_cells.has(key) and actual[key] == target_cells[key]:
            matched += 1
        else:
            wrong += 1
    return {
        "matched": matched, "required": target_cells.size(),
        "wrong": wrong, "missing": target_cells.size() - matched,
        "complete": wrong == 0 and matched == target_cells.size(),
        "percent": roundi(100.0 * float(matched) /
            maxf(1.0, float(target_cells.size())))
    }

static func rank(xp: int) -> int:
    return int(floor(sqrt(float(maxi(xp, 0)) / 100.0))) + 1

static func award(target: Dictionary, moves: int, undos: int,
        seconds: int) -> Dictionary:
    var par: int = int(target["par_bricks"])
    var stars: int = 1
    if moves <= par + 2:
        stars += 1
    if moves <= par and undos <= 1:
        stars += 1
    var score: int = 600 + int(target["difficulty"]) * 150 + \
        maxi(0, par - moves) * 65 + maxi(0, 300 - seconds * 3) + \
        maxi(0, 100 - undos * 25) + stars * 75
    var xp: int = 40 + int(target["difficulty"]) * 20 + stars * 25
    return {"score": score, "stars": stars, "xp": xp}

static func claim(progress: Dictionary, target: Dictionary,
        reward: Dictionary) -> Dictionary:
    var id: int = int(target["id"])
    var completed: Dictionary = progress["completed"]
    var key: String = str(id)
    var previous: Dictionary = completed.get(key, {})
    var first_time: bool = previous.is_empty()
    var new_record: bool = int(reward["score"]) > int(
        previous.get("score", -1))
    var best_stars: int = maxi(int(previous.get("stars", 0)),
        int(reward["stars"]))
    completed[key] = {
        "score": maxi(int(previous.get("score", 0)), int(reward["score"])),
        "stars": best_stars,
        "xp": int(reward["xp"]) if first_time else int(previous.get("xp", 0))
    }
    if first_time:
        progress["xp"] = int(progress["xp"]) + int(reward["xp"])
    progress["unlocked"] = mini(19,
        maxi(int(progress["unlocked"]), id + 1))
    return {
        "first": first_time, "record": new_record,
        "earned_xp": int(reward["xp"]) if first_time else 0,
        "total_xp": int(progress["xp"]), "rank": rank(int(progress["xp"])),
        "stars": best_stars
    }

static func share_message(target: Dictionary, reward: Dictionary,
        profile: Dictionary) -> String:
    return "Jelly Bricks 🧩 Niveau %d/20 : %s (%s) ! %d points · %s étoiles · XP %d · Rang %d. À toi de reproduire la figure ! #JellyBricks" % [
        int(target["id"]) + 1, String(target["title"]),
        String(target["category"]), int(reward["score"]),
        str(reward["stars"]) + "/3", int(profile["xp"]),
        rank(int(profile["xp"]))]

## Godot JSON.parse_string turns all JSON numbers into FLOAT even when
## their values are mathematically integers. Never require `is int` on
## reloaded progress; normalize bounded exact integers and reject NaN,
## infinity, fractions, strings and out-of-range payloads instead.
static func _valid_whole(value: Variant, low: int, high: int) -> bool:
    if not (value is int or value is float):
        return false
    var v: float = float(value)
    return v >= float(low) and v <= float(high) and \
        absf(v - roundf(v)) < .0001

static func _verified(record: Variant) -> Dictionary:
    if not record is Dictionary \
            or not _valid_whole(record.get("schema"), 1, 1) \
            or not _valid_whole(record.get("unlocked"), 0, 19) \
            or not _valid_whole(record.get("xp"), 0, 10000000) \
            or not record.get("completed") is Dictionary:
        return {}
    var unlocked: int = int(roundf(float(record["unlocked"])))
    var xp: int = int(roundf(float(record["xp"])))
    var best: Dictionary = {}
    for key in record["completed"]:
        var idx: String = str(key)
        if not idx.is_valid_int() or int(idx) < 0 or int(idx) >= 20:
            return {}
        var achievement: Variant = record["completed"][key]
        if not achievement is Dictionary \
                or not _valid_whole(achievement.get("score"), 0, 1000000) \
                or not _valid_whole(achievement.get("stars"), 1, 3) \
                or not _valid_whole(achievement.get("xp"), 0, 10000):
            return {}
        best[idx] = {
            "score": int(roundf(float(achievement["score"]))),
            "stars": int(roundf(float(achievement["stars"]))),
            "xp": int(roundf(float(achievement["xp"])))
        }
    return {"schema": 1, "unlocked": unlocked,
        "completed": best, "xp": xp}

static func _load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(path))
    return _verified(parsed)

static func load_profile() -> Dictionary:
    for path in [PATH, BACKUP_PATH]:
        var record: Dictionary = _load_file(path)
        if not record.is_empty():
            return record
    return fresh()

static func save_profile(profile: Dictionary) -> bool:
    if _verified(profile).is_empty():
        return false
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(profile))
    file.flush()
    var flush_status: Error = file.get_error()
    file.close()
    if flush_status != OK or _load_file(TEMP_PATH).is_empty():
        DirAccess.remove_absolute(TEMP_PATH)
        return false
    if not _load_file(PATH).is_empty() and \
            DirAccess.copy_absolute(PATH, BACKUP_PATH) != OK:
        DirAccess.remove_absolute(TEMP_PATH)
        return false
    if DirAccess.rename_absolute(TEMP_PATH, PATH) != OK:
        DirAccess.remove_absolute(TEMP_PATH)
        return false
    return true
