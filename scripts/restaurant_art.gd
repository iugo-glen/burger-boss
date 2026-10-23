extends Node2D
## Original vector art: chunky furniture, soft shadows and animated little people.
var model
var clock := 0.0
# Short-lived ghosts never enter the queue, save file or deterministic simulation.
var departures: Array[Dictionary] = []
const INK := Color("294743")
const SKINS := [Color("efb58d"), Color("ad7055"), Color("f7cfaa"), Color("ce8d65")]
const SHIRTS := [Color("e37355"), Color("849ec2"), Color("d4a84d"), Color("a58ebd"), Color("5c9f8d")]

func _ready() -> void:
    z_index = -1

func text(value: String, at: Vector2, size: int = 20, color: Color = INK) -> void:
    draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func box(rect: Rect2, color: Color, radius: int = 12) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    draw_style_box(style, rect)

func ellipse(at: Vector2, size: Vector2, color: Color) -> void:
    draw_set_transform(at, 0, size)
    draw_circle(Vector2.ZERO, 1, color)
    draw_set_transform(Vector2.ZERO)

func block(rect: Rect2, top: Color, front: Color, height: float = 35.0) -> void:
    box(Rect2(rect.position + Vector2(6, 13), rect.size + Vector2(4, height)), Color(0.1, 0.23, 0.2, 0.13))
    box(Rect2(rect.position + Vector2(0, height), rect.size), front)
    box(Rect2(rect.position, rect.size), top)
    draw_line(rect.position + Vector2(12, rect.size.y), rect.end - Vector2(12, 0), top.darkened(0.12), 2, true)

func burger(at: Vector2, factor: float = 1.0) -> void:
    box(Rect2(at + Vector2(-18, -4) * factor, Vector2(36, 11) * factor), Color("c47d36"), int(5 * factor))
    box(Rect2(at + Vector2(-20, -10) * factor, Vector2(40, 8) * factor), Color("75a74f"), int(3 * factor))
    box(Rect2(at + Vector2(-17, -15) * factor, Vector2(34, 8) * factor), Color("673e2e"), int(3 * factor))
    box(Rect2(at + Vector2(-19, -26) * factor, Vector2(38, 15) * factor), Color("f4ba56"), int(9 * factor))
    draw_circle(at + Vector2(-7, -21) * factor, 1.6 * factor, Color("fff2be"))
    draw_circle(at + Vector2(6, -19) * factor, 1.6 * factor, Color("fff2be"))

func fries(at: Vector2, factor: float = 1.0) -> void:
    for i in range(5):
        box(Rect2(at + Vector2(-14 + i * 6, -29 + (i % 2) * 4) * factor, Vector2(5, 22) * factor), Color("ffdb68"), 2)
    box(Rect2(at + Vector2(-16, -13) * factor, Vector2(32, 21) * factor), Color("cb6b43"), 4)
    draw_line(at + Vector2(-5, -7) * factor, at + Vector2(5, -7) * factor, Color("ffe7ae"), 3 * factor)

func person(at: Vector2, shirt: Color, skin: Color, role: String, moving: bool, carry: int = 0, carry_kind: String = "burger", side_carry: int = 0, sad: bool = false) -> void:
    ellipse(at + Vector2(0, 5), Vector2(23, 9), Color(0.12, 0.25, 0.22, 0.16))
    var bounce := sin(clock * 12 + at.x) * 2.0 if moving else sin(clock * 2 + at.x) * 0.7
    var pos := at + Vector2(0, bounce)
    var stride := sin(clock * 14) * 5.0 if moving else 0.0
    box(Rect2(pos + Vector2(-15, -14 + stride), Vector2(12, 18)), Color("354c4a"), 4)
    box(Rect2(pos + Vector2(3, -14 - stride), Vector2(12, 18)), Color("354c4a"), 4)
    box(Rect2(pos + Vector2(-22, -48), Vector2(44, 37)), shirt, 13)
    if role == "cook" or role == "you":
        box(Rect2(pos + Vector2(-12, -38), Vector2(24, 23)), Color("fff2dc"), 5)
    draw_circle(pos + Vector2(-23, -29), 7, skin)
    draw_circle(pos + Vector2(23, -29), 7, skin)
    draw_circle(pos + Vector2(0, -59), 19, skin)
    box(Rect2(pos + Vector2(-19, -76), Vector2(38, 13)), Color("594335"), 7)
    if role == "cook" or role == "you":
        box(Rect2(pos + Vector2(-22, -80), Vector2(44, 12)), Color("fff9ea"), 5)
        draw_circle(pos + Vector2(-11, -83), 10, Color("fff9ea"))
        draw_circle(pos + Vector2(3, -87), 12, Color("fff9ea"))
        draw_circle(pos + Vector2(15, -82), 9, Color("fff9ea"))
    elif role == "cashier":
        box(Rect2(pos + Vector2(-21, -77), Vector2(42, 10)), Color("ffcf68"), 4)
    draw_circle(pos + Vector2(-7, -58), 2, INK)
    draw_circle(pos + Vector2(7, -58), 2, INK)
    if sad:
        draw_arc(pos + Vector2(0, -46), 6, PI + 0.2, TAU - 0.2, 10, Color("a7604a"), 1.5, true)
    else:
        draw_arc(pos + Vector2(0, -53), 6, 0.2, 2.9, 10, Color("a7604a"), 1.5, true)
    if carry > 0:
        box(Rect2(pos + Vector2(8, -30), Vector2(37, 7)), Color("d9dccc"), 3)
        for i in range(mini(carry, 4)):
            if carry_kind == "fries":
                fries(pos + Vector2(26, -30 - i * 14), 0.8)
            else:
                burger(pos + Vector2(26, -30 - i * 14), 0.8)
    if side_carry > 0:
        fries(pos + Vector2(-27, -28), 0.75)
    if role == "you":
        draw_colored_polygon(PackedVector2Array([pos + Vector2(-7, -107), pos + Vector2(7, -107), pos + Vector2(0, -97)]), Color("ec9b3d"))

func meter(at: Vector2, progress: float, color: Color) -> void:
    box(Rect2(at, Vector2(140, 9)), Color("d5d5bd"), 4)
    if progress > 0.01:
        box(Rect2(at, Vector2(140 * clampf(progress, 0, 1), 9)), color, 4)

func _draw() -> void:
    if model == null:
        return
    draw_rect(Rect2(0, 160, 720, 836), Color("ebead4"))
    draw_rect(Rect2(15, 270, 690, 650), Color("e3d9b9"))
    for row in range(10):
        for col in range(10):
            var p := Vector2(15 + col * 69, 270 + row * 65)
            draw_rect(Rect2(p, Vector2(68, 64)), Color("f0e5c7") if (row + col) % 2 == 0 else Color("e9dfc0"))
    box(Rect2(15, 270, 690, 24), Color("649384"), 4)
    box(Rect2(15, 294, 690, 22), Color("35685e"), 2)
    for x in [55, 290, 620]:
        box(Rect2(x, 270, 85, 18), Color("99c9bc"), 4)
    # Three dimensional grill island.
    block(Rect2(75, 352, 190, 102), Color("e2a065"), Color("bd7447"), 35)
    box(Rect2(87, 363, 165, 68), Color("304e4b"), 9)
    for i in range(7):
        draw_line(Vector2(98 + i * 22, 370), Vector2(98 + i * 22, 424), Color("7d9790"), 3)
    for i in range(mini(model.grill_stock, 4)):
        burger(Vector2(112 + (i % 3) * 49, 410 + (i / 3) * 25), 0.75)
    for i in range(3):
        draw_circle(Vector2(112 + i * 57, 468), 5, Color("ffbf63"))
    if model.cook_progress > 0.05:
        for i in range(3):
            var steam := fmod(clock * 27 + i * 17, 48)
            draw_arc(Vector2(125 + i * 40, 370 - steam), 7, -1, 1, 12, Color(1, 1, 1, (1 - steam / 48) * 0.7), 3, true)
    meter(Vector2(100, 498), model.cook_progress, Color("e49b44"))
    text("%d ready · %d grills" % [model.grill_stock, model.upgrades.grill], Vector2(73, 534), 20)
    for i in range(int(model.upgrades.grill) - 1):
        box(Rect2(279, 365 + i * 35, 55, 28), Color("3e6158"), 5)
        for bar in range(4):
            draw_line(Vector2(286 + bar * 10, 371 + i * 35), Vector2(286 + bar * 10, 387 + i * 35), Color("a9b8a6"), 2)
    # Serving counter and register.
    block(Rect2(440, 353, 220, 100), Color("92bebc"), Color("4b8d91"), 37)
    box(Rect2(450, 363, 200, 70), Color("c1dbd0"), 8)
    block(Rect2(569, 363, 58, 35), Color("466b62"), Color("284b46"), 13)
    box(Rect2(578, 368, 39, 20), Color("a5d7bd"), 3)
    text("$", Vector2(590, 384), 17)
    for i in range(mini(model.counter_stock, 4)):
        burger(Vector2(475 + i * 23, 413), 0.85)
    if model.counter_fries > 0:
        fries(Vector2(543, 414), 0.65)
    meter(Vector2(475, 499), model.serve_progress, Color("4c9b83"))
    text("Burgers %d · Fries %d" % [model.counter_stock, model.counter_fries], Vector2(447, 534), 19)
    for i in range(int(model.upgrades.register) - 1):
        box(Rect2(451 + i * 48, 363, 40, 27), Color("486c63"), 5)
        box(Rect2(457 + i * 48, 367, 28, 13), Color("b2d7b8"), 3)
    # Floor action rings make the automatic interactions discoverable.
    draw_arc(Vector2(170, 480), 85, 0.1, 3.0, 32, Color(0.69, 0.4, 0.15, 0.25), 4, true)
    draw_arc(Vector2(540, 480), 85, 0.1, 3.0, 32, Color(0.2, 0.45, 0.37, 0.25), 4, true)
    # Expansion furniture and optional stations.
    if model.upgrades.fries > 0:
        block(Rect2(72, 603, 178, 78), Color("eac66b"), Color("b99341"), 32)
        box(Rect2(87, 616, 65, 42), Color("604f39"), 5)
        for i in range(5):
            box(Rect2(172 + i * 9, 616 + (i % 2) * 5, 6, 31), Color("ffda6c"), 2)
        meter(Vector2(91, 565), model.fries_progress, Color("e4b04e"))
        text("Fries: %d ready" % model.fries_stock, Vector2(86, 593), 20)
        for i in range(mini(model.fries_stock, 3)):
            fries(Vector2(165 + i * 24, 651), 0.65)
    else:
        box(Rect2(72, 620, 178, 72), Color(0.35, 0.43, 0.32, 0.07))
        text("Fries station", Vector2(96, 653), 20, Color("8b9983"))
        text("Unlock in Expand", Vector2(99, 677), 16, Color("8b9983"))
    for i in range(int(model.upgrades.table)):
        var p := Vector2(171 + (i % 2) * 170, 740 + (i / 2) * 90)
        ellipse(p + Vector2(-36, 9), Vector2(18, 13), Color("719e8e"))
        ellipse(p + Vector2(56, 9), Vector2(18, 13), Color("719e8e"))
        block(Rect2(p - Vector2(20, 24), Vector2(70, 42)), Color("d39d5b"), Color("a7773e"), 18)
    if model.upgrades.drive > 0:
        box(Rect2(547, 724, 147, 172), Color("718a83"), 8)
        draw_line(Vector2(673, 737), Vector2(673, 883), Color("f5e9c2"), 3)
        var car_y := 812 + sin(clock) * 3
        ellipse(Vector2(608, car_y + 19), Vector2(40, 24), Color(0.1, 0.22, 0.2, 0.2))
        box(Rect2(574, car_y - 51, 64, 108), Color("e98568"), 18)
        box(Rect2(580, car_y - 28, 52, 24), Color("92b9ba"), 8)
        box(Rect2(580, car_y + 24, 52, 16), Color("92b9ba"), 6)
        text("DRIVE", Vector2(570, 914), 20)
    # Plants and welcome mat.
    for x in [45, 674]:
        box(Rect2(x - 17, 867, 34, 34), Color("b87951"), 7)
        for i in range(4):
            ellipse(Vector2(x + sin(i * 2) * 13, 856 + cos(i * 2) * 8), Vector2(12, 20), Color("538c66"))
    box(Rect2(278, 873, 163, 52), Color("6b9683"), 6)
    text("WELCOME", Vector2(300, 906), 22, Color("f6ebc7"))
    var actors: Array[Dictionary] = []
    for customer in model.queue:
        actors.append({"pos":customer.position,"role":"customer","moving":customer.position.distance_to(customer.target) > 3,"carry":0,"kind":"burger","sides":0,"id":int(customer.id)})
    for diner in model.diners:
        actors.append({"pos":diner.position,"role":"customer","moving":false,"carry":1,"kind":"burger","sides":0,"id":2})
    for worker in model.staff:
        actors.append({"pos":worker.position,"role":worker.role,"moving":worker.state.begins_with("walking") or worker.state.begins_with("carrying"),"carry":worker.carried,"kind":worker.carry_kind,"sides":0,"id":0})
    actors.append({"pos":model.player,"role":"you","moving":model.player.distance_to(model.target) > 3,"carry":model.carried,"kind":"burger","sides":model.fries_carried,"id":0})
    for departure in departures:
        actors.append({"pos":departure.position,"role":"customer","moving":true,"carry":0,"kind":"burger","sides":0,"id":departure.id,"sad":true})
    actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
    for actor in actors:
        var shirt: Color = SHIRTS[actor.id % SHIRTS.size()]
        if actor.role == "cook":
            shirt = Color("f6f0d9")
        elif actor.role == "cashier":
            shirt = Color("4b9b87")
        elif actor.role == "you":
            shirt = Color("e97051")
        person(actor.pos, shirt, SKINS[actor.id % SKINS.size()], actor.role, actor.moving, actor.carry, actor.kind, actor.sides, actor.get("sad", false))
        if actor.get("sad", false):
            box(Rect2(actor.pos + Vector2(-33, -121), Vector2(66, 28)), Color("fff1d1"), 7)
            text("Hungry", actor.pos + Vector2(-27, -101), 17, Color("a34e36"))
    var worker_numbers := {"cook":0,"cashier":0}
    for worker in model.staff:
        worker_numbers[worker.role] += 1
        var job: String = {"balanced":"Auto", "grill":"Burgers", "fries":"Fries", "counter":"Counter", "drive":"Drive"}.get(worker.assignment, worker.assignment)
        text("%s #%d · %s" % [str(worker.role).capitalize(), worker_numbers[worker.role], job], worker.position + Vector2(-48, 27), 14, Color("45675a"))
        text(worker.state.capitalize(), worker.position + Vector2(-42, 44), 12, Color("607568"))
    _draw_orders()

func _draw_orders() -> void:
    var head_burger := false
    var head_drive := false
    for customer in model.queue:
        if _shows_patience(customer):
            var remaining: float = clampf(customer.patience / maxf(1, customer.max_patience), 0, 1)
            var bar_at: Vector2 = customer.position + Vector2(20, -66)
            box(Rect2(bar_at, Vector2(30, 5)), Color("c5ccb8"), 2)
            box(Rect2(bar_at, Vector2(maxf(1, 30 * remaining), 5)), _patience_colour(remaining), 2)
        var drive: bool = customer.order == "drive"
        if (drive and head_drive) or (not drive and head_burger):
            continue
        if drive:
            head_drive = true
        else:
            head_burger = true
        # Gold tickets explain the physical boss handoff instead of using an obscure icon.
        var special: bool = customer.special and model.rush.active
        var at := Vector2((410 if drive else 561) if special else (443 if drive else 618), clampf(customer.position.y - 38, 555, 835))
        box(Rect2(at, Vector2(143, 93) if special else Vector2(86, 67)), Color("f6cb69") if special else Color("fff6dd"), 10)
        text("BOSS COMBO" if special else ("COMBO" if customer.combo else "BURGER"), at + Vector2(7, 19), 17 if special else 16)
        var icon_y := 70 if special else 51
        if special:
            text("You at drive" if drive else "You at counter", at + Vector2(7, 42), 17)
        burger(at + Vector2(25, icon_y), 0.6)
        if customer.combo:
            text("+", at + Vector2(41, icon_y - 4), 17)
            fries(at + Vector2(65, icon_y - 2), 0.55)
        if _shows_patience(customer):
            var remaining: float = clampf(customer.patience / maxf(1, customer.max_patience), 0, 1)
            var width := 129.0 if special else 72.0
            var bar_y := 84 if special else 58
            box(Rect2(at + Vector2(7, bar_y), Vector2(width, 5)), Color("d7d5be"), 2)
            box(Rect2(at + Vector2(7, bar_y), Vector2(maxf(1, width * remaining), 5)), _patience_colour(remaining), 2)

func _patience_colour(remaining: float) -> Color:
    if model.challenge_patience:
        return Color("e06c4e") if remaining < 0.35 else Color("68a582")
    return Color("e06c4e") if remaining <= 0.2 else (Color("d49a39") if remaining <= 0.5 else Color("68a582"))

func _shows_patience(customer: Dictionary) -> bool:
    return model != null and customer.has("patience")

func present_departure(customer: Dictionary) -> void:
    departures.append({"id":int(customer.id),"position":customer.position,"age":0.0})

func step_departures(delta: float) -> void:
    for departure in departures:
        departure.age += delta
        departure.position = departure.position.move_toward(Vector2(360, 960), delta * 175)
    departures = departures.filter(func(departure): return departure.age < 3.5 and departure.position.y < 954)

func departure_telemetry() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for departure in departures:
        result.append({"id":departure.id,"x":departure.position.x,"y":departure.position.y,"age":departure.age,"sad":true})
    return result
