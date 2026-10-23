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
    test_queue_and_seats()
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
        expect(model.queue.size() <= 8 + int(model.upgrades.table), "Queue stays bounded")
    expect(model.sold > sales_at_start + 50, "Ten-minute automated run makes sustained progress")
    expect(minimum_window_sales > 0, "Every minute has fulfilled customers: no queue or worker deadlock")
    expect(model.upgrades.drive == 1, "Earned progression reaches drive-through")
    print("Ten-minute run: %d additional sales, $%d cash, minimum %d sales/minute" % [model.sold-sales_at_start,model.money,minimum_window_sales])
