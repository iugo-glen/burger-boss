extends RefCounted
## Validate before committing state. Bad or truncated saves leave a fresh playable game.
const DEFAULT_PATH := "user://burger_boss.json"
static func save(model: RefCounted, path: String = DEFAULT_PATH) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(model.snapshot()))
    file.flush()
    return file.get_error() == OK

static func load_into(model: RefCounted, path: String = DEFAULT_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > 65536:
        return false
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return false
    return model.restore(parser.data)
