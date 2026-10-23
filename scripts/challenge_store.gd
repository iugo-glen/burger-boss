extends RefCounted
## Separate checked, atomic records file. Failed writes preserve live records.
const Challenge = preload("res://scripts/score_challenge.gd")
const DEFAULT_PATH := "user://burger_boss_records.json"
const MEDALS := ["None", "Bronze", "Silver", "Gold"]

static func defaults() -> Dictionary:
    return {"version":1,"score_attack":{"best_score":0,"runs":0,"best_medal":"None"},"speedrun":{"best_seconds":0.0,"runs":0}}

static func _integer(value: Variant, low: int, high: int) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func valid(data: Variant) -> bool:
    if not data is Dictionary or data.get("version") != 1:
        return false
    if not data.get("score_attack") is Dictionary or not data.get("speedrun") is Dictionary:
        return false
    var attack: Dictionary = data.score_attack
    var speed: Dictionary = data.speedrun
    if not _integer(attack.get("best_score"), 0, 1000000000) or not _integer(attack.get("runs"), 0, 1000000000) or not MEDALS.has(attack.get("best_medal")):
        return false
    var expected_medal := "None"
    for name in ["Gold", "Silver", "Bronze"]:
        if attack.best_score >= Challenge.MEDALS[name]:
            expected_medal = name
            break
    if attack.best_medal != expected_medal or (attack.runs == 0 and attack.best_score != 0):
        return false
    var seconds: Variant = speed.get("best_seconds")
    if not (seconds is float or seconds is int) or not is_finite(float(seconds)):
        return false
    if (speed.get("runs", 0) == 0) != (float(seconds) == 0.0):
        return false
    return _integer(speed.get("runs"), 0, 1000000000) and (seconds is float or seconds is int) and is_finite(float(seconds)) and float(seconds) >= 0.0 and float(seconds) <= 1000000000.0

static func load_records(path: String = DEFAULT_PATH) -> Dictionary:
    if not FileAccess.file_exists(path):
        return defaults()
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > 4096:
        return defaults()
    var payload := file.get_as_text()
    var readable := file.get_error() == OK
    file.close()
    if not readable:
        return defaults()
    var parser := JSON.new()
    if parser.parse(payload) != OK or not valid(parser.data):
        return defaults()
    return parser.data

static func record_result(records: Dictionary, result: Dictionary, path: String = DEFAULT_PATH) -> bool:
    if not valid(records) or result.get("completed") != true or not result.get("mode") in ["score_attack", "speedrun"]:
        return false
    var next := records.duplicate(true)
    if result.mode == "score_attack":
        if not _integer(result.get("score"), 0, 1000000000) or result.get("elapsed") != 300.0 or not MEDALS.has(result.get("medal")):
            return false
        var expected := "None"
        for name in ["Gold", "Silver", "Bronze"]:
            if result.score >= Challenge.MEDALS[name]:
                expected = name
                break
        if result.medal != expected:
            return false
        next.score_attack.runs += 1
        next.score_attack.best_score = maxi(int(next.score_attack.best_score), int(result.score))
        if MEDALS.find(result.medal) > MEDALS.find(next.score_attack.best_medal):
            next.score_attack.best_medal = result.medal
    else:
        var seconds: Variant = result.get("elapsed")
        if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or float(seconds) <= 0.0:
            return false
        next.speedrun.runs += 1
        if next.speedrun.best_seconds == 0.0 or seconds < next.speedrun.best_seconds:
            next.speedrun.best_seconds = float(seconds)
    if not valid(next) or not _save(next, path):
        return false
    records.clear()
    records.merge(next, true)
    return true

static func _save(records: Dictionary, path: String) -> bool:
    var temporary := path + ".tmp"
    var payload := JSON.stringify(records)
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    file.flush()
    var complete := file.get_error() == OK and file.get_length() == payload.to_utf8_buffer().size()
    file.close()
    if not complete or DirAccess.rename_absolute(temporary, path) != OK:
        DirAccess.remove_absolute(temporary)
        return false
    return true
