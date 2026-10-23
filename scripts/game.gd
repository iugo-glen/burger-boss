extends Node2D
## Presentation coordinator; gameplay and persistence are independently testable.
const Restaurant = preload("res://scripts/restaurant.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Art = preload("res://scripts/restaurant_art.gd")
const Sound = preload("res://scripts/kitchen_sound.gd")
const SIZE := Vector2(720, 1280)
const PAGES := [["grill", "register", "speed", "value", "capacity"], ["cook", "cashier", "table", "fries", "drive"]]
const TITLES := {"grill":"Grill", "register":"Register", "speed":"Speed", "value":"Recipe", "capacity":"Tray", "cook":"Hire cook", "cashier":"Hire cashier", "table":"Table", "fries":"Fries", "drive":"Drive-thru"}
var model = Restaurant.new()
var art: Node2D
var sound: Node
var page := 0
var paused := false
var unfocused := false
var muted := false
var buttons: Array[Dictionary] = []
var pointer := -1
var anchor := Vector2.ZERO
var pointer_pos := Vector2.ZERO
var dragging := false
var autosave := 0.0
var save_status := "Progress saves on this device"
var clock := 0.0
var last_sale := 0
var telemetry_timer := 0.0
var keyboard_moving := false
var popups: Array[Dictionary] = []

func _ready() -> void:
    SaveStore.load_into(model)
    last_sale = model.sale_serial
    art = Art.new()
    art.model = model
    add_child(art)
    sound = Sound.new()
    add_child(sound)
    get_viewport().size_changed.connect(_fit)
    _fit()

func _fit() -> void:
    var space := get_viewport_rect().size
    var factor := minf(space.x / SIZE.x, space.y / SIZE.y)
    scale = Vector2.ONE * factor
    position = (space - SIZE * factor) * 0.5

func _process(delta: float) -> void:
    clock += delta
    if not paused and not unfocused:
        var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
        direction += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
        if pointer >= 0 and dragging:
            direction = (pointer_pos - anchor).limit_length(65) / 65.0
        if direction.length() > 0.05:
            model.set_target(model.player + direction.limit_length(1) * 140)
            keyboard_moving = pointer < 0
        elif keyboard_moving:
            model.set_target(model.player)
            keyboard_moving = false
        model.step(minf(delta, 0.1))
        if model.sale_serial != last_sale:
            last_sale = model.sale_serial
            popups.append({"pos":Vector2(540, 330), "age":0.0, "text":"+$%d" % model.last_earned})
            if not muted:
                sound.play_note(880.0)
        autosave += delta
        if autosave >= 8.0:
            _save()
            autosave = 0.0
    for popup in popups:
        popup.age += delta
    popups = popups.filter(func(p): return p.age < 1.4)
    art.clock = clock
    art.queue_redraw()
    queue_redraw()
    telemetry_timer += delta
    if OS.has_feature("web") and telemetry_timer > 0.5:
        telemetry_timer = 0.0
        var state := {"elapsed":model.elapsed,"money":model.money,"sold":model.sold,"carried":model.carried,"grill_stock":model.grill_stock,"counter_stock":model.counter_stock,"player":{"x":model.player.x,"y":model.player.y},"paused":paused or unfocused,"tutorial":model.tutorial(),"upgrades":model.upgrades}
        JavaScriptBridge.eval("window.__burgerBoss = " + JSON.stringify(state), true)

func _save() -> void:
    save_status = "Saved on this device" if SaveStore.save(model) else "Save unavailable — keep this tab open"

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        unfocused = true
        pointer = -1
        dragging = false
        if is_node_ready():
            model.set_target(model.player)
            _save()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
        unfocused = false
    elif what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
        _save()

func _local(screen: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * screen

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _toggle_pause()
    elif event is InputEventScreenTouch:
        if event.pressed and pointer == -1:
            _press(_local(event.position), event.index)
        elif not event.pressed and event.index == pointer:
            _release()
    elif event is InputEventScreenDrag and event.index == pointer:
        _drag(_local(event.position))
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
        if event.pressed:
            _press(_local(event.position), 100)
        elif pointer == 100:
            _release()
    elif event is InputEventMouseMotion and pointer == 100:
        _drag(_local(event.position))

func _toggle_pause() -> void:
    paused = not paused
    model.set_target(model.player)
    _release()
    _save()

func _press(pos: Vector2, id: int) -> void:
    for button in buttons:
        if button.rect.has_point(pos):
            match button.id:
                "pause": _toggle_pause()
                "sound": muted = not muted
                "page": page = 1 - page
                _:
                    if not paused and model.buy(button.id):
                        if not muted:
                            sound.play_note(660.0)
                        _save()
            return
    if paused or unfocused or pos.y < 260 or pos.y > 985:
        return
    pointer = id
    anchor = pos
    pointer_pos = pos
    dragging = false
    # Tapping an island walks to its working edge instead of onto its surface.
    if Rect2(75, 345, 190, 145).has_point(pos):
        model.set_target(Vector2(170, 495))
    elif Rect2(440, 345, 220, 145).has_point(pos):
        model.set_target(Vector2(540, 495))
    else:
        model.set_target(pos)

func _drag(pos: Vector2) -> void:
    pointer_pos = pos
    if anchor.distance_to(pos) > 14:
        dragging = true

func _release() -> void:
    if dragging:
        model.set_target(model.player)
    pointer = -1
    dragging = false

func _text(value: String, at: Vector2, size: int, color: Color = Color("263b3b")) -> void:
    draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _box(rect: Rect2, color: Color, radius: float = 16.0) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(int(radius))
    draw_style_box(style, rect)

func _button(id: String, rect: Rect2) -> void:
    buttons.append({"id":id, "rect":rect})

func _draw() -> void:
    buttons.clear()
    _box(Rect2(0, 0, 720, 160), Color("193e3c"), 0)
    _text("BURGER BOSS", Vector2(28, 52), 38, Color("ffcf68"))
    _text("YOUR LITTLE RESTAURANT", Vector2(30, 77), 15, Color("c6ded3"))
    _box(Rect2(28, 94, 225, 49), Color("2e5850"))
    _text("$ %d" % model.money, Vector2(44, 129), 31, Color("fff1bb"))
    _text("%d served" % model.sold, Vector2(278, 125), 24, Color.WHITE)
    _box(Rect2(550, 24, 68, 54), Color("2e5850"))
    _text("OFF" if muted else "SFX", Vector2(563, 58), 20, Color.WHITE)
    _button("sound", Rect2(550, 24, 68, 54))
    _box(Rect2(630, 24, 64, 54), Color("2e5850"))
    _text(">" if paused else "II", Vector2(652, 59), 26, Color.WHITE)
    _button("pause", Rect2(630, 24, 64, 54))
    _text("TRAY %d/%d" % [model.carried, model.capacity()], Vector2(470, 125), 22, Color("ffcf68"))
    _box(Rect2(20, 177, 680, 77), Color("fff7df"))
    _text("NEXT UP", Vector2(38, 202), 15, Color("a45b36"))
    var tutorial: String = model.tutorial()
    var font := ThemeDB.fallback_font
    var tutorial_size := 22
    while font.get_string_size(tutorial, HORIZONTAL_ALIGNMENT_LEFT, -1, tutorial_size).x > 642 and tutorial_size > 16:
        tutorial_size -= 1
    _text(tutorial, Vector2(38, 234), tutorial_size)
    _box(Rect2(0, 996, 720, 284), Color("fff7e6"), 0)
    _text("GROW YOUR KITCHEN" if page == 0 else "BUILD YOUR TEAM", Vector2(24, 1031), 23)
    _box(Rect2(507, 1006, 190, 37), Color("dfe9da"))
    _text("Team & more >" if page == 0 else "< Upgrades", Vector2(522, 1032), 20)
    _button("page", Rect2(507, 1006, 190, 37))
    for i in range(5):
        var id: String = PAGES[page][i]
        var rect := Rect2(18 + (i % 3) * 234, 1055 + (i / 3) * 87, 218, 77)
        var enabled: bool = model.can_buy(id)
        _box(rect, Color("267361") if enabled else Color("dce3d4"))
        var ink := Color.WHITE if enabled else Color("435a53")
        _text(TITLES[id], rect.position + Vector2(12, 29), 22, ink)
        var reason: String = model.lock_reason(id)
        var subtitle := "$%d" % model.cost(id)
        if not reason.is_empty() and not reason.begins_with("Need") and not reason.begins_with("Not enough"):
            subtitle = reason
        _text(subtitle.left(24), rect.position + Vector2(12, 57), 18, ink)
        _button(id, rect)
    _text(save_status, Vector2(23, 1265), 17, Color("607467"))
    if not model.notice.is_empty():
        _box(Rect2(28, 926, 664, 40), Color("193e3c"))
        _text(model.notice.left(55), Vector2(43, 954), 20, Color("fff1bb"))
    _text("Tap to walk • drag to steer • WASD / arrows", Vector2(115, 988), 20, Color("547064"))
    if pointer >= 0 and dragging:
        draw_circle(anchor, 65, Color(0.12, 0.3, 0.25, 0.2))
        draw_arc(anchor, 65, 0, TAU, 48, Color("ffffff"), 3, true)
        draw_circle(anchor + (pointer_pos - anchor).limit_length(65), 25, Color(1, 1, 1, 0.7))
    for popup in popups:
        _text(popup.text, popup.pos + Vector2(0, -popup.age * 55), 32, Color("337553"))
    if paused or unfocused:
        _box(Rect2(0, 161, 720, 835), Color(0.08, 0.2, 0.17, 0.85), 0)
        _text("TAKE A BREATHER", Vector2(158, 523), 35, Color("ffcf68"))
        _text("Your restaurant is paused", Vector2(201, 571), 25, Color.WHITE)
        _text("Tap > above to continue", Vector2(215, 615), 22, Color.WHITE)
