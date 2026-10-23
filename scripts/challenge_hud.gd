extends RefCounted
## Challenge controls own their hit targets even before the next canvas draw.
const SCORE := Rect2(92, 510, 536, 92)
const SPEED := Rect2(92, 646, 536, 92)
const BACK := Rect2(92, 804, 536, 92)
const REPLAY := Rect2(92, 724, 536, 92)
const CAREER := Rect2(92, 836, 536, 92)
const KEEP := Rect2(92, 630, 536, 92)
const ABANDON := Rect2(92, 742, 536, 92)

static func owns_input(game: Node2D) -> bool:
    return not game.challenge_panel.is_empty() or (game.challenge != null and game.challenge.finished)

static func handle_press(game: Node2D, point: Vector2) -> bool:
    if not owns_input(game):
        return false
    if game.unfocused:
        return true
    if game.challenge_panel == "choose":
        if SCORE.has_point(point):
            game._start_challenge("score_attack")
        elif SPEED.has_point(point):
            game._start_challenge("speedrun")
        elif BACK.has_point(point):
            game._close_challenges()
    elif game.challenge_panel == "abandon" or game.challenge_panel == "restart":
        if KEEP.has_point(point):
            game.challenge_panel = ""
            game.paused = false
            game._stop_input()
        elif ABANDON.has_point(point):
            if game.challenge_panel == "restart":
                game._start_challenge(game.challenge.mode)
            else:
                game._return_to_career()
    elif game.challenge != null and game.challenge.finished:
        if REPLAY.has_point(point):
            game._start_challenge(game.challenge.mode)
        elif CAREER.has_point(point):
            game._return_to_career()
    game.queue_redraw()
    return true

static func _button(game: Node2D, rect: Rect2, label: String, primary: bool = false) -> void:
    game._box(rect, Color("267361") if primary else Color("dce7d4"), 16)
    var width: float = ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 29).x
    game._text(label, rect.position + Vector2((rect.size.x - width) * 0.5, 58), 29, Color.WHITE if primary else Color("263b3b"))

static func time_label(seconds: float) -> String:
    var whole := maxi(0, int(ceil(seconds)))
    return "%d:%02d" % [whole / 60, whole % 60]

static func draw_strip(game: Node2D) -> void:
    if game.challenge == null:
        return
    var run = game.challenge
    game._box(Rect2(20, 171, 680, 96), Color("193e3c"), 14)
    var label := "SCORE ATTACK" if run.mode == "score_attack" else "FASTEST TO MAX"
    var timer := time_label(run.remaining()) if run.mode == "score_attack" else time_label(run.elapsed)
    game._text(label + " · ACTIVE TIME", Vector2(36, 197), 15, Color("c6ded3"))
    game._text(timer, Vector2(36, 245), 39, Color("ffcf68"))
    game._text("%s pts" % int(run.score), Vector2(209, 240), 32, Color.WHITE)
    game._text("x%d streak" % int(run.multiplier()), Vector2(484, 218), 25, Color("ffcf68"))
    game._text("%d served / %d lost" % [run.model.sold, run.lost], Vector2(484, 247), 17, Color("c6ded3"))

static func draw_modal(game: Node2D) -> void:
    if not owns_input(game):
        return
    game._box(Rect2(0, 0, 720, 1280), Color(0.07, 0.17, 0.15, 0.96), 0)
    game._box(Rect2(60, 278, 600, 700), Color("fff7e6"), 24)
    if game.challenge_panel == "choose":
        game._text("CHALLENGES", Vector2(96, 349), 39)
        game._text("Fresh restaurant. Same start for everyone.", Vector2(96, 397), 24)
        game._text("100/order + up to 50 for fast service.", Vector2(96, 432), 23)
        game._text("Every 5 served: multiplier rises, up to x3.", Vector2(96, 465), 21, Color("607467"))
        game._text("Lost customers reset your streak.", Vector2(96, 493), 21, Color("607467"))
        _button(game, SCORE, "Score Attack · 5 minutes", true)
        var score: Dictionary = game.challenge_records.get("score_attack", {})
        var medals: Dictionary = preload("res://scripts/score_challenge.gd").MEDALS
        game._fit_text("Best %d · Bronze %d / Silver %d / Gold %d" % [int(score.get("best_score", 0)), medals.Bronze, medals.Silver, medals.Gold], Vector2(108, 631), 512, 20, Color("607467"))
        _button(game, SPEED, "Fastest to max · Speedrun")
        var speed: Dictionary = game.challenge_records.get("speedrun", {})
        var best := float(speed.get("best_seconds", 0.0))
        game._text("Best: %s · Max upgrades & staff" % (time_label(best) if best > 0 else "No finish yet"), Vector2(108, 770), 21, Color("607467"))
        _button(game, BACK, "Return to career")
        game._text("Career stays safe. Refresh abandons your run.", Vector2(93, 945), 21, Color("607467"))
    elif game.challenge_panel == "abandon" or game.challenge_panel == "restart":
        var restart: bool = game.challenge_panel == "restart"
        game._text("Restart this run?" if restart else "Leave this run?", Vector2(96, 370), 39)
        game._text("This unfinished run won't set a record.", Vector2(96, 434), 25)
        game._text("Your career progress stays unchanged.", Vector2(96, 475), 24)
        _button(game, KEEP, "Keep playing", true)
        _button(game, ABANDON, "Restart challenge" if restart else "Abandon & return to career")
    else:
        var run = game.challenge
        var result: Dictionary = run.result()
        game._text("RUN COMPLETE", Vector2(96, 349), 39)
        var medal := str(result.get("medal", "None"))
        var award := "Bronze at %d · Keep practicing" % preload("res://scripts/score_challenge.gd").MEDALS.Bronze if medal == "None" else medal.to_upper() + " MEDAL"
        game._fit_text("ALL UPGRADES MAXED" if run.mode == "speedrun" else award, Vector2(96, 402), 528, 27, Color("a45b36"))
        game._text(time_label(run.elapsed) + " FINISH" if run.mode == "speedrun" else "%d POINTS" % int(result.get("score", 0)), Vector2(96, 459), 43)
        game._text("%s · %d served · %d lost" % [time_label(run.elapsed), run.model.sold, run.lost], Vector2(96, 504), 24)
        var records: Dictionary = game.challenge_records.get(run.mode, {})
        var best := "Personal best: %d pts" % int(records.get("best_score", 0))
        if run.mode == "speedrun":
            best = "Personal best: %s" % time_label(float(records.get("best_seconds", run.elapsed)))
        game._text(best, Vector2(96, 548), 25, Color("267361"))
        game._text("NEXT RUN", Vector2(96, 593), 19, Color("a45b36"))
        var advice := "Keep the counter stocked to protect your streak."
        if run.lost == 0:
            advice = "Great service! Upgrade your kitchen to serve more."
        game._fit_text(advice, Vector2(96, 630), 528, 23, Color("263b3b"))
        var targets := "Bronze %d · Silver %d · Gold %d" % [preload("res://scripts/score_challenge.gd").MEDALS.Bronze, preload("res://scripts/score_challenge.gd").MEDALS.Silver, preload("res://scripts/score_challenge.gd").MEDALS.Gold]
        game._fit_text("Hire staff early and keep them supplied." if run.mode == "speedrun" else targets, Vector2(96, 666), 528, 21, Color("607467"))
        if not game.challenge_record_saved:
            game._text("Record save unavailable. Keep this tab open.", Vector2(96, 705), 21, Color("a04432"))
        _button(game, REPLAY, "Play again", true)
        _button(game, CAREER, "Return to career")
