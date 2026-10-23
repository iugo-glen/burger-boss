extends RefCounted
## Commit a complete save before replacing either persisted or live progress.
const Restaurant = preload("res://scripts/restaurant.gd")
const DEFAULT_PATH := "user://burger_boss.json"

static func save(model: RefCounted, path: String = DEFAULT_PATH) -> bool:
    # Same-directory rename commits the replacement without truncating the old
    # primary save if opening, writing, flushing, or committing the new one fails.
    var temporary := path + ".tmp"
    var payload := JSON.stringify(model.snapshot())
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(payload)
    file.flush()
    var complete := file.get_error() == OK and file.get_length() == payload.to_utf8_buffer().size()
    file.close()
    if not complete:
        DirAccess.remove_absolute(temporary)
        return false
    if DirAccess.rename_absolute(temporary, path) != OK:
        DirAccess.remove_absolute(temporary)
        return false
    return true

static func reset_progress(path: String = DEFAULT_PATH) -> RefCounted:
    # The caller swaps its model only after this returns a persisted candidate.
    # A failed reset cannot mutate the old model or remove its previous save.
    var fresh := Restaurant.new()
    return fresh if save(fresh, path) else null

static func load_into(model: RefCounted, path: String = DEFAULT_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > 65536:
        return false
    var payload := file.get_as_text()
    var readable := file.get_error() == OK
    file.close()
    if not readable:
        return false
    var parser := JSON.new()
    if parser.parse(payload) != OK:
        return false
    return model.restore(parser.data)
