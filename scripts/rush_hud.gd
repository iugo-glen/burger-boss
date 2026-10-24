extends RefCounted
## Rush and assignment controls share the existing canvas coordinate system.
const RUSH_RECT := Rect2(20, 270, 460, 82)
const BOSS_RECT := Rect2(492, 270, 208, 82)
const JOB_NAMES := {"balanced":"Auto", "grill":"Burgers", "fries":"Fries", "counter":"Counter", "drive":"Drive-thru"}

static func handle(game: Node2D, action: String) -> bool:
    if not ["rush_start", "boss_action", "assign_cooks", "assign_cashiers", "select_cook", "select_cashier"].has(action):
        return false
    if game.paused or game.unfocused:
        return true
    if action == "rush_start":
        if game.model.rush.active:
            return true
        if game.model.start_rush():
            game._save()
        game._show_notice(game.model.notice)
    elif action == "boss_action":
        if game.model.boss_action():
            if not game.muted:
                game.sound.play_note(740.0)
            game._save()
        game._show_notice(game.model.notice)
    else:
        var role := "cook" if action == "assign_cooks" or action == "select_cook" else "cashier"
        var workers := _worker_indices(game.model, role)
        if workers.is_empty():
            game._show_notice("Hire a %s first to assign a job." % role)
            return true
        var ordinal := int(game.selected_staff[role]) % workers.size()
        if action.begins_with("select_"):
            game.selected_staff[role] = (ordinal + 1) % workers.size()
            return true
        var index: int = workers[ordinal]
        var choices: Array = game.model.allowed_assignments(index)
        if choices.is_empty():
            return true
        var current: String = game.model.staff[index].assignment
        var next: String = choices[(choices.find(current) + 1) % choices.size()]
        game.model.assign_staff(index, next)
        game._show_notice("%s #%d: %s. Other workers keep their jobs." % [role.capitalize(), ordinal + 1, JOB_NAMES.get(next, next)])
        game._save()
    return true

static func _worker_indices(model: RefCounted, role: String) -> Array[int]:
    var indices: Array[int] = []
    for index in range(model.staff.size()):
        if model.staff[index].role == role:
            indices.append(index)
    return indices

static func _progress(game: Node2D, at: Vector2, value: float, color: Color) -> void:
    game._box(Rect2(at, Vector2(134, 5)), Color("49675a"), 2)
    if value > 0.0:
        game._box(Rect2(at, Vector2(134 * clampf(value, 0, 1), 5)), color, 2)

static func draw(game: Node2D) -> void:
    var model = game.model
    var rush = model.rush
    var active: bool = rush.active
    var lock: String = model.rush_lock_reason()
    var ready: bool = not active and lock.is_empty()
    game._box(RUSH_RECT, Color("a65b38") if active else (Color("267361") if ready else Color("d9e5d3")), 12)
    var ink := Color.WHITE if active or ready else Color("435a53")
    if active:
        var seconds := int(ceil(rush.time_left))
        game._text("RUSH %d:%02d · Boss specials %d/%d" % [seconds / 60, seconds % 60, rush.specials, rush.special_goal], Vector2(34, 297), 23, ink)
        game._text("Orders %d/%d  ·  Combos %d/%d" % [rush.served, rush.goal, rush.combos, rush.combo_goal], Vector2(34, 326), 21, ink)
        _progress(game, Vector2(34, 339), float(rush.served) / maxf(1, rush.goal), Color("ffcf68"))
        _progress(game, Vector2(180, 339), float(rush.combos) / maxf(1, rush.combo_goal), Color("9fd6ad"))
        _progress(game, Vector2(326, 339), float(rush.specials) / maxf(1, rush.special_goal), Color("f3bf52"))
    elif rush.result == "Success":
        game._fit_text("SUCCESS +$%d · Start again" % rush.reward, Vector2(34, 301), 430, 24, ink)
        game._text("Rank %d · Best %d orders · Boss %d/%d" % [rush.rank, rush.best, rush.specials, rush.special_goal], Vector2(34, 332), 19, ink)
    elif rush.result == "Try again":
        game._text("Rush over · Retry free", Vector2(34, 301), 24, ink)
        game._fit_text("Orders %d/%d · Combos %d/%d · Boss %d/%d" % [rush.served, rush.goal, rush.combos, rush.combo_goal, rush.specials, rush.special_goal], Vector2(34, 332), 432, 20, ink)
    else:
        game._text("Start lunch rush · Free", Vector2(34, 301), 25, ink)
        var preparation := "Boss combos: you at counter/drive" if model.upgrades.drive > 0 else "60s · You hand off boss combos at counter"
        game._fit_text(preparation if ready else lock, Vector2(34, 332), 432, 20, ink)
    game._button("rush_start", RUSH_RECT)
    var boss_ready: bool = model.boss_cooldown <= 0.0
    game._box(BOSS_RECT, Color("e9b65e") if boss_ready else Color("d9e5d3"), 12)
    game._text("Boss boost", Vector2(508, 300), 25, Color("263b3b"))
    var label: String = model.boss_label()
    if not boss_ready:
        label = "Ready in %ds" % int(ceil(model.boss_cooldown))
    game._fit_text(label, Vector2(507, 331), 178, 19, Color("435a53"))
    game._button("boss_action", BOSS_RECT)

static func draw_staff(game: Node2D) -> void:
    _hire_card(game, "cook", Rect2(18, 1072, 334, 82), "Cook & carry")
    _hire_card(game, "cashier", Rect2(368, 1072, 334, 82), "Serve & collect")
    _assignment_card(game, "cook", Rect2(18, 1160, 334, 82), "assign_cooks")
    _assignment_card(game, "cashier", Rect2(368, 1160, 334, 82), "assign_cashiers")

static func _hire_card(game: Node2D, role: String, rect: Rect2, description: String) -> void:
    var enabled: bool = game.model.can_buy(role)
    var ink := Color.WHITE if enabled else Color("435a53")
    game._box(rect, Color("267361") if enabled else Color("dce3d4"))
    var reason: String = game.model.lock_reason(role)
    var price := "$%d" % game.model.cost(role) if reason.is_empty() else reason
    game._text("Hire %s · %s" % [role, price], rect.position + Vector2(12, 29), 23, ink)
    game._fit_text("%s · %d working" % [description, game.model.upgrades[role]], rect.position + Vector2(12, 60), 310, 20, ink)
    game._button(role, rect)

static func _assignment_card(game: Node2D, role: String, rect: Rect2, action: String) -> void:
    var workers := _worker_indices(game.model, role)
    var hired := not workers.is_empty()
    var ordinal := int(game.selected_staff[role]) % workers.size() if hired else 0
    var assignment := "Auto"
    var choices: Array[String] = []
    if hired:
        var index: int = workers[ordinal]
        var current: String = game.model.staff[index].assignment
        assignment = JOB_NAMES.get(current, current)
        for choice in game.model.allowed_assignments(index):
            choices.append(JOB_NAMES.get(choice, choice))
    var selector := Rect2(rect.position, Vector2(82, 82))
    var job := Rect2(rect.position + Vector2(88, 0), Vector2(246, 82))
    game._box(selector, Color("355e56") if hired else Color("e8e7d7"))
    game._box(job, Color("355e56") if hired else Color("e8e7d7"))
    var ink := Color.WHITE if hired else Color("6b7c70")
    game._text("Next", selector.position + Vector2(15, 29), 20, ink)
    game._text("%d/%d" % [ordinal + 1 if hired else 0, workers.size()], selector.position + Vector2(22, 59), 20, ink)
    game._fit_text("%s #%d: %s >" % [role.capitalize(), ordinal + 1, assignment], job.position + Vector2(10, 29), 226, 22, ink)
    game._fit_text(" / ".join(choices) if hired else "Hire first to assign", job.position + Vector2(10, 59), 226, 18, ink)
    game._button("select_" + role, selector)
    game._button(action, job)

static func telemetry(model: RefCounted) -> Dictionary:
    var workers: Array[Dictionary] = []
    for worker in model.staff:
        workers.append({"role":worker.role,"assignment":worker.assignment,"state":worker.state,"position":{"x":worker.position.x,"y":worker.position.y},"carried":worker.carried,"carry_kind":worker.carry_kind,"trips":worker.trips,"target":{"x":worker.target.x,"y":worker.target.y}})
    var orders: Array[Dictionary] = []
    for customer in model.queue:
        orders.append({"id":customer.id,"position":{"x":customer.position.x,"y":customer.position.y},"target":{"x":customer.target.x,"y":customer.target.y},"settled":customer.position.distance_to(customer.target) < 18,"order":customer.order,"combo":customer.combo,"patience":customer.patience,"max_patience":customer.max_patience,"rush_order":customer.rush_order,"special":customer.special})
    var rush = model.rush
    return {"lost":model.lost,"calm_patience":model.calm_patience(),"calm_arrivals_per_minute":model.calm_arrivals_per_minute(),"calm_arrival_gap":model.calm_arrival_gap(),"queue_capacity":model.queue_capacity(),"fries_stock":model.fries_stock,"counter_fries":model.counter_fries,"fries_carried":model.fries_carried,"combo_served":model.combo_served,"boss_actions":model.boss_actions,"boss_cooldown":model.boss_cooldown,"boss_label":model.boss_label(),"rush_lock_reason":model.rush_lock_reason(),"staff":workers,"queue":orders,"rush":{"active":rush.active,"time_left":rush.time_left,"duration":rush.duration,"goal":rush.goal,"served":rush.served,"combos":rush.combos,"combo_goal":rush.combo_goal,"specials":rush.specials,"special_goal":rush.special_goal,"lost":rush.lost,"rank":rush.rank,"wins":rush.wins,"best":rush.best,"result":rush.result,"reward":rush.reward}}
