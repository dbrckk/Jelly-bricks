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

static func reward(index: int, brick_count: int) -> Dictionary:
    var level := index + 1
    var base := 100 + level * 25
    var efficiency := maxi(0, 40 - brick_count * 2)
    var score := base + efficiency
    return {"score": score, "xp": 35 + level * 10,
        "stars": 3 if brick_count <= 12 else (2 if brick_count <= 22 else 1)}

static func load_progress() -> Dictionary:
    var empty := {"unlocked": 0, "total_score": 0, "xp": 0, "best": {}}
    if not FileAccess.file_exists(SAVE):
        return empty
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    if not parsed is Dictionary:
        return empty
    var progress: Dictionary = parsed
    if not progress.get("best", {}) is Dictionary:
        return empty
    progress["unlocked"] = clampi(int(progress.get("unlocked", 0)), 0, 19)
    progress["total_score"] = maxi(0, int(progress.get("total_score", 0)))
    progress["xp"] = maxi(0, int(progress.get("xp", 0)))
    return progress

static func save_progress(progress: Dictionary) -> bool:
    var file := FileAccess.open(SAVE, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(progress))
    file.flush()
    file.close()
    return true

static func grant(progress: Dictionary, index: int, brick_count: int) -> Dictionary:
    var reward_data := reward(index, brick_count)
    var key := str(index)
    var best: Dictionary = progress.get("best", {})
    var previous: int = int(best.get(key, 0))
    var earned: int = maxi(0, int(reward_data["score"]) - previous)
    best[key] = maxi(previous, int(reward_data["score"]))
    progress["best"] = best
    progress["total_score"] = int(progress.get("total_score", 0)) + earned
    if previous == 0:
        progress["xp"] = int(progress.get("xp", 0)) + int(reward_data["xp"])
    progress["unlocked"] = maxi(int(progress.get("unlocked", 0)),
        mini(index + 1, CHALLENGES.size() - 1))
    return {"earned": earned, "first_win": previous == 0,
        "reward": reward_data, "progress": progress}
