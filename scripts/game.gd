extends Node2D
## Original Godot 4 arcade-idle prototype; no copied third-party game code.
const SIZE := Vector2(720, 1280)
const SAVE := "user://burger_boss.json"
var player := Vector2(320, 750)
var target := player
var money := 0
var burgers := 0
var sold := 0
var queue := 3
var grill := 1
var register := 1
var cooks := 0
var cashiers := 0
var tables := 0
var drive_thru := false
var level := 1
var cook_timer := 0.0
var serve_timer := 0.0
var arrival_timer := 0.0
var save_timer := 0.0
var finger_down := false
var messages: Array[String] = []
var buttons: Array[Dictionary] = []

func _ready() -> void:
    load_progress()
    target = player
    get_window().content_scale_size = Vector2i(720, 1280)
    set_process(true)
    queue_redraw()

func item_price(id: String) -> int:
    match id:
        "grill": return int(25 * pow(1.6, grill - 1))
        "register": return int(35 * pow(1.6, register - 1))
        "cook": return 75 * (cooks + 1)
        "cashier": return 110 * (cashiers + 1)
        "table": return 55 * (tables + 1)
        "drive": return 450
        "expand": return 900 * level
    return 999999

func buy(id: String) -> void:
    var cost := item_price(id)
    if money < cost:
        announce("Need $%d" % cost)
        return
    if id == "drive" and (drive_thru or sold < 25):
        announce("Unlock after 25 sales")
        return
    if id == "expand" and sold < level * 50:
        announce("Unlock after %d sales" % (level * 50))
        return
    money -= cost
    match id:
        "grill": grill += 1
        "register": register += 1
        "cook": cooks += 1
        "cashier": cashiers += 1
        "table": tables += 1
        "drive": drive_thru = true
        "expand": level += 1
    announce("Upgrade purchased!")
    save_progress()

func announce(message: String) -> void:
    messages.append(message)
    if messages.size() > 3:
        messages.pop_front()

func _process(delta: float) -> void:
    var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    if keyboard.length() > 0.05:
        target = player + keyboard * 100
    player = player.move_toward(target, 250 * delta)
    player.x = clampf(player.x, 42, 678)
    player.y = clampf(player.y, 200, 980)
    var near_grill := player.distance_to(Vector2(170, 430)) < 140
    var near_counter := player.distance_to(Vector2(540, 430)) < 140
    if near_grill or cooks > 0:
        cook_timer += delta * (float(grill) * (1.0 if near_grill else 0.0) + cooks * 0.7)
        while cook_timer >= 2.5 and burgers < 6 + grill * 5:
            cook_timer -= 2.5
            burgers += 1
    if (near_counter or cashiers > 0) and burgers > 0 and queue > 0:
        serve_timer += delta * (float(register) * (1.0 if near_counter else 0.0) + cashiers * 0.8)
        if serve_timer > 1.6:
            serve_timer = 0.0
            burgers -= 1
            queue -= 1
            sold += 1
            var earned := 8 + register * 2 + tables * 3 + level * 2
            money += earned
            if sold % 10 == 0:
                announce("10 more customers served!")
    arrival_timer += delta
    if arrival_timer > maxf(1.3, 4.0 - 0.16 * level - 0.08 * tables):
        arrival_timer = 0.0
        queue = mini(queue + 1, 10 + tables * 2)
    if drive_thru and burgers > 0 and queue > 0:
        save_timer += delta
        if save_timer > 5:
            save_timer = 0
            burgers -= 1
            queue -= 1
            sold += 1
            money += 18 + 3 * level
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            interact(event.position)
            finger_down = true
        else:
            finger_down = false
    elif event is InputEventScreenDrag and finger_down:
        if event.position.y < 990:
            target = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        interact(event.position)

func interact(pos: Vector2) -> void:
    for b in buttons:
        if b["rect"].has_point(pos):
            buy(b["id"])
            return
    if pos.y < 990:
        target = pos

func label_at(message: String, pos: Vector2, size: int = 25, color: Color = Color.WHITE) -> void:
    draw_string(ThemeDB.fallback_font, pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color, radius: int = 18) -> void:
    draw_rect(rect, color)
    draw_rect(rect, Color("3d4039"), false, 2)

func _draw() -> void:
    buttons.clear()
    draw_rect(Rect2(Vector2.ZERO, SIZE), Color("f7eaca"))
    draw_rect(Rect2(20, 170, 680, 835), Color("d3e9c5"))
    draw_rect(Rect2(20, 170, 680, 835), Color("6d9472"), false, 5)
    draw_rect(Rect2(0, 0, 720, 158), Color("344d3f"))
    label_at("BURGER BOSS", Vector2(35, 65), 44, Color("ffda6b"))
    label_at("$%d     Burgers: %d     Sold: %d" % [money, burgers, sold], Vector2(35, 110), 26)
    label_at("Customers waiting: %d" % queue, Vector2(35, 145), 23, Color("ffda6b"))
    panel(Rect2(65, 345, 210, 155), Color("e38a4a"))
    label_at("GRILL", Vector2(100, 393), 29)
    label_at("Level %d" % grill, Vector2(100, 430))
    label_at("Stand here", Vector2(86, 465), 20)
    panel(Rect2(445, 345, 210, 155), Color("64a9ba"))
    label_at("COUNTER", Vector2(463, 393), 27)
    label_at("Level %d" % register, Vector2(475, 430))
    label_at("Serve here", Vector2(469, 465), 20)
    for i in range(queue):
        var x := 415.0 + float(i % 5) * 46
        var y := 560.0 + float(i / 5) * 54
        draw_circle(Vector2(x, y), 18, Color("df9c76"))
        draw_circle(Vector2(x, y - 12), 6, Color("543d2d"))
    for i in range(tables):
        var x := 120.0 + float(i % 4) * 115
        var y := 670.0 + float(i / 4) * 85
        draw_rect(Rect2(x, y, 68, 48), Color("aa784a"))
    draw_circle(player, 30, Color("e35f51"))
    draw_circle(player + Vector2(0, -19), 19, Color("f4c29e"))
    draw_rect(Rect2(player.x - 19, player.y - 45, 38, 12), Color.WHITE)
    label_at("YOU", player + Vector2(-27, 55), 21, Color("283a2e"))
    label_at("Cooks: %d    Cashiers: %d    Tables: %d" % [cooks, cashiers, tables], Vector2(45, 895), 25, Color("283a2e"))
    if drive_thru:
        label_at("DRIVE-THRU OPEN!", Vector2(45, 939), 24, Color("365b39"))
    else:
        label_at("Walk to grill, then counter to serve", Vector2(45, 939), 21, Color("365b39"))
    draw_rect(Rect2(0, 1005, 720, 275), Color("fff6e2"))
    var options := ["grill", "register", "cook", "cashier", "table", "drive", "expand"]
    for i in range(options.size()):
        var id: String = options[i]
        var row := i / 4
        var col := i % 4
        var rect := Rect2(14 + col * 178, 1020 + row * 115, 163, 96)
        panel(rect, Color("39795e"))
        label_at(id.capitalize(), rect.position + Vector2(10, 37), 22)
        label_at("$%d" % item_price(id), rect.position + Vector2(10, 72), 23, Color("ffdd75"))
        buttons.append({"id": id, "rect": rect})
    if messages.size() > 0:
        label_at(messages.back(), Vector2(35, 995), 21, Color("334a38"))

func save_progress() -> void:
    var data := {"money": money, "burgers": burgers, "sold": sold, "grill": grill, "register": register, "cooks": cooks, "cashiers": cashiers, "tables": tables, "drive": drive_thru, "level": level}
    var file := FileAccess.open(SAVE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func load_progress() -> void:
    if not FileAccess.file_exists(SAVE):
        return
    var file := FileAccess.open(SAVE, FileAccess.READ)
    if file == null:
        return
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return
    money = int(data.get("money", 0))
    burgers = int(data.get("burgers", 0))
    sold = int(data.get("sold", 0))
    grill = int(data.get("grill", 1))
    register = int(data.get("register", 1))
    cooks = int(data.get("cooks", 0))
    cashiers = int(data.get("cashiers", 0))
    tables = int(data.get("tables", 0))
    drive_thru = bool(data.get("drive", false))
    level = int(data.get("level", 1))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        save_progress()
