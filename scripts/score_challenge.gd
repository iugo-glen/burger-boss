extends RefCounted
## Fresh, deterministic sessions. Only supplied active simulation time counts.
const Restaurant = preload("res://scripts/restaurant.gd")
const DURATION := 300.0
const MEDALS := {"Bronze":8000,"Silver":20000,"Gold":35000}
var model := Restaurant.new()
var mode := "score_attack"
var elapsed := 0.0
var finished := false
var score := 0
var streak := 0
var best_streak := 0
var best_multiplier := 1
var lost := 0

func _init(selected_mode: String = "score_attack") -> void:
    mode = selected_mode if selected_mode in ["score_attack", "speedrun"] else "score_attack"
    model.challenge_patience = true
    model.sale_completed.connect(_on_sale)
    model.customer_abandoned.connect(_on_abandoned)

func remaining() -> float:
    return maxf(0.0, DURATION - elapsed) if mode == "score_attack" else 0.0

func multiplier() -> int:
    return mini(3, 1 + maxi(0, streak - 1) / 5)

func step(delta: float) -> void:
    if finished or not is_finite(delta) or delta <= 0.0:
        return
    # Match restaurant substeps, observing completion after every simulation tick.
    var pending := minf(delta, remaining()) if mode == "score_attack" else minf(delta, 60.0)
    while pending > 0.0 and not finished:
        var dt := minf(0.1, pending)
        model.step(dt)
        elapsed += dt
        pending -= dt
        if mode == "speedrun" and all_upgrades_maxed():
            _finish()
        elif mode == "score_attack" and elapsed >= DURATION - 0.000001:
            elapsed = DURATION
            model.elapsed = DURATION
            _finish()

func _on_sale(customer: Dictionary) -> void:
    if finished:
        return
    streak += 1
    best_streak = maxi(best_streak, streak)
    best_multiplier = maxi(best_multiplier, multiplier())
    var fraction := clampf(float(customer.get("patience", 0.0)) / float(customer.get("max_patience", 30.0)), 0.0, 1.0)
    score += (100 + int(round(50.0 * fraction))) * multiplier()

func _on_abandoned(_customer: Dictionary) -> void:
    if not finished:
        lost += 1
        streak = 0

func all_upgrades_maxed() -> bool:
    for id in Restaurant.IDS:
        if int(model.upgrades[id]) != int(Restaurant.LIMITS[id]):
            return false
    return true

func _finish() -> void:
    finished = true
    model.simulation_frozen = true

func medal() -> String:
    for name in ["Gold", "Silver", "Bronze"]:
        if score >= int(MEDALS[name]):
            return name
    return "None"

func result() -> Dictionary:
    return {"mode":mode,"score":score,"elapsed":elapsed,"medal":medal(),"lost":lost,"best_multiplier":best_multiplier,"completed":finished,"served":model.sold,"best_streak":best_streak}

func set_target(point: Vector2) -> void:
    model.set_target(point)

func buy(id: String) -> bool:
    var bought := model.buy(id)
    if bought and mode == "speedrun" and all_upgrades_maxed():
        _finish()
    return bought

func boss_action() -> bool:
    return model.boss_action()

func assign_staff(index: int, assignment: String) -> bool:
    return model.assign_staff(index, assignment)

func start_rush() -> bool:
    return model.start_rush()
