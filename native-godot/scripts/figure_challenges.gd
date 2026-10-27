extends RefCounted
## Twenty hand-authored 6x6 pixel sculptures using the REAL 3D Jelly bricks.
## Each digit is a studio palette index (0..4), dot is an empty cell.
## No procedural impossible targets, downloads or paid assets.
const CHALLENGES := [
    {"name":"Coeur", "family":"Formes", "rows":["......",".0..0.","000000","000000",".0000.","..00.."]},
    {"name":"Fleur", "family":"Nature", "rows":["..2...","..2...","11211.","11111.","..2...","..2..."]},
    {"name":"Étoile", "family":"Formes", "rows":["..3...","..3...", "333333",".3333.","3.3.3.","......"]},
    {"name":"Poisson", "family":"Animaux", "rows":["......",".1114.","111111","111111",".1114.","......"]},
    {"name":"Papillon", "family":"Animaux", "rows":["0.22.0","00..00",".0330.",".0330.","00..00","0.22.0"]},
    {"name":"Maison", "family":"Objets", "rows":["..00..",".0000.","000000","111111","11..11","111111"]},
    {"name":"Arbre", "family":"Nature", "rows":["..22..",".2222.","222222",".2222.","..33..","..33.."]},
    {"name":"Chat", "family":"Animaux", "rows":["1....1","11..11","111111","13..31","111111",".1111."]},
    {"name":"Soleil", "family":"Nature", "rows":["3..3.3",".3333.","333333","333333",".3333.","3..3.3"]},
    {"name":"Tortue", "family":"Animaux", "rows":["......",".2222.","222222","222222",".2..2.","......"]},
    {"name":"Fusée", "family":"Objets", "rows":["..00..",".0000.",".0110.",".0110.","301103","3....3"]},
    {"name":"Lapin", "family":"Animaux", "rows":[".1..1.",".1..1.",".1111.","111111","11.311",".1111."]},
    {"name":"Champignon", "family":"Nature", "rows":[".0000.","000000","030030",".3333.","..33..","..33.."]},
    {"name":"Oiseau", "family":"Animaux", "rows":["......","....3.","111133","111111",".1111.","..11.."]},
    {"name":"Couronne", "family":"Objets", "rows":["3.3.3.","333333","333333",".3333.",".3333.","......"]},
    {"name":"Renard", "family":"Animaux", "rows":["4....4","44..44","444444","43..34",".4444.","..44.."]},
    {"name":"Grenouille", "family":"Animaux", "rows":["22..22","222222","232232","222222",".2222.","2....2"]},
    {"name":"Pingouin", "family":"Animaux", "rows":[".1111.","111111","110011","110011","111111",".3..3."]},
    {"name":"Dragon", "family":"Animaux", "rows":["..2222","222222","232222",".2222.",".2.22.","2...22"]},
    {"name":"Licorne", "family":"Animaux", "rows":["...3..","..333.",".0000.","011110","011110",".1..1."]}
]
const SAVE := "user://jelly-figures-progress-v1.json"

static func target(index: int) -> Dictionary:
    return CHALLENGES[clampi(index, 0, CHALLENGES.size() - 1)]

static func validate_catalog() -> bool:
    if CHALLENGES.size() != 20:
        return false
    var names := {}
    for challenge in CHALLENGES:
        var title: String = challenge["name"]
        var rows: Array = challenge["rows"]
        if names.has(title) or rows.size() != 6:
            return false
        names[title] = true
        var filled := 0
        for row in rows:
            if String(row).length() != 6:
                return false
            for character in String(row):
                if character != "." and (character < "0" or character > "4"):
                    return false
                if character != ".":
                    filled += 1
        if filled < 5 or filled > 32:
            return false
    return true

static func evaluate(index: int, entries: Array) -> Dictionary:
    var challenge: Dictionary = target(index)
    var rows: Array = challenge["rows"]
    var actual := {}
    var invalid := false
    for entry in entries:
        var length_index: int = int(entry.get("length", -1))
        var length: int = length_index + 1
        var turns: int = int(entry.get("turns", 0))
        var layer: int = int(entry.get("layer", -1))
        var color: int = int(entry.get("color", -1))
        if length < 1 or length > 3 or layer != 0 or color < 0 or color > 4:
            invalid = true
            continue
        for offset in range(length):
            var row: int = int(entry.get("row", -1)) + (offset if turns % 2 == 1 else 0)
            var col: int = int(entry.get("col", -1)) + (offset if turns % 2 == 0 else 0)
            if row < 0 or row >= 6 or col < 0 or col >= 6:
                invalid = true
                continue
            var key := Vector2i(row, col)
            if actual.has(key):
                invalid = true
            actual[key] = color
    var correct := 0
    var required := 0
    var wrong := 0
    for row in range(6):
        for col in range(6):
            var symbol: String = String(rows[row]).substr(col, 1)
            var key := Vector2i(row, col)
            if symbol == ".":
                if actual.has(key):
                    wrong += 1
            else:
                required += 1
                if actual.has(key) and int(actual[key]) == int(symbol):
                    correct += 1
                elif actual.has(key):
                    wrong += 1
    var won: bool = not invalid and wrong == 0 and correct == required
    return {"won": won, "correct": correct, "required": required,
        "wrong": wrong, "accuracy": float(correct) / float(maxi(1, required))}

## Friendly labels are not just decorative: the campaign's complexity
## rises through colors, occupancy and placement-efficiency goals.
static func difficulty(index: int) -> String:
    return "Découverte" if index < 6 else (
        "Intermédiaire" if index < 13 else "Expert")

## Achievable par: choose whichever of row-wise or column-wise continuous
## runs of identical colors requires fewer 1/2/3-cell bricks. This is an
## actual legal build, unlike arbitrary thresholds that made 3 stars
## impossible on the old 24–32-cell animal silhouettes.
static func par_bricks(index: int) -> int:
    var rows: Array = target(index)["rows"]
    var horizontal := 0
    var vertical := 0
    for direction in range(2):
        var count := 0
        for main in range(6):
            var previous := "."
            var run := 0
            for secondary in range(7):
                var symbol := "." if secondary == 6 else (
                    String(rows[main]).substr(secondary, 1) if direction == 0
                    else String(rows[secondary]).substr(main, 1))
                if symbol != previous:
                    if previous != ".":
                        count += ceili(float(run) / 3.0)
                    run = 0
                if symbol != ".":
                    run += 1
                previous = symbol
        if direction == 0:
            horizontal = count
        else:
            vertical = count
    return mini(horizontal, vertical)

static func reward(index: int, brick_count: int) -> Dictionary:
    var level: int = index + 1
    var par: int = par_bricks(index)
    var score := 100 + 25 * level + maxi(0,
        (par + 6 - brick_count) * 10)
    return {"score": score, "xp": 35 + level * 10, "par": par,
        "stars": 3 if brick_count <= par else (
            2 if brick_count <= par + 3 else 1)}

## Cosmetic mastery tiers never modify puzzle scoring or unlock gates.
static func mastery(xp: int) -> Dictionary:
    var thresholds := [0, 250, 750, 1750, 3500]
    var titles := ["Novice", "Apprenti", "Sculpteur", "Maître gelée", "Artiste Jelly"]
    var rank := 0
    for i in range(thresholds.size()):
        if xp >= thresholds[i]:
            rank = i
    var next_xp := -1 if rank == thresholds.size() - 1 else thresholds[rank + 1]
    return {"title": titles[rank], "rank": rank + 1,
        "next_xp": next_xp, "xp": maxi(0, xp)}

static func collection_summary(progress: Dictionary) -> Dictionary:
    var best: Dictionary = progress.get("best", {})
    var stars: Dictionary = progress.get("stars", {})
    var completed := 0
    var earned_stars := 0
    for index in range(CHALLENGES.size()):
        var key := str(index)
        if int(best.get(key, 0)) > 0:
            completed += 1
            earned_stars += clampi(int(stars.get(key, 0)), 0, 3)
    return {"completed": completed, "stars": earned_stars,
        "max_stars": CHALLENGES.size() * 3,
        "score": maxi(0, int(progress.get("total_score", 0))),
        "mastery": mastery(int(progress.get("xp", 0)))}

static func fresh_progress() -> Dictionary:
    return {"unlocked": 0, "active": 0, "total_score": 0,
        "xp": 0, "best": {}, "stars": {}, "sessions": {}}

static func _read_progress(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        return {}
    var data: Dictionary = parsed
    for field in ["best", "stars", "sessions"]:
        if data.has(field) and not data[field] is Dictionary:
            return {}
    var normalized := fresh_progress()
    normalized["unlocked"] = clampi(int(data.get("unlocked", 0)), 0, 20)
    normalized["active"] = clampi(int(data.get("active", 0)), 0,
        mini(19, int(normalized["unlocked"])))
    normalized["total_score"] = maxi(0, int(data.get("total_score", 0)))
    normalized["xp"] = maxi(0, int(data.get("xp", 0)))
    normalized["best"] = data.get("best", {}).duplicate(true)
    normalized["stars"] = data.get("stars", {}).duplicate(true)
    normalized["sessions"] = data.get("sessions", {}).duplicate(true)
    return normalized

static func load_progress() -> Dictionary:
    for path in [SAVE, SAVE + ".bak"]:
        var valid: Dictionary = _read_progress(path)
        if not valid.is_empty():
            return valid
    return fresh_progress()

## Transactional autosave: sessions are checkpointed on every placement
## and Undo. A crash between temp write and atomic rename can recover
## from the prior backup without affecting the free studio's separate
## mature transactional save.
static func save_progress(progress: Dictionary) -> bool:
    var temp_path := SAVE + ".tmp"
    var backup_path := SAVE + ".bak"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(progress))
    file.flush()
    file.close()
    if _read_progress(temp_path).is_empty():
        return false
    var backup_abs: String = ProjectSettings.globalize_path(backup_path)
    var save_abs: String = ProjectSettings.globalize_path(SAVE)
    var temp_abs: String = ProjectSettings.globalize_path(temp_path)
    var backed_up := false
    if FileAccess.file_exists(SAVE):
        if FileAccess.file_exists(backup_path) and \
                DirAccess.remove_absolute(backup_abs) != OK:
            return false
        if DirAccess.rename_absolute(save_abs, backup_abs) != OK:
            return false
        backed_up = true
    if DirAccess.rename_absolute(temp_abs, save_abs) != OK:
        if backed_up:
            DirAccess.rename_absolute(backup_abs, save_abs)
        return false
    return true

static func grant(progress: Dictionary, index: int, brick_count: int) -> Dictionary:
    var reward_data: Dictionary = reward(index, brick_count)
    var key := str(index)
    var best: Dictionary = progress.get("best", {})
    var stars: Dictionary = progress.get("stars", {})
    var previous: int = int(best.get(key, 0))
    var earned: int = maxi(0, int(reward_data["score"]) - previous)
    best[key] = maxi(previous, int(reward_data["score"]))
    stars[key] = maxi(int(stars.get(key, 0)), int(reward_data["stars"]))
    progress["best"] = best
    progress["stars"] = stars
    progress["total_score"] = int(progress.get("total_score", 0)) + earned
    if previous == 0:
        progress["xp"] = int(progress.get("xp", 0)) + int(reward_data["xp"])
    progress["unlocked"] = maxi(int(progress.get("unlocked", 0)),
        mini(index + 1, CHALLENGES.size()))
    return {"earned": earned, "first_win": previous == 0,
        "reward": reward_data, "progress": progress}
