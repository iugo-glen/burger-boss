extends RefCounted
## Hit testing is independent of the last draw, so a newly opened modal owns input immediately.
const HEADER_PAUSE := Rect2(620, 8, 82, 82)
const RESUME := Rect2(112, 548, 496, 92)
const CHALLENGES := Rect2(112, 772, 496, 92)
const START_OVER := Rect2(112, 660, 496, 92)
const CANCEL := Rect2(92, 650, 536, 92)
const ERASE := Rect2(92, 770, 536, 92)

static func handle_press(game: Node2D, point: Vector2) -> bool:
    if game.reset_confirm_visible:
        if not game.unfocused:
            if CANCEL.has_point(point):
                game._cancel_reset()
            elif ERASE.has_point(point):
                game._confirm_reset()
        return true
    if not game.paused and not game.unfocused:
        return false
    if not game.unfocused:
        if RESUME.has_point(point) or HEADER_PAUSE.has_point(point):
            game._toggle_pause()
        elif START_OVER.has_point(point):
            game._open_reset()
        elif CHALLENGES.has_point(point):
            game._open_challenges()
    return true

static func _button(game: Node2D, rect: Rect2, label: String, fill: Color, ink: Color) -> void:
    game._box(rect, fill, 16)
    var width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 29).x
    game._text(label, rect.position + Vector2((rect.size.x - width) * 0.5, 58), 29, ink)

static func draw(game: Node2D) -> void:
    if not game.paused and not game.unfocused and not game.reset_confirm_visible:
        return
    game._box(Rect2(0, 0, 720, 1280), Color(0.07, 0.17, 0.15, 0.9), 0)
    if game.reset_confirm_visible:
        game._box(Rect2(60, 300, 600, 640), Color("fff7e6"), 24)
        game._text("Start over?", Vector2(96, 397), 40)
        game._text("This erases your restaurant on this device:", Vector2(96, 449), 23)
        game._text("money, staff, upgrades and rush rank.", Vector2(96, 483), 23)
        game._text("Other devices are unaffected.", Vector2(96, 523), 23)
        game._text("You can't undo this.", Vector2(96, 563), 24, Color("a04432"))
        if not game.reset_error.is_empty():
            game._text("Could not save a fresh start.", Vector2(96, 603), 23, Color("a04432"))
            game._text("Your restaurant is unchanged. Try again.", Vector2(96, 632), 21, Color("a04432"))
        _button(game, CANCEL, "Cancel", Color("dce7d4"), Color("263b3b"))
        _button(game, ERASE, "Erase & start over", Color("b64935"), Color.WHITE)
        game._text("No changes until you confirm.", Vector2(176, 903), 21, Color("607467"))
    else:
        game._box(Rect2(80, 390, 560, 550), Color("fff7e6"), 24)
        game._text("PAUSED", Vector2(272, 470), 40)
        game._text("Challenge paused · career protected" if game.challenge != null else "Your restaurant is safely paused.", Vector2(151, 515), 23)
        _button(game, RESUME, "Resume", Color("267361"), Color.WHITE)
        _button(game, START_OVER, "Restart challenge" if game.challenge != null else "Start over", Color("e9dcc6"), Color("a04432"))
        _button(game, CHALLENGES, "Return to career" if game.challenge != null else "Challenges", Color("dce7d4"), Color("263b3b"))
        var failed: bool = game.save_status.begins_with("Career save failed")
        game._text("Career save failed. Challenge not started." if failed else "Challenge records are saved separately.", Vector2(133, 910), 21, Color("a04432") if failed else Color("607467"))
        # Keep the existing header resume control available alongside the explicit menu.
        game._box(HEADER_PAUSE, Color("2e5850"))
        game._text(">", Vector2(651, 60), 29, Color.WHITE)
