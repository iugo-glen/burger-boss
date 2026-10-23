extends RefCounted
## Deterministic restaurant simulation, independent of scene/render/input APIs.
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
    return "Your team is working! Upgrade, add tables, fries and drive-through."

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
    player = player.move_toward(target, (250.0 + 30.0 * float(upgrades.speed)) * dt)
    var near_grill := player.distance_to(GRILL) < 100
    var near_counter := player.distance_to(COUNTER) < 100
    var working_cooks := 0
    for worker in staff:
        if worker.role == "cook" and worker.state == "cooking":
            working_cooks += 1
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
        if near_counter and carried > 0 and counter_stock < 30:
            carried -= 1
            counter_stock += 1
    if upgrades.fries > 0 and player.distance_to(FRIES) < 100:
        _fries_timer += dt
        if _fries_timer >= 0.8:
            _fries_timer = 0
            fries_carried = mini(fries_carried + 1, capacity())
    var active_cashiers := 0
    var drive_cashier := false
    for worker in staff:
        _update_worker(worker, dt)
        if worker.role == "cashier" and worker.state == "serving":
            active_cashiers += 1
        if worker.role == "cashier" and worker.state == "drive service":
            drive_cashier = true
    if counter_stock > 0 and _front(false) >= 0 and (near_counter or active_cashiers > 0):
        serve_progress += dt * float(upgrades.register) * ((1.0 if near_counter else 0.0) + float(active_cashiers) * 0.9) / 1.3
        if serve_progress >= 1.0:
            serve_progress -= 1.0
            _sell(false)
    else:
        serve_progress = 0
    if upgrades.drive > 0 and counter_stock > 0 and _front(true) >= 0 and (player.distance_to(DRIVE) < 100 or drive_cashier):
        _drive_timer += dt
        if _drive_timer >= 1.4:
            _drive_timer = 0
            _sell(true)
    else:
        _drive_timer = 0
    _arrival += dt
    if _arrival >= maxf(1.8, 3.1 - float(upgrades.table) * 0.22):
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
    for i in range(diners.size() - 1, -1, -1):
        diners[i].time -= dt
        if diners[i].time <= 0:
            diners.remove_at(i)

func _add_staff(role: String) -> void:
    var index := staff.size()
    staff.append({"role":role,"position":Vector2(350 + index * 25, 900),"target":GRILL if role == "cook" else COUNTER,"state":"walking to grill" if role == "cook" else "walking to counter","carried":0,"timer":0.0,"trips":0})

func _update_worker(worker: Dictionary, dt: float) -> void:
    var offset := Vector2(float(staff.find(worker) % 3) * 22 - 22, 65)
    var station: Vector2 = worker.target
    worker.position = worker.position.move_toward(station + offset, dt * (170 + int(upgrades.speed) * 15))
    if worker.position.distance_to(station + offset) > 3:
        return
    if worker.role == "cook":
        if worker.state == "walking to grill":
            worker.state = "cooking"
        if worker.state == "cooking" and grill_stock > 0:
            var amount := mini(grill_stock, capacity())
            grill_stock -= amount
            worker.carried = amount
            worker.target = COUNTER
            worker.state = "carrying burgers"
        elif worker.state == "carrying burgers":
            var amount := mini(int(worker.carried), 30 - counter_stock)
            counter_stock += amount
            worker.carried -= amount
            if worker.carried == 0:
                worker.target = GRILL
                worker.state = "walking to grill"
    else:
        if worker.state == "walking to counter":
            worker.state = "serving"
        if worker.state == "walking to drive":
            worker.state = "drive service"
        worker.timer += dt
        if worker.timer >= 4.0:
            worker.timer = 0
            if upgrades.drive > 0 and worker.state == "serving" and _front(true) >= 0:
                worker.target = DRIVE
                worker.state = "walking to drive"
            elif worker.state == "drive service":
                worker.target = COUNTER
                worker.state = "walking to counter"

func _spawn_customer() -> void:
    var is_drive: bool = upgrades.drive > 0 and _next_customer % 3 == 2
    queue.append({"id":_next_customer,"order":"drive" if is_drive else "burger","position":Vector2(650, 940),"target":Vector2(540,550)})
    _next_customer += 1

func _front(is_drive: bool) -> int:
    for i in queue.size():
        if (queue[i].order == "drive") == is_drive:
            return i if queue[i].position.distance_to(queue[i].target) < 18 else -1
    return -1

func _sell(is_drive: bool) -> void:
    var index := _front(is_drive)
    if index < 0 or counter_stock <= 0:
        return
    queue.remove_at(index)
    counter_stock -= 1
    sold += 1
    last_earned = burger_value() + (6 if is_drive else 0)
    if fries_carried > 0 and upgrades.fries > 0:
        fries_carried -= 1
        last_earned += 6
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

func snapshot() -> Dictionary:
    var staff_loads: Array[int] = []
    # Restore recreates staff by role, independent of the order they were hired.
    for role in ["cook", "cashier"]:
        for worker in staff:
            if worker.role == role:
                staff_loads.append(int(worker.carried))
    return {"staff_loads":staff_loads,"version":2,"money":money,"sold":sold,"upgrades":upgrades.duplicate(),"grill_stock":grill_stock,"carried":carried,"counter_stock":counter_stock,"fries_carried":fries_carried}

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
    upgrades = next_upgrades
    money = int(d.money)
    sold = int(d.sold)
    grill_stock = int(d.grill_stock)
    carried = int(d.carried)
    counter_stock = int(d.counter_stock)
    fries_carried = int(d.fries_carried)
    staff.clear()
    for i in int(upgrades.cook):
        _add_staff("cook")
    for i in int(upgrades.cashier):
        _add_staff("cashier")
    for i in staff.size():
        staff[i].carried = int(saved_loads[i])
        if staff[i].carried > 0:
            staff[i].target = COUNTER
            staff[i].state = "carrying burgers"
    notice = "Welcome back, Boss! Your restaurant is ready."
    return true

static func _valid_integer(value: Variant, low: int, high: int) -> bool:
    if not (value is int or value is float):
        return false
    return is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
