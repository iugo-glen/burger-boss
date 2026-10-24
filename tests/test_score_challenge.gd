extends SceneTree
const Challenge = preload("res://scripts/score_challenge.gd")
const Store = preload("res://scripts/challenge_store.gd")
const Restaurant = preload("res://scripts/restaurant.gd")
var checks := 0
var failures := 0

func expect(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)

func ready_customer(model: RefCounted, patience: float = 30.0, drive: bool = false) -> void:
    model.queue.append({"id":1000 + model.queue.size(),"order":"drive" if drive else "burger","position":Restaurant.DRIVE if drive else Restaurant.COUNTER,"target":Restaurant.DRIVE if drive else Restaurant.COUNTER,"combo":false,"rush_order":false,"special":false,"patience":patience,"max_patience":30.0})

func _initialize() -> void:
    test_scoring()
    test_clock_and_freeze()
    test_speedrun()
    test_natural_speedrun()
    test_records()
    test_balance()
    print("Score challenge acceptance: %d checks, %d failures" % [checks, failures])
    quit(1 if failures else 0)

func test_scoring() -> void:
    var run := Challenge.new()
    run.model.queue.clear()
    run.model.player = Restaurant.COUNTER
    run.model.target = Restaurant.COUNTER
    run.model.counter_stock = 30
    for i in 11:
        ready_customer(run.model)
        run.model._sell(false)
    expect(run.score == 150 * (5 + 10 + 3), "Every sale gets exact bonus and 1/2/3x streak bands")
    expect(run.streak == 11 and run.multiplier() == 3 and run.best_multiplier == 3, "Streak caps at three")
    ready_customer(run.model, 0.01)
    run.model.serve_progress = 1.0
    run.step(0.1)
    expect(run.lost == 1 and run.streak == 0 and run.model.sold == 11, "Expired customer abandons before ready service and resets streak")
    ready_customer(run.model, 15.0)
    run.model._sell(false)
    expect(run.score == 2825, "Half patience gives25 bonus after streak reset")
    run.model.queue.clear()
    for i in 3:
        ready_customer(run.model)
    var before: int = run.score
    run.model.boss_action()
    expect(run.score - before == 450 and run.streak == 4, "Synchronous Boss boost records every sale")
    var rush_run := Challenge.new()
    rush_run.model.sold = 30
    rush_run.model.upgrades.cook = 1
    rush_run.model.upgrades.cashier = 1
    rush_run.model.upgrades.fries = 1
    rush_run.model.queue[0].patience = 10.0
    expect(rush_run.start_rush() and rush_run.model.queue[0].patience == 10.0, "Rush promotion preserves challenge wait time")
    expect(rush_run.model.rush.goal == 12, "Challenge rush retains its original register-dependent target")
    var mature := Challenge.new()
    mature.model.sold = 300
    mature.model.upgrades.table = 4
    expect(is_equal_approx(mature.model.calm_arrival_gap(), 2.22) and mature.model.queue_capacity() == 12 and mature.model.calm_patience() == 30.0, "Mature challenges retain original demand, capacity and patience")
    rush_run.step(0.1)
    expect(is_equal_approx(rush_run.model.queue[0].patience, 9.9), "Rush patience advances once per challenge tick")
    var career := Restaurant.new()
    career.step(40)
    expect(career.lost == 0 and career.queue.size() >= 3, "Generous career patience retains customers through forty unattended seconds")
    var dual := Challenge.new()
    dual.model.queue.clear()
    dual.model.upgrades.drive = 1
    dual.model._add_staff("cashier")
    dual.model.staff[0].position = Restaurant.DRIVE + Vector2(-22,65)
    dual.model.staff[0].target = Restaurant.DRIVE
    dual.model.staff[0].state = "drive service"
    dual.model.staff[0].assignment = "drive"
    dual.model.player = Restaurant.COUNTER
    dual.model.target = Restaurant.COUNTER
    dual.model.counter_stock = 3
    dual.model.serve_progress = 1.0
    dual.model._drive_timer = 1.4
    ready_customer(dual.model)
    ready_customer(dual.model, 30.0, true)
    dual.step(0.1)
    expect(dual.model.sold == 2 and dual.streak == 2 and dual.score == 300, "Counter and drive sales in same tick both score")

func test_clock_and_freeze() -> void:
    var run := Challenge.new()
    run.step(-1)
    run.step(NAN)
    run.step(INF)
    expect(run.elapsed == 0, "Invalid deltas cannot advance time")
    run.step(299.95)
    expect(not run.finished and is_equal_approx(run.remaining(), 0.05), "Clock retains final partial tick")
    run.step(1000)
    expect(run.finished and run.elapsed == 300.0 and run.model.elapsed == 300.0, "Oversized final frame clips exactly to five minutes")
    var boundary := Challenge.new()
    boundary.step(299.95)
    boundary.model.queue.clear()
    ready_customer(boundary.model)
    boundary.model.player = Restaurant.COUNTER
    boundary.model.target = Restaurant.COUNTER
    boundary.model.counter_stock = 30
    boundary.model.serve_progress = 0.99
    boundary.step(1.0)
    expect(boundary.finished and boundary.model.sold == 1 and boundary.score == 150, "Final clipped tick includes eligible sale exactly once")
    var snapshot := run.model.snapshot()
    var score_before: int = run.score
    run.step(100)
    run.model.step(20)
    run.model.money = 1000
    expect(not run.buy("grill") and not run.boss_action() and not run.start_rush(), "Finished actions are blocked")
    expect(run.score == score_before and run.model.elapsed == 300.0 and run.model.sold == snapshot.sold, "Finished run is frozen")
    var fresh := Challenge.new()
    expect(fresh.model.snapshot() == Challenge.new().model.snapshot() and fresh.elapsed == 0 and fresh.score == 0, "Every run has identical fresh initial state")
    fresh.elapsed = 300.0 - 0.0000001
    fresh.step(1)
    expect(fresh.finished and fresh.elapsed == 300.0, "Sub-microsecond final remainder still completes")

func test_speedrun() -> void:
    var run := Challenge.new("speedrun")
    for i in 6:
        run.step(60)
    run.step(1.0e308)
    expect(run.elapsed < 500.0, "Huge speedrun delta remains bounded")
    expect(not run.finished and run.elapsed > 300 and run.remaining() == 0, "Speedrun has no five-minute cutoff")
    run.model.money = 1000000
    run.model.sold = 100
    for id in Restaurant.IDS:
        while run.model.upgrades[id] < Restaurant.LIMITS[id]:
            run.buy(id)
    expect(run.finished and run.all_upgrades_maxed() and run.model.staff.size() == 5, "All finite upgrades and all five staff finish speedrun immediately")
    expect(not run.buy("cook"), "Speedrun has no infinite hire ambiguity")

func test_records() -> void:
    var path := "user://score_test_records.json"
    DirAccess.remove_absolute(path)
    var records := Store.load_records(path)
    expect(Store.valid(records), "Missing records defaults validate")
    var run := Challenge.new()
    run.step(300)
    expect(Store.record_result(records, run.result(), path), "Completed result persists")
    var loaded := Store.load_records(path)
    expect(loaded.score_attack.runs == records.score_attack.runs and loaded.score_attack.best_score == records.score_attack.best_score and records.score_attack.runs == 1, "Records roundtrip")
    var previous := records.duplicate(true)
    expect(not Store.record_result(records, run.result(), "user://absent/records.json") and records == previous, "Failed record write preserves live records")
    var incomplete := Challenge.new()
    expect(not Store.record_result(records, incomplete.result(), path), "Abandoned run cannot count as completed record")
    var blocked_path := "user://record_rename_blocked"
    DirAccess.make_dir_absolute(blocked_path)
    var sentinel := FileAccess.open(blocked_path + "/existing", FileAccess.WRITE)
    sentinel.store_string("preserve existing bytes")
    sentinel.close()
    expect(not Store.record_result(records, run.result(), blocked_path) and records == previous, "Rename failure preserves live records")
    sentinel = FileAccess.open(blocked_path + "/existing", FileAccess.READ)
    expect(sentinel.get_as_text() == "preserve existing bytes" and not FileAccess.file_exists(blocked_path + ".tmp"), "Rename failure preserves existing data and cleans temporary")
    sentinel.close()
    DirAccess.remove_absolute(blocked_path + "/existing")
    DirAccess.remove_absolute(blocked_path)
    for name in ["Bronze", "Silver", "Gold"]:
        run.score = Challenge.MEDALS[name] - 1
        expect(run.medal() != name, "Medal threshold excludes score below " + name)
        run.score += 1
        expect(run.medal() == name, "Medal threshold includes exact " + name)
    run.score = 0
    var corrupt := records.duplicate(true)
    corrupt.score_attack.best_score = 1.5
    expect(not Store.valid(corrupt), "Fractional record score rejected")
    corrupt = records.duplicate(true)
    corrupt.speedrun.best_seconds = NAN
    expect(not Store.valid(corrupt), "Nonfinite record time rejected")
    corrupt = records.duplicate(true)
    corrupt.score_attack.best_medal = "Gold"
    expect(not Store.valid(corrupt), "Medal inconsistent with best score rejected")
    corrupt = records.duplicate(true)
    corrupt.speedrun.runs = 1
    expect(not Store.valid(corrupt), "Completed speedrun without positive best time rejected")
    var result := run.result()
    result.score = 21000
    result.medal = "Silver"
    expect(Store.record_result(records, result, path) and records.score_attack.best_score == 21000, "Higher score updates personal best")
    expect(Store.record_result(records, run.result(), path) and records.score_attack.best_score == 21000, "Lower completed score preserves personal best")
    var speed_result := {"completed":true,"mode":"speedrun","elapsed":900.0}
    expect(Store.record_result(records, speed_result, path) and records.speedrun.best_seconds == 900.0, "First speedrun time recorded")
    speed_result.elapsed = 850.0
    expect(Store.record_result(records, speed_result, path) and records.speedrun.best_seconds == 850.0, "Faster speedrun improves time")
    speed_result.elapsed = 950.0
    expect(Store.record_result(records, speed_result, path) and records.speedrun.best_seconds == 850.0, "Slower speedrun preserves time")
    var persisted := Store.load_records(path)
    expect(persisted.speedrun.best_seconds == 850.0 and persisted.speedrun.runs == 3 and persisted.score_attack.best_score == 21000, "Both mode records roundtrip independently")
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string("{bad json")
    file.close()
    expect(Store.load_records(path) == Store.defaults(), "Malformed records recover to defaults")
    DirAccess.remove_absolute(path)

func test_balance() -> void:
    var idle := Challenge.new()
    idle.step(300)
    expect(idle.score == 0 and idle.lost > 0 and idle.medal() == "None", "Unattended fresh run cannot earn medal")
    for skill in ["manual", "managed"]:
        var run := Challenge.new()
        for frame in 3000:
            if frame % 10 != 0:
                run.step(0.1)
                continue
            if skill == "managed":
                for id in ["cook", "cashier", "grill", "capacity", "value", "speed", "register", "table"]:
                    if run.model.can_buy(id):
                        run.buy(id)
            if run.model.carried == 0 and (run.model.upgrades.cook == 0 or run.model.counter_stock < 3):
                run.set_target(Restaurant.GRILL)
            elif run.model.carried >= run.model.capacity() or run.model.upgrades.cook > 0:
                run.set_target(Restaurant.COUNTER)
            run.boss_action()
            run.step(0.1)
        print("Balance %s: score=%d served=%d lost=%d medal=%s" % [skill,run.score,run.model.sold,run.lost,run.medal()])
        expect(run.finished and run.score > idle.score, "Active %s strategy beats unattended" % skill)
        expect(run.score == (34172 if skill == "manual" else 38189), "Career tuning preserves exact %s challenge score" % skill)

func test_natural_speedrun() -> void:
    var run := Challenge.new("speedrun")
    # No injected money, inventory, sales or upgrades: one decision per second.
    for frame in 6000:
        if frame % 10 == 0:
            for id in ["cook", "cashier", "grill", "capacity", "value", "speed", "register", "table", "fries", "drive"]:
                if run.model.can_buy(id):
                    run.buy(id)
            if run.model.fries_carried > 0:
                run.set_target(Restaurant.COUNTER)
            elif run.model.upgrades.fries > 0 and run.model.counter_fries < 2:
                run.set_target(Restaurant.FRIES)
            elif run.model.carried == 0 and (run.model.upgrades.cook == 0 or run.model.counter_stock < 3):
                run.set_target(Restaurant.GRILL)
            elif run.model.carried >= run.model.capacity() or run.model.upgrades.cook > 0:
                run.set_target(Restaurant.COUNTER)
            run.boss_action()
        run.step(0.1)
        if run.finished:
            break
    print("Balance natural speedrun: completed=%s seconds=%.1f served=%d" % [run.finished,run.elapsed,run.model.sold])
    expect(is_equal_approx(run.elapsed, 428.0) and run.model.sold == 147, "Career tuning preserves exact 428-second, 147-sale speedrun")
    expect(run.finished and run.elapsed <= 600.0 and run.all_upgrades_maxed(), "Natural earnings can purchase all finite upgrades within ten active minutes")
    expect(run.model.sold > 100 and run.model.staff.size() == 5 and run.model.upgrades.fries == 1 and run.model.upgrades.drive == 1, "Natural speedrun earns sales and completes staff, sides and drive-through")
