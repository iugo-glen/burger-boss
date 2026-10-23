extends RefCounted
## Optional demand challenge; no payroll, debt, or punishment to the idle loop.
var active := false
var duration := 60.0
var time_left := 0.0
var goal := 0
var served := 0
var combos := 0
var combo_goal := 0
var specials := 0
var special_goal := 0
var lost := 0
var rank := 0
var wins := 0
var best := 0
var result := "Ready"
var reward := 0

func start(upgrades: Dictionary) -> void:
    # Demand follows real kitchen capacity rather than bank balance or play time.
    goal = 6 + int(upgrades.grill) * 2 + int(upgrades.cook) * 2 + int(upgrades.register) * 2 + mini(rank, 6)
    combo_goal = maxi(3, int(ceil(float(goal) * 0.4)))
    special_goal = maxi(2, int(ceil(float(goal) / 4.0)))
    specials = 0
    served = 0
    combos = 0
    lost = 0
    reward = 0
    time_left = duration
    result = "In progress"
    active = true

func record_sale(combo: bool, special: bool = false) -> void:
    if not active:
        return
    served += 1
    if combo:
        combos += 1
    if special:
        specials += 1

func achieved() -> bool:
    return served >= goal and combos >= combo_goal and specials >= special_goal

func finish(value: int) -> void:
    active = false
    best = maxi(best, served)
    if achieved():
        wins += 1
        rank = mini(999, rank + 1)
        reward = 60 + goal * value / 2 + rank * 20
        result = "Success"
    else:
        reward = 0
        result = "Try again"
