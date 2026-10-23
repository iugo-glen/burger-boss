extends SceneTree
const Restaurant = preload("res://scripts/restaurant.gd")
const SaveStore = preload("res://scripts/save_store.gd")
var checks := 0
var errors := 0

func expect(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        errors += 1
        push_error(description)

func _initialize() -> void:
    test_first_sale_and_economy()
    test_save_validation()
    test_reset_transaction()
    test_queue_and_seats()
    test_rush_rules_and_recovery()
    test_career_patience()
    test_career_demand()
    test_calm_throughput_matrix()
    test_rush_balance_matrix()
    test_ten_minutes()
    print("Restaurant acceptance tests: %d checks, %d failures" % [checks, errors])
    quit(1 if errors else 0)

func manual_delivery(model: RefCounted) -> void:
    model.set_target(Restaurant.GRILL)
    model.step(10)
    model.set_target(Restaurant.COUNTER)
    model.step(8)

func test_first_sale_and_economy() -> void:
    var model := Restaurant.new()
    manual_delivery(model)
    expect(model.sold >= 1 and model.elapsed < 60, "Fresh player serves first burger within 60 seconds")
    expect(model.money >= 12, "Customer pays money")
    expect(model.carried == 0 and model.grill_stock >= 0, "Carried burgers move into counter stock")
    var before := model.money
    expect(not model.buy("nonsense") and model.money == before, "Invalid upgrade cannot charge money")
    expect(not model.buy("drive") and model.money == before, "Drive-through is gated before 25 sales")
    model.money = 10000
    var price: int = model.cost("value")
    var value: int = model.burger_value()
    expect(model.buy("value") and model.money == 10000 - price, "Upgrade charges advertised cost")
    expect(model.burger_value() > value, "Value upgrade raises payment")
    var carry: int = model.capacity()
    model.buy("capacity")
    expect(model.capacity() > carry, "Carry upgrade changes capacity")
    model.buy("cook")
    model.buy("cashier")
    expect(model.staff.size() == 2, "Hiring creates visible workers")
    var worker_start: Vector2 = model.staff[0].position
    model.set_target(Vector2(350,900))
    model.step(20)
    expect(model.staff[0].position != worker_start, "Cook navigates to a station")
    var sales_before: int = model.sold
    model.step(50)
    expect(model.sold > sales_before, "Hired staff cook, carry, and sell without player intervention")
    var arriving := Restaurant.new()
    arriving.counter_stock = 3
    arriving.player = Restaurant.COUNTER
    arriving.target = arriving.player
    arriving.step(1.5)
    expect(arriving.sold == 0, "Cashier waits for front customer to physically reach queue")
    model.sold = 25
    expect(model.buy("drive") and model.buy("fries"), "New stations unlock after sales thresholds")
    model.set_target(Restaurant.FRIES)
    model.step(5)
    expect(model.fries_carried > 0, "Unlocked fries station produces optional combo sides")
    model.buy("table")
    expect(model.upgrades.table == 1, "Tables can be purchased")
    for i in 8:
        model.buy("grill")
    expect(model.upgrades.grill == 4 and model.lock_reason("grill") == "MAX", "Upgrade limits prevent runaway costs")
    var capped_money: int = model.money
    expect(not model.buy("grill") and model.money == capped_money, "Maxed purchase cannot charge money")

func test_save_validation() -> void:
    var model := Restaurant.new()
    model.money = 10000
    model.sold = 50
    for id in ["cook","cashier","drive","fries","table","speed","capacity"]:
        model.buy(id)
    manual_delivery(model)
    var state: Dictionary = model.snapshot()
    var restored := Restaurant.new()
    expect(restored.restore(JSON.parse_string(JSON.stringify(state))), "JSON save roundtrip loads")
    expect(restored.snapshot() == state, "All persistent economy and inventory fields survive reload")
    expect(restored.staff.size() == 2, "Staff restored visibly")
    model.staff[0].carried = 2
    model.staff[0].carry_kind = "burger"
    model.staff[0].state = "carrying burgers"
    model.staff[0].target = Restaurant.COUNTER
    state = model.snapshot()
    expect(restored.restore(state) and restored.staff[0].carried == 2 and restored.staff[0].state == "carrying burgers", "Midtrip save conserves burgers carried by cooks")
    var reverse := Restaurant.new()
    reverse.money = 1000
    reverse.buy("cashier")
    reverse.buy("cook")
    reverse.staff[1].carried = 2
    reverse.staff[1].state = "carrying burgers"
    reverse.staff[1].target = Restaurant.COUNTER
    var reverse_restored := Restaurant.new()
    expect(reverse_restored.restore(reverse.snapshot()), "Cashier-before-cook hiring order saves valid midtrip state")
    expect(reverse_restored.staff[0].role == "cook" and reverse_restored.staff[0].carried == 2, "Canonical role order preserves cook inventory across reverse hiring")
    for bad in [null, [], "broken", {}, {"version":99}, {"version":2,"upgrades":[]}]:
        expect(not restored.restore(bad), "Malformed save rejected")
    var baseline: Dictionary = restored.snapshot()
    var corrupt: Dictionary = state.duplicate(true)
    corrupt.money = -1
    expect(not restored.restore(corrupt) and restored.snapshot() == baseline, "Negative save fails without mutating state")
    corrupt = state.duplicate(true)
    corrupt.upgrades.grill = 99999
    expect(not restored.restore(corrupt), "Out-of-range upgrades rejected")
    corrupt = state.duplicate(true)
    corrupt.carried = "x"
    expect(not restored.restore(corrupt), "Wrong scalar types rejected")
    corrupt = state.duplicate(true)
    corrupt.money = INF
    expect(not restored.restore(corrupt), "Nonfinite values rejected")
    var path := "user://test_restaurant.json"
    expect(SaveStore.save(model,path), "Save writes to disk")
    var disk := Restaurant.new()
    expect(SaveStore.load_into(disk,path) and disk.snapshot() == state, "Disk reload restores progress")
    var file := FileAccess.open(path,FileAccess.WRITE)
    file.store_string('{"money":')
    file.close()
    var fresh := Restaurant.new()
    expect(not SaveStore.load_into(fresh,path) and fresh.money == 0 and fresh.queue.size() > 0, "Truncated disk save leaves playable fresh model")
    DirAccess.remove_absolute(path)

func test_queue_and_seats() -> void:
    var model := Restaurant.new()
    model.upgrades.table = 2
    model.diners = [{"seat":1,"position":Vector2(305,740),"time":5.0}]
    model.queue[0].position = model.queue[0].target
    model.counter_stock = 2
    model._sell(false)
    expect(model.diners.size() == 2 and model.diners[1].seat == 0, "Diner reuses first free seat rather than overlapping occupied seat")
    model.queue.clear()
    model.upgrades.drive = 1
    model.upgrades.table = 4
    for i in 12:
        model.queue.append({"id":i,"order":"drive","position":Vector2(650,940),"target":Vector2(540,550)})
    model.step(0.1)
    var visible := true
    for customer in model.queue:
        visible = visible and customer.target.x >= 42 and customer.target.x <= 678 and customer.target.y <= 940
    expect(visible, "Maximum drive queue remains in visible play area")

func test_ten_minutes() -> void:
    var model := Restaurant.new()
    # Earn every dollar from a fresh manual loop, then buy both staff roles.
    for i in 7:
        manual_delivery(model)
    expect(model.money >= 210, "Fresh economy funds cook and cashier without gifts")
    expect(model.buy("cook") and model.buy("cashier"), "Earned money hires the automation team")
    model.set_target(Vector2(350,900))
    var sales_at_start: int = model.sold
    var minimum_window_sales := 100000
    var last_sales: int = model.sold
    for second in 600:
        model.step(1)
        if second % 60 == 59:
            minimum_window_sales = mini(minimum_window_sales, model.sold - last_sales)
            last_sales = model.sold
        if second == 90:
            model.buy("table")
        if second == 180:
            model.buy("grill")
        if second == 240:
            model.buy("value")
        if second == 300:
            model.buy("drive")
        expect(model.money >= 0 and model.grill_stock >= 0 and model.counter_stock >= 0, "Ten-minute economy remains nonnegative")
        expect(model.queue.size() <= model.queue_capacity(), "Queue stays bounded")
    expect(model.sold > sales_at_start + 50, "Ten-minute automated run makes sustained progress")
    expect(minimum_window_sales >= 9, "Every minute retains at least nine sales with no queue or worker deadlock")
    expect(model.upgrades.drive == 1, "Earned progression reaches drive-through")
    print("Ten-minute run: %d additional sales, $%d cash, minimum %d sales/minute" % [model.sold-sales_at_start,model.money,minimum_window_sales])

# The challenge fixtures start from explicit snapshots; no state or supplies are
# injected after promotion. Tier zero earns every upgrade from the original loop.
func rush_fixture(tier: int) -> RefCounted:
    var model := Restaurant.new()
    if tier == 0:
        for i in 12:
            manual_delivery(model)
        for id in ["cook", "cashier", "fries"]:
            expect(model.buy(id), "Earned manual progression unlocks lunch rush team")
        expect(model.sold >= 25, "Naturally earned rush unlock reaches 25 sales")
    else:
        model.money = 1000000
        model.sold = 100
        for id in Restaurant.IDS:
            var limit: int = Restaurant.LIMITS[id] if tier >= 2 else mini(int(Restaurant.LIMITS[id]), 2)
            while model.upgrades[id] < limit:
                model.buy(id)
        if tier == 3:
            model.rush.rank = 6
    return model

func run_rush_snapshot(state: Dictionary, active: bool) -> RefCounted:
    var model := Restaurant.new()
    expect(model.restore(state), "Challenge comparison starts from matching valid snapshot")
    model.player = Vector2(350, 900)
    model.set_target(model.player)
    expect(model.start_rush(), "Eligible promotion starts a free rush")
    var leg := "prep"
    var prep := Restaurant.GRILL
    var wait := 0.0
    var since_boost := 10.0
    for frame in 601:
        if not model.rush.active:
            break
        if active:
            # Actual movement and imperfect boost timing: never faster than 10s,
            # although the ability recharges in 8s. No direct position changes.
            since_boost += 0.1
            if leg == "prep":
                model.set_target(prep)
                if model.player.distance_to(prep) < 45:
                    wait += 0.1
                    if since_boost >= 10 and model.boss_action():
                        since_boost = 0
                    if wait > 3.0 or model.carried >= model.capacity() or model.fries_carried >= model.capacity():
                        leg = "drop"
                        wait = 0
            else:
                model.set_target(Restaurant.COUNTER)
                if model.player.distance_to(Restaurant.COUNTER) < 45:
                    wait += 0.1
                    if since_boost >= 10 and model.boss_action():
                        since_boost = 0
                    if wait > 1.2 and model.carried == 0 and model.fries_carried == 0:
                        leg = "prep"
                        wait = 0
                        prep = Restaurant.FRIES if model.counter_fries + model.fries_stock < (model.counter_stock + model.grill_stock) * 0.75 else Restaurant.GRILL
            # Give the boss a real job: deliver gold combo orders at either lane.
            for drive in [false, true]:
                var front: int = model._front(drive)
                if front >= 0 and model.queue[front].get("special", false) and model.counter_stock > 0 and model.counter_fries > 0:
                    model.set_target(Restaurant.DRIVE if drive else Restaurant.COUNTER)
                    break
        model.step(0.1)
    return model

func test_rush_balance_matrix() -> void:
    for tier in [0, 1, 2, 3]:
        var base: RefCounted = rush_fixture(tier)
        for stocked in [false, true]:
            var state: Dictionary = base.snapshot()
            state.grill_stock = 6 + int(base.upgrades.grill) * 3 if stocked else 0
            state.counter_stock = 30 if stocked else 0
            state.fries_stock = 18 if stocked else 0
            state.counter_fries = 30 if stocked else 0
            state.carried = base.capacity() if stocked else 0
            state.fries_carried = base.capacity() if stocked else 0
            var idle: RefCounted = run_rush_snapshot(state, false)
            var active: RefCounted = run_rush_snapshot(state, true)
            expect(idle.rush.result == "Try again", "Idle automation cannot replace boss handoffs at any capacity tier")
            expect(active.rush.result == "Success", "Imperfect active play wins early, middle, maxed and rank-six rushes")
            expect(active.rush.specials >= active.rush.special_goal and active.rush.combos >= active.rush.combo_goal, "Winning rush fulfills real special and combo targets")
            expect(active.rush.reward > 0 and active.rush.rank == base.rush.rank + 1, "Rush victory earns money and lasting mastery")
            expect(active.boss_actions <= 6, "Rush does not require perfect cooldown spam")
            print("Rush matrix tier=%d stocked=%s goal=%d idle=%d active=%d boss=%d/%d boosts=%d" % [tier,stocked,active.rush.goal,idle.rush.served,active.rush.served,active.rush.specials,active.rush.special_goal,active.boss_actions])

func test_rush_rules_and_recovery() -> void:
    var locked := Restaurant.new()
    expect(not locked.start_rush() and not locked.rush.active and locked.money == 0, "Fresh player cannot accidentally start an unsupported rush")
    var model: RefCounted = rush_fixture(0)
    model.queue.clear()
    model.queue.append({"id":20,"position":Restaurant.COUNTER,"target":Restaurant.COUNTER,"order":"burger","combo":true})
    model.counter_stock = 2
    model.counter_fries = 0
    var cash: int = model.money
    var combo_sales_before: int = model.sold
    model._sell(false)
    expect(model.sold == combo_sales_before and model.counter_stock == 2 and model.money == cash, "Combo without fries neither consumes burger nor pays ghost money")
    model.counter_fries = 1
    var before_sales: int = model.sold
    model._sell(false)
    expect(model.sold == before_sales + 1 and model.counter_stock == 1 and model.counter_fries == 0 and model.money == cash + model.burger_value() + 10, "Combo consumes exactly one burger and one real side")
    model.player = Vector2(350,900)
    model.target = model.player
    expect(not model.boss_action() and model.boss_cooldown == 0, "Boost away from station does not spend cooldown")
    model.player = Restaurant.COUNTER
    model.target = model.player
    model.queue.clear()
    model.carried = 0
    model.fries_carried = 0
    expect(not model.boss_action() and model.boss_cooldown == 0, "Empty order cannot consume a boost")
    model.player = Restaurant.FRIES
    model.fries_stock = 0
    expect(model.boss_action() and model.fries_stock == 5 and model.boss_cooldown == 8, "Fryer boost produces a bounded real batch")
    expect(not model.boss_action() and model.fries_stock == 5, "Boost cooldown prevents duplicate production")
    model.step(8)
    model.player = Restaurant.GRILL
    model.grill_stock = 9
    expect(not model.boss_action() and model.boss_cooldown == 0, "Full grill does not waste ready boost")
    # Assignments cause actual navigation, production and typed deliveries.
    var fryer: RefCounted = rush_fixture(0)
    fryer.player = Vector2(350,900)
    fryer.target = fryer.player
    fryer.grill_stock = 0
    fryer.counter_stock = 0
    fryer.fries_stock = 0
    fryer.counter_fries = 0
    fryer.carried = 0
    fryer.fries_carried = 0
    expect(fryer.assign_staff(0,"fries"), "Cook accepts unlocked fryer assignment")
    fryer.step(25)
    expect(fryer.counter_fries > 0 and fryer.counter_stock == 0, "Fryer assignment physically produces and delivers fries instead of burgers")
    expect(not fryer.assign_staff(0,"drive"), "Inappropriate cook assignment rejected")
    fryer.assign_staff(0,"grill")
    var fryer_sales: int = fryer.sold
    fryer.step(25)
    expect(fryer.counter_stock > 0 or fryer.sold > fryer_sales, "Grill reassignment produces burgers and restores service")
    # Full-counter rescue conserves carried cargo and breaks either ingredient jam.
    for explicit in [false, true]:
        var rescue: RefCounted = rush_fixture(0)
        rescue.player = Vector2(350,900)
        rescue.target = rescue.player
        rescue.counter_stock = 30
        rescue.counter_fries = 0
        rescue.fries_stock = 8
        rescue.queue[0].combo = true
        rescue.staff[0].position = Restaurant.COUNTER + Vector2(-22,65)
        rescue.staff[0].target = Restaurant.COUNTER
        rescue.staff[0].state = "carrying burgers"
        rescue.staff[0].carry_kind = "burger"
        rescue.staff[0].carried = 3
        if explicit:
            rescue.assign_staff(0,"fries")
        expect(rescue.staff[0].carried == 3 and rescue.staff[0].carry_kind == "burger", "Assignment preserves typed cargo already in transit")
        var old_sales: int = rescue.sold
        rescue.step(35)
        expect(rescue.sold > old_sales, "Balanced or explicitly fryer-assigned loaded cook rescues a full-burger combo blockage")
    var reverse: RefCounted = rush_fixture(0)
    reverse.player = Vector2(350,900)
    reverse.target = reverse.player
    reverse.counter_stock = 0
    reverse.counter_fries = 30
    reverse.grill_stock = 0
    reverse.staff[0].position = Restaurant.COUNTER + Vector2(-22,65)
    reverse.staff[0].target = Restaurant.COUNTER
    reverse.staff[0].state = "carrying fries"
    reverse.staff[0].carry_kind = "fries"
    reverse.staff[0].carried = 3
    var reverse_sales: int = reverse.sold
    reverse.step(35)
    expect(reverse.sold > reverse_sales, "Auto assignment recovers from full fries counter and held sides by cooking burgers")
    # Successful baseline fries routing must collect stock waiting at the fryer.
    var waiting: RefCounted = rush_fixture(0)
    waiting.player = Vector2(350,900)
    waiting.target = waiting.player
    waiting.counter_stock = 10
    waiting.counter_fries = 0
    waiting.fries_stock = 8
    waiting.queue[0].combo = true
    var waiting_sales: int = waiting.sold
    waiting.step(30)
    expect(waiting.sold > waiting_sales, "Balanced cooks deliver already-prepared fryer stock to unblock combos")
    # Promotion deliberately includes pre-existing queued customers, even a full queue.
    var challenge: RefCounted = rush_fixture(0)
    challenge.player = Vector2(350,900)
    challenge.target = challenge.player
    while challenge.queue.size() < 8:
        challenge._spawn_customer()
    var queued: int = challenge.queue.size()
    var money_before: int = challenge.money
    expect(challenge.start_rush() and challenge.queue.size() == queued and challenge.money == money_before, "Free promotion promotes existing full queue without removing or charging customers")
    var promoted := true
    var special_found := false
    for customer in challenge.queue:
        promoted = promoted and customer.rush_order
        special_found = special_found or customer.special
    expect(promoted and special_found, "Waiting queue becomes eligible rush demand including Boss specials")
    challenge.step(60)
    expect(challenge.rush.result == "Try again" and challenge.rush.lost > 0 and challenge.rush.reward == 0, "Idle failed rush records impatient departures with no cash penalty")
    var cleared := true
    for customer in challenge.queue:
        cleared = cleared and not customer.get("rush_order",false) and not customer.get("special",false) and not customer.get("combo",false)
    expect(cleared, "Failed rush clears special and combo blockers from remaining promoted demand")
    var calm_reset := true
    for customer in challenge.queue:
        calm_reset = calm_reset and customer.patience == challenge.calm_patience() and customer.max_patience == challenge.calm_patience()
    expect(calm_reset, "Rush survivors receive the full calm patience allowance")
    var recovery_sales: int = challenge.sold
    challenge.step(40)
    expect(challenge.sold > recovery_sales and challenge.start_rush(), "Calm economy recovers and retry remains free")
    var interrupted: Dictionary = challenge.snapshot()
    var loaded := Restaurant.new()
    expect(loaded.restore(interrupted) and not loaded.rush.active and loaded.notice.contains("cancelled"), "Midrush reload explicitly cancels optional timer and resumes safe calm service")
    expect(loaded.boss_cooldown == challenge.boss_cooldown, "Reload preserves boost cooldown")
    # Every prior version-two save, including maxed cargo, migrates transactionally.
    var legacy_model: RefCounted = rush_fixture(2)
    var legacy: Dictionary = legacy_model.snapshot()
    for key in ["fries_stock","counter_fries","combo_served","boss_actions","boss_cooldown","mastery","staff_kinds","staff_assignments","staff_reserve","staff_fries_reserve","rush_interrupted"]:
        legacy.erase(key)
    legacy.staff_loads = [11,11,11,0,0]
    expect(loaded.restore(legacy) and loaded.upgrades == legacy.upgrades and loaded.staff[0].carried == 11 and loaded.staff[0].carry_kind == "burger", "Old maxed v2 saves and cook cargo migrate with defaults")
    var current: Dictionary = loaded.snapshot()
    var invalid: Dictionary = current.duplicate(true)
    invalid.counter_fries = -1
    expect(not loaded.restore(invalid) and loaded.snapshot() == current, "Invalid new fields cannot partially mutate save state")
    invalid = current.duplicate(true)
    invalid.staff_assignments[0] = "drive"
    expect(not loaded.restore(invalid) and loaded.snapshot() == current, "Invalid saved role assignment rejected transactionally")
    var cargo: RefCounted = rush_fixture(0)
    cargo.staff[0].carried = 2
    cargo.staff[0].carry_kind = "fries"
    cargo.staff[0].held_burgers = 3
    cargo.assign_staff(0,"fries")
    expect(loaded.restore(cargo.snapshot()) and loaded.staff[0].carried == 2 and loaded.staff[0].carry_kind == "fries" and loaded.staff[0].held_burgers == 3 and loaded.staff[0].assignment == "fries", "Typed fries cargo, rescue burger tray and assignment survive reload")
    # A loaded rescue worker swaps the already held opposite tray; never creates
    # two reserves or a snapshot rejected by the next browser reload.
    cargo.staff[0].position = Restaurant.COUNTER + Vector2(-22,65)
    cargo.staff[0].target = Restaurant.COUNTER
    cargo.staff[0].state = "carrying fries"
    cargo.staff[0].assignment = "balanced"
    cargo.counter_stock = 0
    cargo.counter_fries = 30
    cargo._update_worker(cargo.staff[0],0.1)
    expect(cargo.staff[0].carried == 3 and cargo.staff[0].carry_kind == "burger" and cargo.staff[0].held_fries == 2 and cargo.staff[0].held_burgers == 0, "Opposite held tray becomes rescue delivery without losing or inventing ingredients")
    expect(loaded.restore(cargo.snapshot()), "Valid rescue save remains valid after worker takes next step")
    var invalid_same: Dictionary = cargo.snapshot()
    invalid_same.staff_loads[0] = 3
    invalid_same.staff_kinds[0] = "burger"
    invalid_same.staff_reserve[0] = 2
    invalid_same.staff_fries_reserve[0] = 0
    expect(not loaded.restore(invalid_same), "Semantically invalid same-kind cargo and rescue reserve rejected before any overwrite")
    cargo.staff[0].carried = 0
    cargo.staff[0].held_burgers = 3
    cargo.staff[0].held_fries = 0
    cargo.staff[0].carry_kind = "burger"
    expect(loaded.restore(cargo.snapshot()) and loaded.staff[0].carried == 3 and loaded.staff[0].held_burgers == 0, "Reload resumes existing held tray instead of producing a second same-kind load")
    cargo.assign_staff(0,"grill")
    expect(cargo.staff[0].carried == 3 and cargo.staff[0].held_burgers == 0 and cargo.staff[0].state == "carrying burgers", "Reassignment resumes held tray without discarding or duplicating it")

func test_reset_transaction() -> void:
    # These paths are isolated fixtures. Never reset or write DEFAULT_PATH.
    var root := "user://test_reset_transaction"
    var path := root.path_join("save.json")
    var temporary := path + ".tmp"
    expect(DirAccess.make_dir_recursive_absolute(root) == OK, "Reset test creates its own isolated save directory")
    var rich: RefCounted = rush_fixture(2)
    rich.money = 43210
    rich.sold = 987
    rich.grill_stock = 15
    rich.carried = 7
    rich.counter_stock = 22
    rich.fries_stock = 12
    rich.counter_fries = 19
    rich.fries_carried = 4
    rich.combo_served = 123
    rich.boss_actions = 77
    rich.boss_cooldown = 5.0
    rich.rush.rank = 6
    rich.rush.wins = 8
    rich.rush.best = 42
    rich.staff[0].carried = 3
    rich.staff[0].carry_kind = "fries"
    rich.staff[0].assignment = "fries"
    var previous: Dictionary = rich.snapshot()
    expect(SaveStore.save(rich, path), "Rich progress is persisted before testing reset")
    expect(not FileAccess.file_exists(temporary), "Successful atomic save leaves no temporary file")
    var old_bytes := FileAccess.get_file_as_string(path)
    # A directory at the temporary filename causes a real storage-open failure.
    # The directory is test-owned and removed only by this fixture's cleanup.
    expect(DirAccess.make_dir_absolute(temporary) == OK, "Fixture blocks temporary file creation to simulate storage failure")
    var failed: RefCounted = SaveStore.reset_progress(path)
    expect(failed == null, "Failed reset never hands the UI an unpersisted fresh model")
    expect(rich.snapshot() == previous, "Failed reset leaves every live progress field intact")
    expect(FileAccess.get_file_as_string(path) == old_bytes, "Failed reset preserves old primary save byte for byte")
    expect(DirAccess.dir_exists_absolute(temporary), "Failed open does not delete an unrelated temporary-path directory")
    var retained := Restaurant.new()
    expect(SaveStore.load_into(retained,path) and retained.snapshot() == previous, "Old rich save still restores after failed reset")
    expect(DirAccess.remove_absolute(temporary) == OK, "Fixture removes its own storage-failure directory")
    # A rename failure must also preserve the destination, not delete it first.
    var blocked := root.path_join("blocked_destination")
    expect(DirAccess.make_dir_absolute(blocked) == OK, "Fixture creates nonempty destination directory for rename failure")
    var sentinel := blocked.path_join("sentinel.txt")
    var sentinel_file := FileAccess.open(sentinel,FileAccess.WRITE)
    sentinel_file.store_string("keep existing destination")
    sentinel_file.close()
    expect(SaveStore.reset_progress(blocked) == null, "Commit failure is reported instead of swapping to fresh progress")
    expect(DirAccess.dir_exists_absolute(blocked) and FileAccess.get_file_as_string(sentinel) == "keep existing destination", "Failed commit preserves its existing destination and contents")
    expect(not FileAccess.file_exists(blocked + ".tmp"), "Failed commit cleans only the temporary file it wrote")
    expect(FileAccess.get_file_as_string(path) == old_bytes, "Commit failure never touches the isolated previous progress save")
    var missing := root.path_join("missing_parent/save.json")
    expect(SaveStore.reset_progress(missing) == null and not FileAccess.file_exists(missing), "Missing storage directory fails safely without manufacturing a success")
    var fresh: RefCounted = SaveStore.reset_progress(path)
    expect(fresh != null and fresh != rich, "Successful reset returns a distinct persisted Restaurant")
    var initial := Restaurant.new()
    if fresh != null:
        expect(fresh.snapshot() == initial.snapshot(), "Reset clears money, upgrades, staff, cargo, fries, cooldown and mastery")
        expect(fresh.player == initial.player and fresh.target == initial.target and fresh.queue.size() == 3 and not fresh.rush.active, "Reset starts a playable restaurant with fresh position, waiting customers and no active rush")
    expect(rich.snapshot() == previous, "Successful reset also leaves the old live object untouched until caller swaps it")
    var reloaded := Restaurant.new()
    expect(SaveStore.load_into(reloaded,path) and reloaded.snapshot() == initial.snapshot(), "Reload after reset restores only fresh progress")
    expect(not FileAccess.file_exists(temporary), "Reset atomically replaces primary and consumes temporary file")
    DirAccess.remove_absolute(path)
    DirAccess.remove_absolute(sentinel)
    DirAccess.remove_absolute(blocked)
    DirAccess.remove_absolute(root)

func test_career_patience() -> void:
    for tables in [0, 4]:
        var model := Restaurant.new()
        model.upgrades.table = tables
        model.queue.clear()
        model._spawn_customer()
        var customer: Dictionary = model.queue[0]
        var window: float = 45.0 + tables * 5.0
        expect(customer.patience == window and customer.max_patience == window, "Calm patience includes generous table allowance")
        customer.position = customer.target
        model.step(1)
        expect(is_equal_approx(customer.patience, window - 1), "Settled calm patience counts down exactly once per tick")
        model.queue.clear()
        model.queue.append(customer)
        customer.patience = 0.05
        customer.position = Vector2(650, 940)
        model.step(0.1)
        expect(model.queue.size() == 1 and customer.patience == 0.05 and model.lost == 0, "Walking arrivals cannot expire before reaching their queue position")
        customer.position = customer.target
        model.step(0.1)
        expect(model.queue.is_empty() and model.lost == 1 and model.money == 0 and model.sold == 0, "Calm departure records one loss without payment or sale")
        expect(model.notice.contains("left"), "Calm departure supplies visible feedback")
    var unattended := Restaurant.new()
    unattended.step(60)
    expect(unattended.lost > 0 and unattended.money == 0 and unattended.sold == 0, "Natural unattended calm queue loses customers without income")
    var service := Restaurant.new()
    service.queue.clear()
    service._spawn_customer()
    service.queue[0].position = service.queue[0].target
    service.queue[0].patience = 0.05
    service.player = Restaurant.COUNTER
    service.target = service.player
    service.counter_stock = 3
    service.serve_progress = 0.99
    service.step(0.1)
    expect(service.lost == 1 and service.sold == 0 and service.counter_stock == 3 and service.money == 0, "Expiry precedes ready service without consuming food or paying")
    var reflow := Restaurant.new()
    reflow.queue.clear()
    reflow._spawn_customer()
    reflow._spawn_customer()
    reflow._spawn_customer()
    reflow.step(0.1)
    reflow.queue[0].position = reflow.queue[0].target
    reflow.queue[0].patience = 0.05
    reflow.queue[1].position = reflow.queue[1].target
    reflow.queue[1].patience = 0.05
    var follower: Dictionary = reflow.queue[2]
    follower.position = follower.target
    reflow.step(0.1)
    var remaining: float = follower.patience
    reflow.step(0.1)
    expect(reflow.queue.size() == 1 and follower.patience == remaining, "Reflowed follower retains patience while walking towards the newly vacant position")
    var state: Dictionary = unattended.snapshot()
    var loaded := Restaurant.new()
    expect(loaded.restore(state) and loaded.lost == unattended.lost, "Calm lost counter survives save roundtrip")
    state.erase("lost")
    expect(loaded.restore(state) and loaded.lost == 0, "Existing version-two saves default missing lost counter to zero")
    var baseline: Dictionary = loaded.snapshot()
    for invalid in [-1, 0.5, "1", true, INF, NAN]:
        var corrupt: Dictionary = baseline.duplicate(true)
        corrupt.lost = invalid
        expect(not loaded.restore(corrupt) and loaded.snapshot() == baseline, "Invalid calm lost counter is rejected transactionally")
    var rush_model: RefCounted = rush_fixture(0)
    rush_model.queue.clear()
    rush_model._spawn_customer()
    rush_model.queue[0].position = rush_model.queue[0].target
    expect(rush_model.start_rush() and rush_model.queue[0].max_patience == 30.0, "Career rush retains thirty-second patience")
    var rush_customer: Dictionary = rush_model.queue[0]
    rush_model.step(1)
    expect(is_equal_approx(rush_customer.patience, 29.0), "Settled career rush patience counts down once")
    rush_customer.patience = 0.05
    rush_customer.position = Vector2(650, 940)
    rush_model.step(0.1)
    expect(rush_customer.patience == 0.05 and rush_model.rush.lost == 0, "Career rush arrivals also retain patience while walking")
    rush_customer.position = rush_customer.target
    var money_before: int = rush_model.money
    var sales_before: int = rush_model.sold
    var calm_lost_before: int = rush_model.lost
    rush_model.step(0.1)
    expect(rush_model.rush.lost == 1 and rush_model.lost == calm_lost_before and rush_model.money == money_before and rush_model.sold == sales_before, "Rush departure increments only rush losses and cannot pay")

func test_career_demand() -> void:
    var model := Restaurant.new()
    var previous_gap := INF
    for sales in range(301):
        model.sold = sales
        var gap: float = model.calm_arrival_gap()
        expect(gap < previous_gap, "Every sale through 300 strictly raises calm demand")
        previous_gap = gap
    model.sold = 0
    expect(is_equal_approx(model.calm_arrivals_per_minute(), 18.0), "Fresh career demand is eighteen arrivals per minute")
    model.sold = 150
    expect(is_equal_approx(model.calm_arrivals_per_minute(), 30.0), "Mid-career demand is thirty arrivals per minute")
    model.sold = 300
    model.upgrades.table = 4
    expect(is_equal_approx(model.calm_arrivals_per_minute(), 48.0), "Mature demand reaches forty-eight arrivals per minute")
    var capped_gap: float = model.calm_arrival_gap()
    model.sold = 100000
    expect(model.calm_arrival_gap() == capped_gap and model.queue_capacity() == 14, "Sales beyond three hundred cannot exceed demand or queue caps")
    for drive in [0, 1]:
        model.upgrades.drive = drive
        model.queue.clear()
        while model.queue.size() < model.queue_capacity():
            model._spawn_customer()
        model.step(1)
        var visible := true
        for customer in model.queue:
            visible = visible and customer.target.x >= 42 and customer.target.x <= 678 and customer.target.y <= 940
        expect(model.queue.size() <= 14 and visible, "Fourteen-customer counter or mixed queue remains bounded and visible")
    var register_low: RefCounted = rush_fixture(0)
    var register_high := Restaurant.new()
    expect(register_high.restore(register_low.snapshot()), "Register comparison restores identical career team")
    register_high.money = 100000
    while register_high.upgrades.register < 3:
        register_high.buy("register")
    expect(register_low.start_rush() and register_high.start_rush() and register_low.rush.goal == register_high.rush.goal, "Buying registers cannot raise career rush targets")

func test_calm_throughput_matrix() -> void:
    # Controlled mature balance fixtures, with no extra inventory during the run.
    for explicit in [false, true]:
        for stocked in [false, true]:
            var model: RefCounted = rush_fixture(2)
            model.sold = 300
            model.player = Vector2(350, 900)
            model.target = model.player
            model.grill_stock = 18 if stocked else 0
            model.fries_stock = 18 if stocked else 0
            model.counter_stock = 30 if stocked else 0
            model.counter_fries = 30 if stocked else 0
            model.carried = 0
            model.fries_carried = 0
            if explicit:
                for worker in 3:
                    expect(model.assign_staff(worker, "fries" if worker == 2 else "grill"), "Mature cooks accept deliberate ingredient split")
                expect(model.assign_staff(3, "counter") and model.assign_staff(4, "drive"), "Mature cashiers accept deliberate lane split")
            var peak_queue := 0
            var bounded := true
            var minutes: Array[int] = []
            var previous_sales: int = model.sold
            for second in 600:
                # Observe the queue each simulation step without thousands of assertions.
                for frame in 10:
                    model.step(0.1)
                    peak_queue = maxi(peak_queue, model.queue.size())
                    bounded = bounded and model.queue.size() <= model.queue_capacity()
                if second % 60 == 59:
                    minutes.append(model.sold - previous_sales)
                    previous_sales = model.sold
            expect(bounded, "Mature calm queues stay inside their advertised capacity")
            if explicit:
                expect(minutes.min() >= 45 and peak_queue < 14 and model.lost == 0, "Assigned mature team sustains forty-five sales every minute without capped queues or losses")
            else:
                expect(model.sold > 300 and minutes.min() > 0, "Auto staff continue serving despite mature congestion")
            print("Calm matrix assigned=%s stocked=%s sales=%d minutes=%s peak_queue=%d lost=%d" % [explicit,stocked,model.sold-300,minutes,peak_queue,model.lost])
