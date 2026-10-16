extends RefCounted
## Portable, strictly validated Jelly Bricks Android progress backups.
## Uses only built-in Godot 4.6 APIs, including Android SAF content URIs.
const FORMAT := "jelly-bricks-native-backup"
const VERSION := 1
const MAX_BYTES := 2 * 1024 * 1024

static func encode(progress: Dictionary) -> String:
    var payload := JSON.stringify(progress)
    return JSON.stringify({
        "kind": FORMAT, "version": VERSION, "progress": progress,
        "sha256": payload.sha256_text()
    })

static func decode(content: String, levels: Array) -> Dictionary:
    if content.to_utf8_buffer().size() > MAX_BYTES:
        return {"ok": false, "reason": "Fichier trop volumineux"}
    var parser := JSON.new()
    if parser.parse(content) != OK or not parser.data is Dictionary:
        return {"ok": false, "reason": "Fichier JSON illisible"}
    var envelope: Dictionary = parser.data
    if envelope.get("kind") != FORMAT or envelope.get("version") != VERSION:
        return {"ok": false, "reason": "Format de sauvegarde non reconnu"}
    var progress: Variant = envelope.get("progress")
    if not progress is Dictionary or not envelope.get("sha256") is String:
        return {"ok": false, "reason": "Données de sauvegarde manquantes"}
    if JSON.stringify(progress).sha256_text() != envelope["sha256"]:
        return {"ok": false, "reason": "Sauvegarde altérée (SHA-256)"}
    return validate_progress(progress, levels)

static func _valid_integer(value: Variant, low: int, high: int) -> bool:
    if not (value is int or value is float):
        return false
    var n: float = float(value)
    return n >= float(low) and n <= float(high) and n == float(int(value))

static func _level_board(level: Dictionary) -> Dictionary:
    var board_size: int = int(level.get("size", 0))
    var rows: Variant = level.get("rows", [])
    if board_size < 1 or board_size > 12 or not rows is Array \
            or rows.size() != board_size:
        return {}
    var wanted: Dictionary = {}
    var shapes: Dictionary = {}
    for r in range(board_size):
        var line: String = String(rows[r])
        if line.length() != board_size:
            return {}
        for c in range(board_size):
            var id: String = line.substr(c, 1)
            if id == ".":
                continue
            var cell := Vector2i(r, c)
            wanted[cell] = id
            if not shapes.has(id):
                shapes[id] = []
            shapes[id].append(cell)
    for id in shapes:
        var low_row: int = board_size
        var low_col: int = board_size
        for cell in shapes[id]:
            low_row = mini(low_row, cell.x)
            low_col = mini(low_col, cell.y)
        var normalized: Array = []
        for cell in shapes[id]:
            normalized.append(cell - Vector2i(low_row, low_col))
        shapes[id] = normalized
    return {"wanted": wanted, "shapes": shapes, "size": board_size}

static func _rotated(cells: Array, turns: int) -> Array:
    var rotated: Array = cells.duplicate()
    for _i in range(turns):
        var shifted: Array = []
        for p in rotated:
            shifted.append(Vector2i(p.y, -p.x))
        var low_r: int = 999
        var low_c: int = 999
        for p in shifted:
            low_r = mini(low_r, p.x)
            low_c = mini(low_c, p.y)
        rotated.clear()
        for p in shifted:
            rotated.append(p - Vector2i(low_r, low_c))
    return rotated

static func _validate_placements(raw: Variant, board: Dictionary) -> Dictionary:
    var shapes: Dictionary = board["shapes"]
    var wanted: Dictionary = board["wanted"]
    if not raw is Dictionary or raw.size() > shapes.size():
        return {"ok": false}
    var used: Dictionary = {}
    var clean: Dictionary = {}
    for id in raw:
        if not id is String or not shapes.has(id) or not raw[id] is Dictionary:
            return {"ok": false}
        var pose: Dictionary = raw[id]
        if not _valid_integer(pose.get("row"), 0, board["size"] - 1) \
                or not _valid_integer(pose.get("col"), 0, board["size"] - 1) \
                or not _valid_integer(pose.get("turns"), 0, 3):
            return {"ok": false}
        var at := Vector2i(int(pose["row"]), int(pose["col"]))
        var turns: int = int(pose["turns"])
        for cell in _rotated(shapes[id], turns):
            var world: Vector2i = at + cell
            if not wanted.has(world) or used.has(world):
                return {"ok": false}
            used[world] = true
        clean[id] = {"row": at.x, "col": at.y, "turns": turns}
    return {"ok": true, "placements": clean}

static func _validate_session(raw: Variant, level_index: int, board: Dictionary) -> Dictionary:
    if not raw is Dictionary or not _valid_integer(raw.get("level"), level_index, level_index):
        return {"ok": false}
    var current: Dictionary = _validate_placements(raw.get("placements", {}), board)
    if not current.get("ok", false):
        return {"ok": false}
    var history: Variant = raw.get("undo_history", [])
    if not history is Array or history.size() > 64:
        return {"ok": false}
    var clean_history: Array = []
    for snapshot in history:
        var validated: Dictionary = _validate_placements(snapshot, board)
        if not validated.get("ok", false):
            return {"ok": false}
        clean_history.append(validated["placements"])
    if not _valid_integer(raw.get("selected_turns", 0), 0, 3) \
            or not _valid_integer(raw.get("moves", 0), 0, 1000000):
        return {"ok": false}
    var selected: Variant = raw.get("selected_id", "")
    if not selected is String or (selected != "" and not board["shapes"].has(selected)):
        return {"ok": false}
    return {"ok": true, "session": {
        "level": level_index,
        "placements": current["placements"],
        "undo_history": clean_history,
        "selected_id": selected,
        "selected_turns": int(raw.get("selected_turns", 0)),
        "moves": maxi(int(raw.get("moves", 0)), current["placements"].size())
    }}

static func validate_progress(progress: Dictionary, levels: Array) -> Dictionary:
    if levels.is_empty() or progress.get("format") != 2:
        return {"ok": false, "reason": "Version de progression incompatible"}
    if not _valid_integer(progress.get("unlocked"), 0, levels.size() - 1):
        return {"ok": false, "reason": "Niveaux débloqués invalides"}
    var unlocked: int = int(progress["unlocked"])
    if not _valid_integer(progress.get("level"), 0, unlocked):
        return {"ok": false, "reason": "Niveau actif invalide"}
    if not progress.get("feedback_enabled") is bool:
        return {"ok": false, "reason": "Réglages invalides"}
    var entries: Variant = progress.get("sessions")
    if not entries is Dictionary or entries.size() > levels.size():
        return {"ok": false, "reason": "Sessions invalides"}
    var validated_sessions: Dictionary = {}
    for raw_key in entries:
        if not raw_key is String or not raw_key.is_valid_int():
            return {"ok": false, "reason": "Identifiant de niveau invalide"}
        var idx: int = int(raw_key)
        if idx < 0 or idx > unlocked or idx >= levels.size() or raw_key != str(idx):
            return {"ok": false, "reason": "Niveau de session hors progression"}
        var board: Dictionary = _level_board(levels[idx])
        if board.is_empty():
            return {"ok": false, "reason": "Modèle de niveau indisponible"}
        var clean: Dictionary = _validate_session(entries[raw_key], idx, board)
        if not clean.get("ok", false):
            return {"ok": false, "reason": "Placement ou annulation invalide au niveau %d" % (idx + 1)}
        validated_sessions[raw_key] = clean["session"]
    var current: int = int(progress["level"])
    var active: Dictionary = validated_sessions.get(str(current), {})
    return {"ok": true, "progress": {
        "format": 2,
        "unlocked": unlocked,
        "level": current,
        "feedback_enabled": progress["feedback_enabled"],
        "sessions": validated_sessions,
        "session": active
    }}
