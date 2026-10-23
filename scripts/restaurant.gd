extends RefCounted
## Deterministic restaurant simulation, independent of scene/render/input APIs.
const RushDirector = preload("res://scripts/rush_director.gd")
const GRILL := Vector2(170, 430)
const COUNTER := Vector2(540, 430)
const FRIES := Vector2(170, 660)
const DRIVE := Vector2(575, 800)
const IDS := ["grill", "register", "cook", "cashier", "table", "fries", "drive", "speed", "value", "capacity"]
const LIMITS := {"grill":4,"register":3,"cook":3,"cashier":2,"table":4,"fries":1,"drive":1,"speed":5,"value":5,"capacity":4}
const INITIAL := {"grill":1,"register":1,"cook":0,"cashier":0,"table":0,"fries":0,"drive":0,"speed":0,"value":0,"capacity":0}
var upgrades: Dictionary = INITIAL.duplicate()
var player := Vector2(320, 750)
var target := player
var money := 0
var sold := 0
var grill_stock := 0
var carried := 0
var counter_stock := 0
var fries_carried := 0
var fries_stock := 0
var counter_fries := 0
var fries_progress := 0.0
var combo_served := 0
var boss_actions := 0
var boss_cooldown := 0.0
var rush := RushDirector.new()
var queue: Array[Dictionary] = []
var staff: Array[Dictionary] = []
var diners: Array[Dictionary] = []
var cook_progress := 0.0
var serve_progress := 0.0
var elapsed := 0.0
var notice := "Welcome! Walk to the grill to cook your first burger."
var last_earned := 0
var sale_serial := 0
var _arrival := 0.0
var _pickup := 0.0
var _fries_timer := 0.0
var _drive_timer := 0.0
var _next_customer := 0

func _init() -> void:
    for i in 3:
        _spawn_customer()

func capacity() -> int:
    return 3 + int(upgrades.capacity) * 2

func burger_value() -> int:
    return 12 + int(upgrades.value) * 4

func cost(id: String) -> int:
    if not IDS.has(id):
        return 0
    var base := {"grill":45,"register":60,"cook":90,"cashier":120,"table":55,"fries":180,"drive":320,"speed":35,"value":40,"capacity":30}
    var purchased := int(upgrades[id]) - int(INITIAL[id])
    return int(round(float(base[id]) * pow(1.65, purchased)))

func lock_reason(id: String) -> String:
    if not IDS.has(id):
        return "Unknown upgrade"
    if int(upgrades[id]) >= int(LIMITS[id]):
        return "MAX"
    if id == "fries" and sold < 12:
        return "12 sales to unlock"
    if id == "drive" and sold < 25:
        return "25 sales to unlock"
    return ""

func can_buy(id: String) -> bool:
    return lock_reason(id).is_empty() and money >= cost(id)

func buy(id: String) -> bool:
    var reason := lock_reason(id)
    if not reason.is_empty():
        notice = reason
        return false
    if money < cost(id):
        notice = "Need $%d" % cost(id)
        return false
    money -= cost(id)
    upgrades[id] = int(upgrades[id]) + 1
    if id == "cook" or id == "cashier":
        _add_staff(id)
    notice = "%s purchased!" % id.capitalize()
    return true

func set_target(point: Vector2) -> void:
    target = Vector2(clampf(point.x, 42, 678), clampf(point.y, 230, 940))

func tutorial() -> String:
    if sold == 0 and carried == 0:
        return "1. Walk to the orange grill. Wait to cook and pick up burgers."
    if carried > 0:
        return "2. Carry burgers to the blue counter. Stay there to serve."
    if sold < 3:
        return "3. Keep cooking and serving. Your first hire costs $90."
    if upgrades.cook == 0:
        return "Hire a cook to carry burgers while you run the counter."
    if upgrades.cashier == 0:
        return "Hire a cashier for automatic service. Try upgrades too!"
    if upgrades.fries > 0:
        return "Combos need burger + fries at counter. Gold rush orders need you nearby. Boost at stations."
    return "Your team is working! Unlock fries, then promote a lunch rush."

func step(delta: float) -> void:
    if not is_finite(delta) or delta <= 0:
        return
    # Substeps prevent missed arrivals/interactions when callers fast-forward.
    var remaining := minf(delta, 60.0)
    while remaining > 0.000001:
        var dt := minf(remaining, 0.1)
        _tick(dt)
        remaining -= dt

func _tick(dt: float) -> void:
    elapsed += dt
    boss_cooldown = maxf(0, boss_cooldown - dt)
    if boss_cooldown < 0.000001:
        boss_cooldown = 0
    player = player.move_toward(target, (250.0 + 30.0 * float(upgrades.speed)) * dt)
    var near_grill := player.distance_to(GRILL) < 100
    var near_counter := player.distance_to(COUNTER) < 100
    var working_cooks := 0
    var frying_cooks := 0
    for worker in staff:
        if worker.role == "cook" and worker.state == "cooking":
            working_cooks += 1
        if worker.role == "cook" and worker.state == "frying":
            frying_cooks += 1
    var cook_rate := float(upgrades.grill) * (float(working_cooks) * 0.85 + (1.0 if near_grill else 0.0))
    if grill_stock < 6 + int(upgrades.grill) * 3:
        cook_progress += dt * cook_rate / 2.2
        while cook_progress >= 1.0 and grill_stock < 6 + int(upgrades.grill) * 3:
            cook_progress -= 1.0
            grill_stock += 1
    else:
        cook_progress = 0
    _pickup += dt
    if _pickup >= 0.22:
        _pickup = 0
        if near_grill and carried < capacity() and grill_stock > 0:
            grill_stock -= 1
            carried += 1
        if near_counter or player.distance_to(DRIVE) < 100:
            _unload_player(1)
        if upgrades.fries > 0 and player.distance_to(FRIES) < 100 and fries_stock > 0 and fries_carried < capacity():
            fries_stock -= 1
            fries_carried += 1
    if upgrades.fries > 0 and fries_stock < 18:
        var fry_rate: float = float(frying_cooks) * 0.9 + (1.0 if player.distance_to(FRIES) < 100 else 0.0)
        fries_progress += dt * fry_rate / 1.2
        while fries_progress >= 1.0 and fries_stock < 18:
            fries_progress -= 1.0
            fries_stock += 1
    else:
        fries_progress = 0
    var active_cashiers := 0
    var drive_cashier := false
    for worker in staff:
        _update_worker(worker, dt)
        if worker.role == "cashier" and worker.state == "serving":
            active_cashiers += 1
        if worker.role == "cashier" and worker.state == "drive service":
            drive_cashier = true
    if _can_serve(false) and (near_counter or active_cashiers > 0):
        serve_progress += dt * float(upgrades.register) * ((1.0 if near_counter else 0.0) + float(active_cashiers) * 0.9) / 1.3
        if serve_progress >= 1.0:
            serve_progress -= 1.0
            _sell(false)
    else:
        serve_progress = 0
    if upgrades.drive > 0 and _can_serve(true) and (player.distance_to(DRIVE) < 100 or drive_cashier):
        _drive_timer += dt
        if _drive_timer >= 1.4:
            _drive_timer = 0
            _sell(true)
    else:
        _drive_timer = 0
    _arrival += dt
    var arrival_gap := maxf(1.8, 3.1 - float(upgrades.table) * 0.22)
    if rush.active:
        arrival_gap = maxf(0.75, rush.duration / (float(rush.goal) * 1.65))
    if _arrival >= arrival_gap:
        _arrival = 0
        if queue.size() < 8 + int(upgrades.table):
            _spawn_customer()
    var normal_index := 0
    var drive_index := 0
    for customer in queue:
        if customer.order == "drive":
            customer.target = Vector2(600 + (drive_index / 4) * 30, 835 + (drive_index % 4) * 28)
            drive_index += 1
        else:
            customer.target = Vector2(540, 550 + normal_index * 29)
            normal_index += 1
        customer.position = customer.position.move_toward(customer.target, dt * 125)
    _tick_rush(dt)
    for i in range(diners.size() - 1, -1, -1):
        diners[i].time -= dt
        if diners[i].time <= 0:
            diners.remove_at(i)

func allowed_assignments(index: int) -> Array:
    if index < 0 or index >= staff.size():
        return []
    if staff[index].role == "cook":
        return ["balanced", "grill", "fries"] if upgrades.fries > 0 else ["balanced", "grill"]
    return ["balanced", "counter", "drive"] if upgrades.drive > 0 else ["balanced", "counter"]

func assign_staff(index: int, assignment: String) -> bool:
    if not allowed_assignments(index).has(assignment):
        return false
    var worker: Dictionary = staff[index]
    _resume_held_tray(worker)
    worker.assignment = assignment
    worker.timer = 0.0
    # Finish deliveries before changing jobs, preserving every carried ingredient.
    if worker.carried == 0:
        if worker.role == "cook":
            _route_cook(worker)
        else:
            worker.target = DRIVE if assignment == "drive" else COUNTER
            worker.state = "walking to drive" if assignment == "drive" else "walking to counter"
    notice = "%s assigned to %s" % [str(worker.role).capitalize(), assignment]
    return true

func _add_staff(role: String) -> void:
    var index := staff.size()
    staff.append({"role":role,"position":Vector2(350 + index * 25, 900),"target":GRILL if role == "cook" else COUNTER,"state":"walking to grill" if role == "cook" else "walking to counter","carried":0,"held_burgers":0,"held_fries":0,"carry_kind":"burger","assignment":"balanced","timer":0.0,"trips":0})

func _resume_held_tray(worker: Dictionary) -> void:
    # A reload or assignment can interrupt a rescue walk before its new load is
    # picked up. Resume the existing tray first, never cook more of its kind.
    if worker.carried > 0:
        return
    if worker.get("held_burgers", 0) > 0:
        worker.carried = worker.held_burgers
        worker.held_burgers = 0
        worker.carry_kind = "burger"
    elif worker.get("held_fries", 0) > 0:
        worker.carried = worker.held_fries
        worker.held_fries = 0
        worker.carry_kind = "fries"
    else:
        return
    worker.target = COUNTER
    worker.state = "carrying fries" if worker.carry_kind == "fries" else "carrying burgers"

func _route_cook(worker: Dictionary) -> void:
    var use_fries: bool = worker.assignment == "fries"
    if worker.assignment == "balanced" and upgrades.fries > 0:
        var sides_in_transit := 0
        for other in staff:
            if other.role == "cook" and (other.state == "frying" or other.state == "walking to fries" or (other.carried > 0 and other.carry_kind == "fries")):
                sides_in_transit += maxi(2, int(other.carried))
        var wanted := 2
        for customer in queue:
            if customer.get("combo", false):
                wanted += 1
        use_fries = counter_fries + sides_in_transit < wanted
    worker.target = FRIES if use_fries else GRILL
    worker.state = "walking to fries" if use_fries else "walking to grill"
    worker.timer = 0.0

func _update_worker(worker: Dictionary, dt: float) -> void:
    var offset := Vector2(float(staff.find(worker) % 3) * 22 - 22, 65)
    var station: Vector2 = worker.target
    worker.position = worker.position.move_toward(station + offset, dt * (170 + int(upgrades.speed) * 15))
    if worker.position.distance_to(station + offset) > 3:
        return
    if worker.role == "cook":
        if worker.state == "walking to grill":
            worker.state = "cooking"
        elif worker.state == "walking to fries":
            worker.state = "frying"
        if worker.state == "cooking" or worker.state == "frying":
            worker.timer += dt
            var frying: bool = worker.state == "frying"
            var available := fries_stock if frying else grill_stock
            if available > 0 and (available >= capacity() or worker.timer >= 3.0):
                var amount := mini(available, capacity())
                if frying:
                    fries_stock -= amount
                else:
                    grill_stock -= amount
                worker.carried = amount
                worker.carry_kind = "fries" if frying else "burger"
                worker.target = COUNTER
                worker.state = "carrying fries" if frying else "carrying burgers"
                worker.timer = 0.0
        elif worker.state == "carrying burgers" or worker.state == "carrying fries":
            var is_fries: bool = worker.carry_kind == "fries"
            var amount := mini(int(worker.carried), 30 - (counter_fries if is_fries else counter_stock))
            if is_fries:
                counter_fries += amount
            else:
                counter_stock += amount
            worker.carried -= amount
            if worker.carried == 0:
                worker.trips += 1
                if worker.get("held_burgers", 0) > 0:
                    worker.carried = worker.held_burgers
                    worker.held_burgers = 0
                    worker.carry_kind = "burger"
                    worker.state = "carrying burgers"
                    worker.target = COUNTER
                elif worker.get("held_fries", 0) > 0:
                    worker.carried = worker.held_fries
                    worker.held_fries = 0
                    worker.carry_kind = "fries"
                    worker.state = "carrying fries"
                    worker.target = COUNTER
                else:
                    _route_cook(worker)
            elif not is_fries and worker.assignment in ["balanced", "fries"] and upgrades.fries > 0 and counter_fries == 0:
                # Keep the burger tray on the worker while making a rescue side run.
                # A full burger counter must not trap every cook behind a combo.
                worker.held_burgers = worker.carried
                if worker.get("held_fries", 0) > 0:
                    worker.carried = worker.held_fries
                    worker.held_fries = 0
                    worker.carry_kind = "fries"
                    worker.target = COUNTER
                    worker.state = "carrying fries"
                else:
                    worker.carried = 0
                    worker.target = FRIES
                    worker.state = "walking to fries"
                worker.timer = 0.0
            elif is_fries and worker.assignment in ["balanced", "grill"] and counter_stock == 0:
                worker.held_fries = worker.carried
                if worker.get("held_burgers", 0) > 0:
                    worker.carried = worker.held_burgers
                    worker.held_burgers = 0
                    worker.carry_kind = "burger"
                    worker.target = COUNTER
                    worker.state = "carrying burgers"
                else:
                    worker.carried = 0
                    worker.target = GRILL
                    worker.state = "walking to grill"
                worker.timer = 0.0
    else:
        if worker.state == "walking to counter":
            worker.state = "serving"
        if worker.state == "walking to drive":
            worker.state = "drive service"
        worker.timer += dt
        if worker.assignment == "balanced" and worker.timer >= 4.0:
            worker.timer = 0
            if upgrades.drive > 0 and worker.state == "serving" and _front(true) >= 0:
                worker.target = DRIVE
                worker.state = "walking to drive"
            elif worker.state == "drive service":
                worker.target = COUNTER
                worker.state = "walking to counter"

func _spawn_customer() -> void:
    var is_drive: bool = upgrades.drive > 0 and _next_customer % 3 == 2
    queue.append({"id":_next_customer,"order":"drive" if is_drive else "burger","position":Vector2(650, 940),"target":Vector2(540,550),"combo":upgrades.fries > 0 and _next_customer % (2 if rush.active else 3) == 1,"rush_order":rush.active,"patience":30.0,"max_patience":30.0,"special":rush.active and _next_customer % 4 == 2})
    if queue.back().special:
        queue.back().combo = true
    _next_customer += 1

func _front(is_drive: bool) -> int:
    for i in queue.size():
        if (queue[i].order == "drive") == is_drive:
            return i if queue[i].position.distance_to(queue[i].target) < 18 else -1
    return -1

func _can_serve(is_drive: bool) -> bool:
    var index := _front(is_drive)
    if index < 0 or counter_stock <= 0 or (queue[index].get("combo", false) and counter_fries <= 0):
        return false
    if rush.active and queue[index].get("rush_order", false) and queue[index].get("special", false):
        return player.distance_to(DRIVE if is_drive else COUNTER) < 100
    return true

func _sell(is_drive: bool) -> void:
    if not _can_serve(is_drive):
        return
    var index := _front(is_drive)
    var customer: Dictionary = queue[index]
    var is_combo: bool = customer.get("combo", false)
    if is_combo:
        counter_fries -= 1
        combo_served += 1
    if customer.get("rush_order", false):
        rush.record_sale(is_combo, customer.get("special", false))
    queue.remove_at(index)
    counter_stock -= 1
    sold += 1
    last_earned = burger_value() + (6 if is_drive else 0)
    if is_combo:
        last_earned += 10
    if upgrades.table > 0 and not is_drive:
        last_earned += 2
        for seat in int(upgrades.table):
            var occupied := false
            for diner in diners:
                if diner.seat == seat:
                    occupied = true
                    break
            if not occupied:
                diners.append({"seat":seat,"position":Vector2(135 + (seat % 2) * 170, 740 + (seat / 2) * 90),"time":8.0})
                break
    money += last_earned
    sale_serial += 1
    if sold == 1:
        notice = "First burger served! +$%d" % last_earned
    elif sold % 10 == 0:
        notice = "%d happy customers served!" % sold

func rush_lock_reason() -> String:
    if rush.active:
        return "Rush already running"
    if sold < 25:
        return "Serve 25 customers first"
    if upgrades.cook == 0 or upgrades.cashier == 0:
        return "Hire a cook and cashier first"
    if upgrades.fries == 0:
        return "Unlock the fries station first"
    return ""

func start_rush() -> bool:
    var reason := rush_lock_reason()
    if not reason.is_empty():
        notice = reason
        return false
    rush.start(upgrades)
    _arrival = 0.0
    # Promote the people already waiting; a full calm queue never wastes the timer.
    for i in queue.size():
        queue[i].rush_order = true
        queue[i].special = i % 4 == 2
        queue[i].combo = i % 2 == 1 or queue[i].special
        queue[i].patience = 30.0
        queue[i].max_patience = 30.0
    notice = "Lunch rush! %d orders, %d combos, %d Boss handoffs. Stand at the counter for gold orders." % [rush.goal, rush.combo_goal, rush.special_goal]
    return true

func _tick_rush(dt: float) -> void:
    if not rush.active:
        return
    rush.time_left = maxf(0, rush.time_left - dt)
    for i in range(queue.size() - 1, -1, -1):
        if queue[i].get("rush_order", false):
            queue[i].patience -= dt
            if queue[i].patience <= 0:
                queue.remove_at(i)
                rush.lost += 1
    if rush.achieved() or rush.time_left <= 0:
        rush.finish(burger_value())
        money += rush.reward
        if rush.result == "Success":
            notice = "Rush won! Rank %d, +$%d. Prepare and try the next rush." % [rush.rank, rush.reward]
        else:
            notice = "Rush over: %d/%d orders, %d/%d combos, %d/%d Boss. Retry free!" % [rush.served,rush.goal,rush.combos,rush.combo_goal,rush.specials,rush.special_goal]
        # Remaining impatient combo demands become ordinary orders. Recovery is free.
        for customer in queue:
            customer.rush_order = false
            customer.combo = false
            customer.special = false

func _unload_player(amount: int) -> void:
    var burgers_to_drop := mini(amount, mini(carried, 30 - counter_stock))
    carried -= burgers_to_drop
    counter_stock += burgers_to_drop
    var fries_to_drop := mini(amount, mini(fries_carried, 30 - counter_fries))
    fries_carried -= fries_to_drop
    counter_fries += fries_to_drop

func boss_label() -> String:
    if boss_cooldown > 0:
        return "Ready in %ds" % int(ceil(boss_cooldown))
    if player.distance_to(GRILL) < 110:
        return "Grill +%d" % (4 + int(upgrades.grill))
    if upgrades.fries > 0 and player.distance_to(FRIES) < 110:
        return "Fry +%d" % (4 + int(upgrades.grill))
    if player.distance_to(COUNTER) < 110 or (upgrades.drive > 0 and player.distance_to(DRIVE) < 110):
        return "Serve now"
    return "Move to a station"

func boss_action() -> bool:
    if boss_cooldown > 0:
        notice = "Boss boost is recharging"
        return false
    var changed := false
    var batch := 4 + int(upgrades.grill)
    if player.distance_to(GRILL) < 110:
        var amount := mini(batch, 6 + int(upgrades.grill) * 3 - grill_stock)
        if amount > 0:
            grill_stock += amount
            changed = true
            notice = "Boss grilled %d burgers! Carry them to the counter." % amount
    elif upgrades.fries > 0 and player.distance_to(FRIES) < 110:
        var amount := mini(batch, 18 - fries_stock)
        if amount > 0:
            fries_stock += amount
            changed = true
            notice = "Boss fried %d sides! Carry them to the counter." % amount
    elif player.distance_to(COUNTER) < 110 or (upgrades.drive > 0 and player.distance_to(DRIVE) < 110):
        var before := carried + fries_carried
        _unload_player(capacity())
        changed = before > carried + fries_carried
        var at_drive: bool = player.distance_to(DRIVE) < 110 and upgrades.drive > 0
        for i in 2 + int(upgrades.register):
            if not _can_serve(at_drive):
                break
            _sell(at_drive)
            changed = true
        if changed:
            notice = "Boss expedited the counter!"
    if not changed:
        notice = "Use a station with room to prep, or a complete order to serve."
        return false
    boss_cooldown = 8.0
    boss_actions += 1
    return true

func snapshot() -> Dictionary:
    var staff_loads: Array[int] = []
    var staff_kinds: Array[String] = []
    var staff_assignments: Array[String] = []
    var staff_reserve: Array[int] = []
    var staff_fries_reserve: Array[int] = []
    # Restore recreates staff by role, independent of the order they were hired.
    for role in ["cook", "cashier"]:
        for worker in staff:
            if worker.role == role:
                staff_loads.append(int(worker.carried))
                staff_kinds.append(str(worker.get("carry_kind", "burger")))
                staff_assignments.append(str(worker.get("assignment", "balanced")))
                staff_reserve.append(int(worker.get("held_burgers", 0)))
                staff_fries_reserve.append(int(worker.get("held_fries", 0)))
    return {"rush_interrupted":rush.active,"staff_fries_reserve":staff_fries_reserve,"fries_stock":fries_stock,"counter_fries":counter_fries,"combo_served":combo_served,"boss_actions":boss_actions,"boss_cooldown":boss_cooldown,"mastery":{"rank":rush.rank,"wins":rush.wins,"best":rush.best},"staff_reserve":staff_reserve,"staff_kinds":staff_kinds,"staff_assignments":staff_assignments,"staff_loads":staff_loads,"version":2,"money":money,"sold":sold,"upgrades":upgrades.duplicate(),"grill_stock":grill_stock,"carried":carried,"counter_stock":counter_stock,"fries_carried":fries_carried}

func restore(data: Variant) -> bool:
    if not data is Dictionary:
        return false
    var d: Dictionary = data
    if d.get("version", 0) != 2 or not d.get("upgrades") is Dictionary:
        return false
    var next_upgrades: Dictionary = INITIAL.duplicate()
    for id in IDS:
        var n: Variant = d.upgrades.get(id)
        if not _valid_integer(n, int(INITIAL[id]), int(LIMITS[id])):
            return false
        next_upgrades[id] = int(n)
    for key in ["money", "sold", "grill_stock", "carried", "counter_stock", "fries_carried"]:
        if not _valid_integer(d.get(key), 0, 1000000000):
            return false
    if int(d.carried) > 3 + int(next_upgrades.capacity) * 2 or int(d.counter_stock) > 30 or int(d.grill_stock) > 6 + int(next_upgrades.grill) * 3 or int(d.fries_carried) > 3 + int(next_upgrades.capacity) * 2:
        return false
    var saved_loads: Variant = d.get("staff_loads")
    if not saved_loads is Array or saved_loads.size() != int(next_upgrades.cook) + int(next_upgrades.cashier):
        return false
    for i in saved_loads.size():
        if not _valid_integer(saved_loads[i], 0, 3 + int(next_upgrades.capacity) * 2):
            return false
        if i >= int(next_upgrades.cook) and int(saved_loads[i]) != 0:
            return false
    # New fields are optional so every previously valid v2 save still loads.
    for key in ["fries_stock", "counter_fries", "combo_served", "boss_actions"]:
        var upper := 18 if key == "fries_stock" else (30 if key == "counter_fries" else 1000000000)
        if not _valid_integer(d.get(key, 0), 0, upper):
            return false
    var saved_cooldown: Variant = d.get("boss_cooldown", 0.0)
    if not (saved_cooldown is float or saved_cooldown is int) or not is_finite(float(saved_cooldown)) or float(saved_cooldown) < 0 or float(saved_cooldown) > 8:
        return false
    var mastery: Variant = d.get("mastery", {"rank":0,"wins":0,"best":0})
    if not mastery is Dictionary:
        return false
    for key in ["rank", "wins", "best"]:
        if not _valid_integer(mastery.get(key), 0, 999 if key == "rank" else 1000000000):
            return false
    var reserve: Variant = d.get("staff_reserve", [])
    if not reserve is Array or (not reserve.is_empty() and reserve.size() != saved_loads.size()):
        return false
    for i in reserve.size():
        if not _valid_integer(reserve[i], 0, 3 + int(next_upgrades.capacity) * 2) or (i >= int(next_upgrades.cook) and int(reserve[i]) != 0):
            return false
    var side_reserve: Variant = d.get("staff_fries_reserve", [])
    if not side_reserve is Array or (not side_reserve.is_empty() and side_reserve.size() != saved_loads.size()):
        return false
    for i in side_reserve.size():
        if not _valid_integer(side_reserve[i], 0, 3 + int(next_upgrades.capacity) * 2) or (i >= int(next_upgrades.cook) and int(side_reserve[i]) != 0):
            return false
        if int(side_reserve[i]) > 0 and (next_upgrades.fries == 0 or (not reserve.is_empty() and int(reserve[i]) > 0)):
            return false
    if not d.get("rush_interrupted", false) is bool:
        return false
    var kinds: Variant = d.get("staff_kinds", [])
    var assignments: Variant = d.get("staff_assignments", [])
    if not kinds is Array or not assignments is Array:
        return false
    if (not kinds.is_empty() and kinds.size() != saved_loads.size()) or (not assignments.is_empty() and assignments.size() != saved_loads.size()):
        return false
    for i in saved_loads.size():
        var kind: Variant = kinds[i] if not kinds.is_empty() else "burger"
        var assignment: Variant = assignments[i] if not assignments.is_empty() else "balanced"
        if not ["burger", "fries"].has(kind) or (kind == "fries" and next_upgrades.fries == 0):
            return false
        var held_burger: int = int(reserve[i]) if not reserve.is_empty() else 0
        var held_side: int = int(side_reserve[i]) if not side_reserve.is_empty() else 0
        if int(saved_loads[i]) > 0 and ((kind == "burger" and held_burger > 0) or (kind == "fries" and held_side > 0)):
            return false
        if held_burger > 0 and next_upgrades.fries == 0:
            return false
        var allowed := ["balanced", "grill", "fries"] if i < int(next_upgrades.cook) else ["balanced", "counter", "drive"]
        if not allowed.has(assignment) or (assignment == "fries" and next_upgrades.fries == 0) or (assignment == "drive" and next_upgrades.drive == 0):
            return false
    upgrades = next_upgrades
    money = int(d.money)
    sold = int(d.sold)
    grill_stock = int(d.grill_stock)
    carried = int(d.carried)
    counter_stock = int(d.counter_stock)
    fries_carried = int(d.fries_carried)
    fries_stock = int(d.get("fries_stock", 0))
    counter_fries = int(d.get("counter_fries", 0))
    combo_served = int(d.get("combo_served", 0))
    boss_actions = int(d.get("boss_actions", 0))
    boss_cooldown = float(saved_cooldown)
    rush = RushDirector.new()
    rush.rank = int(mastery.rank)
    rush.wins = int(mastery.wins)
    rush.best = int(mastery.best)
    staff.clear()
    for i in int(upgrades.cook):
        _add_staff("cook")
    for i in int(upgrades.cashier):
        _add_staff("cashier")
    for i in staff.size():
        staff[i].carried = int(saved_loads[i])
        staff[i].held_burgers = reserve[i] if not reserve.is_empty() else 0
        staff[i].held_fries = side_reserve[i] if not side_reserve.is_empty() else 0
        staff[i].carry_kind = kinds[i] if not kinds.is_empty() else "burger"
        staff[i].assignment = assignments[i] if not assignments.is_empty() else "balanced"
        if staff[i].carried == 0:
            assign_staff(i, staff[i].assignment)
        if staff[i].carried > 0:
            staff[i].target = COUNTER
            staff[i].state = "carrying fries" if staff[i].carry_kind == "fries" else "carrying burgers"
    notice = "Saved rush cancelled; calm service resumed. Retry free when ready." if d.get("rush_interrupted", false) else "Welcome back, Boss! Your restaurant is ready."
    return true

static func _valid_integer(value: Variant, low: int, high: int) -> bool:
    if not (value is int or value is float):
        return false
    return is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
