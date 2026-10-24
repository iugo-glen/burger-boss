extends Node2D
## Presentation coordinator; gameplay and persistence are independently testable.
const Restaurant = preload("res://scripts/restaurant.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const Art = preload("res://scripts/restaurant_art.gd")
const Sound = preload("res://scripts/kitchen_sound.gd")
const RushHUD = preload("res://scripts/rush_hud.gd")
const PauseMenu = preload("res://scripts/pause_menu.gd")
const ChallengeHUD = preload("res://scripts/challenge_hud.gd")
const ScoreChallenge = preload("res://scripts/score_challenge.gd")
const ChallengeStore = preload("res://scripts/challenge_store.gd")
const SIZE := Vector2(720, 1280)
const UPGRADE_IDS := ["grill", "register", "speed", "value", "capacity"]
const UI_PREFS := "user://burger_boss_ui.cfg"
const TITLES := {"grill":"Grill", "register":"Register", "speed":"Speed", "value":"Recipe", "capacity":"Tray", "cook":"Hire cook", "cashier":"Hire cashier", "table":"Table", "fries":"Fries", "drive":"Drive-thru"}
var model = Restaurant.new()
var career_model: RefCounted
var challenge: RefCounted
var challenge_panel := ""
var challenge_records := {}
var challenge_record_saved := true
var challenge_recorded := false
var art: Node2D
var sound: Node
var menu := "upgrades"
var selected_staff := {"cook":0,"cashier":0}
var guide_visible := true
var prefs_saved := true
var notice_text := ""
var notice_remaining := 0.0
var seen_notice := ""
var paused := false
var reset_confirm_visible := false
var reset_error := ""
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
var wait_for_keyboard_release := false
var popups: Array[Dictionary] = []
var presentation_model: RefCounted

func _ready() -> void:
    SaveStore.load_into(model)
    career_model = model
    challenge_records = ChallengeStore.load_records()
    _load_ui_prefs()
    _show_notice(model.notice)
    last_sale = model.sale_serial
    art = Art.new()
    _bind_presentation_model()
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
    _record_finished_challenge()
    clock += delta
    notice_remaining = maxf(0.0, notice_remaining - delta)
    if not paused and not unfocused and not ChallengeHUD.owns_input(self):
        var direction := Vector2.ZERO
        if wait_for_keyboard_release:
            if not _movement_keys_down():
                wait_for_keyboard_release = false
        else:
            direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
            direction += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
        if pointer >= 0 and dragging:
            direction = (pointer_pos - anchor).limit_length(65) / 65.0
        if direction.length() > 0.05:
            model.set_target(model.player + direction.limit_length(1) * 140)
            keyboard_moving = pointer < 0
        elif keyboard_moving:
            model.set_target(model.player)
            keyboard_moving = false
        if challenge != null:
            challenge.step(minf(delta, 0.1))
            _record_finished_challenge()
        else:
            model.step(minf(delta, 0.1))
        art.step_departures(minf(delta, 0.1))
        if model.sale_serial != last_sale:
            last_sale = model.sale_serial
            popups.append({"pos":Vector2(540, 330), "age":0.0, "text":"+$%d" % model.last_earned})
            if not muted:
                sound.play_note(880.0)
        autosave += delta
        if autosave >= 8.0:
            _save()
            autosave = 0.0
    if model.notice != seen_notice:
        _show_notice(model.notice)
    for popup in popups:
        popup.age += delta
    popups = popups.filter(func(p): return p.age < 1.4)
    art.clock = clock
    art.queue_redraw()
    queue_redraw()
    telemetry_timer += delta
    if OS.has_feature("web") and telemetry_timer > 0.5:
        telemetry_timer = 0.0
        var state := {"elapsed":model.elapsed,"money":model.money,"sold":model.sold,"carried":model.carried,"grill_stock":model.grill_stock,"counter_stock":model.counter_stock,"player":{"x":model.player.x,"y":model.player.y},"paused":paused or unfocused,"pause_menu_visible":paused or unfocused,"reset_confirm_visible":reset_confirm_visible,"reset_error":reset_error,"muted":muted,"keyboard_release_pending":wait_for_keyboard_release,"tutorial":model.tutorial(),"upgrades":model.upgrades,"guide_visible":guide_visible,"tutorial_visible":guide_visible and challenge == null,"menu":menu,"selected_staff":selected_staff.duplicate(),"notice_visible":notice_remaining > 0.0,"notice_text":notice_text if notice_remaining > 0.0 else "","prefs_saved":prefs_saved}
        state.merge(RushHUD.telemetry(model))
        state["departing_customers"] = art.departure_telemetry()
        state.merge(_challenge_telemetry())
        JavaScriptBridge.eval("window.__burgerBoss = " + JSON.stringify(state), true)

func _movement_keys_down() -> bool:
    for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
        if Input.is_physical_key_pressed(key):
            return true
    return false

func _load_ui_prefs() -> void:
    var preferences := ConfigFile.new()
    if preferences.load(UI_PREFS) == OK:
        var saved_visibility: Variant = preferences.get_value("help", "guide_visible", true)
        if typeof(saved_visibility) == TYPE_BOOL:
            guide_visible = saved_visibility
        var saved_mute: Variant = preferences.get_value("sound", "muted", false)
        if typeof(saved_mute) == TYPE_BOOL:
            muted = saved_mute

func _save_ui_prefs() -> void:
    var preferences := ConfigFile.new()
    preferences.set_value("help", "guide_visible", guide_visible)
    preferences.set_value("sound", "muted", muted)
    prefs_saved = preferences.save(UI_PREFS) == OK
    if not prefs_saved:
        save_status = "Preferences could not be saved on this device"

func _set_guide(visible: bool) -> void:
    guide_visible = visible
    _save_ui_prefs()
    queue_redraw()

func _show_notice(message: String) -> void:
    seen_notice = model.notice
    notice_text = message
    notice_remaining = 4.0 if not message.is_empty() else 0.0

func _save() -> void:
    if challenge != null:
        return
    save_status = "Saved on this device" if SaveStore.save(career_model) else "Save unavailable: keep this tab open"

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        unfocused = true
        wait_for_keyboard_release = true
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
    var menu_owned_input := paused or unfocused or reset_confirm_visible or ChallengeHUD.owns_input(self)
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        if ChallengeHUD.owns_input(self):
            if challenge_panel == "choose":
                _close_challenges()
            elif challenge_panel == "abandon" or challenge_panel == "restart":
                challenge_panel = ""
        elif reset_confirm_visible:
            _cancel_reset()
        elif not unfocused:
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
    if menu_owned_input:
        get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
    if reset_confirm_visible or ChallengeHUD.owns_input(self):
        return
    paused = not paused
    wait_for_keyboard_release = true
    model.set_target(model.player)
    _release()
    keyboard_moving = false
    _save()
    queue_redraw()

func _open_reset() -> void:
    if challenge != null:
        challenge_panel = "restart"
        _stop_input()
        return
    paused = true
    reset_confirm_visible = true
    reset_error = ""
    model.set_target(model.player)
    _release()
    keyboard_moving = false
    queue_redraw()

func _cancel_reset() -> void:
    reset_confirm_visible = false
    reset_error = ""
    paused = true
    _release()
    queue_redraw()

func _confirm_reset() -> void:
    if not reset_confirm_visible or challenge != null:
        return
    var fresh = SaveStore.reset_progress()
    if fresh == null:
        reset_error = "Could not save a fresh start. Your restaurant is unchanged."
        paused = true
        queue_redraw()
        return
    # The fresh state is saved before replacing the live restaurant.
    model = fresh
    career_model = model
    _bind_presentation_model()
    menu = "upgrades"
    selected_staff = {"cook":0,"cashier":0}
    popups.clear()
    autosave = 0.0
    clock = 0.0
    last_sale = model.sale_serial
    telemetry_timer = 0.0
    pointer = -1
    dragging = false
    anchor = Vector2.ZERO
    pointer_pos = Vector2.ZERO
    keyboard_moving = false
    model.set_target(model.player)
    wait_for_keyboard_release = true
    reset_confirm_visible = false
    reset_error = ""
    paused = false
    save_status = "Fresh restaurant saved on this device"
    _set_guide(true)
    _show_notice(model.notice)
    art.queue_redraw()
    queue_redraw()

func _press(pos: Vector2, id: int) -> void:
    if ChallengeHUD.handle_press(self, pos):
        return
    if PauseMenu.handle_press(self, pos):
        return
    for button in buttons:
        if not button.rect.has_point(pos):
            continue
        # A just-dismissed hint must not leave an invisible floor hit target.
        if button.id == "guide_close" and not guide_visible:
            continue
        if button.id == "notice_close" and notice_remaining <= 0.0:
            continue
        match button.id:
            "pause": _toggle_pause()
            "sound":
                muted = not muted
                _save_ui_prefs()
            "help":
                if challenge != null:
                    _show_notice("Serve fast, protect streaks, and buy upgrades. Timer counts active play.")
                else:
                    _set_guide(true)
            "guide_close": _set_guide(false)
            "notice_close": notice_remaining = 0.0
            "upgrades", "staff", "expand": menu = button.id
            _:
                if RushHUD.handle(self, button.id):
                    queue_redraw()
                    return
                if not paused and not unfocused:
                    var purchased: bool = challenge.buy(button.id) if challenge != null else model.buy(button.id)
                    _record_finished_challenge()
                    _show_notice(model.notice)
                    if purchased:
                        if not muted:
                            sound.play_note(660.0)
                        _save()
        queue_redraw()
        return
    var floor_top := 270.0 if guide_visible or challenge != null else 160.0
    if paused or unfocused or pos.y < floor_top or pos.y >= 966:
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

func _fit_text(value: String, at: Vector2, maximum_width: float, size: int, color: Color) -> void:
    var fitted_size := size
    while ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size).x > maximum_width and fitted_size > 14:
        fitted_size -= 1
    _text(value, at, fitted_size, color)

func _guide_lines(value: String) -> Array[String]:
    var lines: Array[String] = [""]
    for word in value.split(" "):
        var candidate := word if lines[-1].is_empty() else lines[-1] + " " + word
        if ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x > 555:
            lines.append(word)
        else:
            lines[-1] = candidate
    return lines

func _card(id: String, rect: Rect2, description: Array[String] = []) -> void:
    var enabled: bool = model.can_buy(id)
    var ink := Color.WHITE if enabled else Color("435a53")
    _box(rect, Color("267361") if enabled else Color("dce3d4"))
    _text(TITLES[id], rect.position + Vector2(12, 29), 22, ink)
    var reason: String = model.lock_reason(id)
    var subtitle := "$%d" % model.cost(id) if reason.is_empty() else reason
    _fit_text(subtitle, rect.position + Vector2(12, 57), rect.size.x - 24, 21, ink)
    for i in range(description.size()):
        _fit_text(description[i], rect.position + Vector2(12, 88 + i * 23), rect.size.x - 24, 18, ink)
    _button(id, rect)

func _draw() -> void:
    buttons.clear()
    _box(Rect2(0, 0, 720, 160), Color("193e3c"), 0)
    _text("BURGER BOSS", Vector2(28, 52), 38, Color("ffcf68"))
    _text("YOUR LITTLE RESTAURANT", Vector2(30, 77), 15, Color("c6ded3"))
    _box(Rect2(28, 94, 225, 49), Color("2e5850"))
    _text("$ %d" % model.money, Vector2(44, 129), 31, Color("fff1bb"))
    _text("%d served" % model.sold, Vector2(278, 125), 24, Color.WHITE)
    _box(Rect2(420, 8, 116, 82), Color("2e5850"))
    _text("Help", Vector2(451, 56), 23, Color.WHITE)
    _button("help", Rect2(420, 8, 116, 82))
    _box(Rect2(550, 24, 68, 54), Color("2e5850"))
    _text("OFF" if muted else "SFX", Vector2(563, 58), 20, Color.WHITE)
    _button("sound", Rect2(550, 24, 68, 54))
    _box(PauseMenu.HEADER_PAUSE, Color("2e5850"))
    _text("Pause", Vector2(635, 57), 20, Color.WHITE)
    _button("pause", PauseMenu.HEADER_PAUSE)
    _text("TRAY %d/%d" % [model.carried, model.capacity()], Vector2(470, 125), 22, Color("ffcf68"))
    if model.upgrades.fries > 0:
        _text("Counter: %d burgers, %d fries" % [model.counter_stock, model.counter_fries], Vector2(278, 151), 16, Color("dce7d1"))
        _text("+ %d fries" % model.fries_carried, Vector2(559, 151), 17, Color("ffcf68"))
    if challenge == null:
        _text("%d left hungry" % model.lost, Vector2(278, 101), 16, Color("ffcf68"))
    if guide_visible and challenge == null:
        _box(Rect2(20, 171, 680, 100), Color("fff7df"))
        _text("NEXT UP", Vector2(38, 192), 15, Color("a45b36"))
        var lines := _guide_lines(model.tutorial())
        for i in range(mini(2, lines.size())):
            _text(lines[i], Vector2(38, 218 + i * 26), 21)
        _box(Rect2(618, 175, 82, 82), Color("e7dfc4"))
        _text("X", Vector2(651, 224), 27)
        _button("guide_close", Rect2(618, 175, 82, 82))
    ChallengeHUD.draw_strip(self)
    RushHUD.draw(self)
    _box(Rect2(0, 966, 720, 314), Color("fff7e6"), 0)
    var tabs := [{"id":"upgrades", "title":"Upgrades"}, {"id":"staff", "title":"Hire staff"}, {"id":"expand", "title":"Expand"}]
    for i in range(tabs.size()):
        var tab: Dictionary = tabs[i]
        var rect := Rect2(18 + i * 234, 978, 218, 82)
        var active: bool = menu == tab.id
        _box(rect, Color("193e3c") if active else Color("d9e5d3"))
        _text(tab.title, rect.position + Vector2(24, 50), 27, Color("ffcf68") if active else Color("263b3b"))
        _button(tab.id, rect)
    if menu == "staff":
        RushHUD.draw_staff(self)
    elif menu == "expand":
        _card("table", Rect2(18, 1072, 218, 168), ["More seats", "and bigger tips."])
        _card("fries", Rect2(252, 1072, 218, 168), ["Cook & deliver", "sides for combos."])
        _card("drive", Rect2(486, 1072, 218, 168), ["Open another", "service window."])
    else:
        for i in range(UPGRADE_IDS.size()):
            _card(UPGRADE_IDS[i], Rect2(18 + (i % 3) * 234, 1072 + (i / 3) * 88, 218, 82))
    _text("Rush rank %d · %s" % [model.rush.rank, save_status], Vector2(23, 1265), 17, Color("607467"))
    if notice_remaining > 0.0:
        _box(Rect2(28, 888, 664, 78), Color("193e3c"))
        _fit_text(notice_text, Vector2(43, 935), 558, 21, Color("fff1bb"))
        _box(Rect2(620, 888, 72, 78), Color("2e5850"))
        _text("X", Vector2(645, 937), 26, Color.WHITE)
        _button("notice_close", Rect2(618, 884, 82, 82))
    elif challenge == null:
        _fit_text("Calm demand %d/min · Queue %d/%d · Watch the patience bars" % [roundi(model.calm_arrivals_per_minute()), model.queue.size(), model.queue_capacity()], Vector2(30, 956), 660, 18, Color("3c5c50"))
    elif guide_visible:
        _text("Tap to walk • drag to steer • WASD / arrows", Vector2(115, 956), 20, Color("547064"))
    if pointer >= 0 and dragging:
        draw_circle(anchor, 65, Color(0.12, 0.3, 0.25, 0.2))
        draw_arc(anchor, 65, 0, TAU, 48, Color("ffffff"), 3, true)
        draw_circle(anchor + (pointer_pos - anchor).limit_length(65), 25, Color(1, 1, 1, 0.7))
    for popup in popups:
        _text(popup.text, popup.pos + Vector2(0, -popup.age * 55), 32, Color("337553"))
    PauseMenu.draw(self)
    ChallengeHUD.draw_modal(self)


func _stop_input() -> void:
    _release()
    keyboard_moving = false
    wait_for_keyboard_release = true
    model.set_target(model.player)

func _open_challenges() -> void:
    if challenge != null:
        challenge_panel = "abandon"
    else:
        challenge_panel = "choose"
    paused = true
    _stop_input()

func _close_challenges() -> void:
    challenge_panel = ""
    paused = true
    _stop_input()

func _start_challenge(mode: String) -> void:
    _record_finished_challenge()
    if challenge_recorded and not challenge_record_saved:
        challenge_record_saved = ChallengeStore.record_result(challenge_records, challenge.result())
    if challenge == null and not SaveStore.save(career_model):
        _show_notice("Could not save career. Challenge not started; try again.")
        save_status = "Career save failed · challenge not started"
        challenge_panel = ""
        return
    challenge = ScoreChallenge.new(mode)
    model = challenge.model
    _swap_model()
    challenge_recorded = false
    challenge_record_saved = true
    challenge_panel = ""
    paused = false
    save_status = "Practice run · career protected"

func _return_to_career() -> void:
    _record_finished_challenge()
    if challenge_recorded and not challenge_record_saved:
        challenge_record_saved = ChallengeStore.record_result(challenge_records, challenge.result())
    challenge = null
    challenge_recorded = false
    model = career_model
    _swap_model()
    challenge_panel = ""
    paused = true
    save_status = "Career restored · records saved separately" if challenge_record_saved else "Career restored · challenge record save failed"

func _swap_model() -> void:
    _bind_presentation_model()
    last_sale = model.sale_serial
    popups.clear()
    autosave = 0.0
    selected_staff = {"cook":0,"cashier":0}
    menu = "upgrades"
    _stop_input()
    _show_notice(model.notice)
    queue_redraw()

func _challenge_telemetry() -> Dictionary:
    var run: Dictionary = {"active":challenge != null, "panel":challenge_panel, "records":challenge_records, "record_saved":challenge_record_saved}
    if challenge != null:
        run.merge({"mode":challenge.mode,"score":challenge.score,"elapsed":challenge.elapsed,"remaining":challenge.remaining(),"multiplier":challenge.multiplier(),"streak":challenge.streak,"lost":challenge.lost,"finished":challenge.finished,"result":challenge.result() if challenge.finished else {}})
    return {"challenge":run,"career":{"money":career_model.money,"sold":career_model.sold,"elapsed":career_model.elapsed,"upgrades":career_model.upgrades.duplicate(true)}}

func _record_finished_challenge() -> void:
    if challenge != null and challenge.finished and not challenge_recorded:
        challenge_record_saved = ChallengeStore.record_result(challenge_records, challenge.result())
        challenge_recorded = true
        _stop_input()

# Effects are presentation only: the model removes abandoned orders immediately.
# Rebinding also clears ghosts when starting/restarting a challenge or resetting.
func _bind_presentation_model() -> void:
    if presentation_model != null and presentation_model.customer_abandoned.is_connected(_present_departure):
        presentation_model.customer_abandoned.disconnect(_present_departure)
    presentation_model = model
    presentation_model.customer_abandoned.connect(_present_departure)
    art.model = model
    art.departures.clear()

func _present_departure(customer: Dictionary) -> void:
    if model.challenge_patience:
        return
    art.present_departure(customer)
    _show_notice("A customer left hungry" if not customer.rush_order else "A rush customer left hungry")
