# Burger Boss gameplay review

Date: 2026-10-23
Scope: the gameplay loop as implemented on `main` at `c0ed7e8`. This is a design review with implementation notes, not a bug report. The build, tests and persistence are in good shape; this document is about why the game goes flat after the first couple of minutes and what to do about it.

Each idea below has a **Concept** section (what the player experiences and why it matters) and a **Technical** section (where it lives in the code, the shape of the change, and what tests it touches). Ideas are ordered by impact. Numbers quoted are derived from constants in `scripts/restaurant.gd` and from the figures recorded in `docs/HANDOFF.md`; they are close, not exact.

## Summary of findings

| Finding | Evidence |
| --- | --- |
| Calm play has no stakes | Patience only ticks inside `_tick_rush`. No wages, spoilage, lost customers or offline income. |
| Arrivals cap income, not the kitchen | `arrival_gap` is 3.1 s minus 0.22 s per table, floor 1.8 s. That is 19 to 27 customers/min. One register plus one cashier already serves about 41/min. |
| Several upgrades have no visible effect | Registers 2 and 3 and cashier 2 do nothing outside a rush. Speed, Recipe and Tray are flat stat bumps with no on-screen change. |
| Some upgrades make the game harder | `RushDirector.start` sets `goal = 6 + 2*grill + 2*cook + 2*register + rank`. Buying a register raises the rush target without raising calm income. |
| Money loses purpose quickly | Every upgrade maxed costs about $3,840. At the handoff's recorded rate (105 sales in ten minutes plus rush rewards) that is roughly 25 to 30 minutes of play. |
| Rush rank stops mattering at six | `mini(rank, 6)` in the goal formula. After that each rush is identical and the reward is cash the player no longer needs. |
| Boss boost removes the only manual rhythm | `boss_action` creates `4 + grill` burgers from nothing on an eight second cooldown. |
| Automation arrives before the player learns the loop | Cook ($90) and cashier ($120) are affordable after roughly 20 sales, under two minutes. After that the player only buys things. |

The common thread: once a cook and a cashier are hired there is no reason to be present and no reason to be away. An idle game needs one of those two to be true. The lunch rush was added to give a reason to be present, and it works as a minigame, but the calm loop underneath it still has nothing in it.

## Economy reference

Useful numbers for anyone retuning balance.

| Item | Base cost | Purchases to max | Total | Formula |
| --- | --- | --- | --- | --- |
| Grill | $45 | 3 | $242 | `base * 1.65^purchased` |
| Register | $60 | 2 | $159 | |
| Cook | $90 | 3 | $483 | |
| Cashier | $120 | 2 | $318 | |
| Table | $55 | 4 | $543 | |
| Fries | $180 | 1 | $180 | unlocks at 12 sales |
| Drive-through | $320 | 1 | $320 | unlocks at 25 sales |
| Speed | $35 | 5 | $604 | |
| Recipe (value) | $40 | 5 | $691 | +$4 per burger each |
| Tray (capacity) | $30 | 4 | $297 | +2 carry each |
| **All** | | | **$3,837** | |

Income per sale: `burger_value()` is 12 + 4 per Recipe level, plus $10 for a combo, $6 for drive-through, $2 when any table exists.

Throughput, per minute:

| Rate | Value | Where |
| --- | --- | --- |
| Calm arrivals, no tables | 19.4 | `arrival_gap` in `_tick` |
| Calm arrivals, four tables | 27.0 | |
| Serve, 1 register + 1 cashier | 41.5 | `serve_progress` in `_tick` |
| Cook, 1 grill + 1 cook (while in `cooking` state) | 23.2 | `cook_rate` in `_tick` |

Cooks spend roughly a third of their time walking (grill to counter is 370 px at 170 px/s), so effective cook output per cook is closer to 15/min on one grill. That makes the second cook or second grill the last purchase that visibly changes calm play.

---

## 1. Give calm play stakes: always-on patience

### Concept

Customers currently wait forever outside a rush. Make patience tick at all times, generously, so that a neglected queue starts to lose people. A customer who runs out walks off without paying, shows a sad emote and the player sees the lost sale. The queue becomes the pressure gauge the player keeps one eye on, which is the core feeling this genre runs on.

Keep it kind. Calm patience should be long enough that a reasonably staffed restaurant almost never loses anyone, so the first few minutes stay friendly. The point is that neglect has a visible cost, not that the game becomes stressful.

### Technical

- `scripts/restaurant.gd`, `_spawn_customer`: `patience` and `max_patience` are already set on every customer (30 s). Give calm customers a longer value, for example 45 s plus 5 s per table, and keep the rush value at 30 s.
- `scripts/restaurant.gd`, `_tick`: the patience countdown lives in `_tick_rush` and only runs while `rush.active`. Move the countdown into `_tick` so it runs always. Keep the `rush.lost` increment conditional on `rush_order`. Add a `lost` counter on the restaurant for the calm case and a short notice such as "A customer left hungry".
- Only count down once the customer has reached their queue spot (`position.distance_to(target) < 18`, the same check `_front` uses), otherwise arrivals at the back of a long queue are penalised for walking.
- `scripts/restaurant_art.gd`: draw the existing patience value as a small bar or a face that changes at 50% and 20%. The HUD telemetry already exports `patience` and `max_patience` per customer, so nothing new is needed for the browser tests to assert on it.
- `snapshot` / `restore`: persist the new `lost` counter as an optional field with a default of 0 so version 2 saves still load. Follow the pattern used for `combo_served`.
- Tests: `tests/test_restaurant.gd` `test_ten_minutes` asserts at least one sale per minute, which still holds. Add a test that an unstaffed, unattended queue loses a customer after the calm patience window and that money does not change.

---

## 2. Scale demand with progression

### Concept

Arrival rate should grow as the restaurant grows. The simplest driver is a reputation value that rises with sales. A bigger crowd then makes the second cashier, extra registers and extra grills matter in calm play, and it removes the trap where buying a register only makes the rush harder. Demand growing with reputation is also the single pacing dial for the whole game: tune one curve and everything downstream follows.

Pair this with idea 1. More customers only matters if slow service costs something.

### Technical

- `scripts/restaurant.gd`, `_tick`: replace the fixed `arrival_gap` with a function of demand. One option:

  ```
  var demand := 1.0 + minf(2.0, float(sold) / 150.0) + float(upgrades.table) * 0.15
  var arrival_gap := maxf(1.0, 3.4 / demand)
  ```

  That gives about 18/min at the start, 30/min at 150 sales and about 48/min at 300 sales with four tables. Tune against the serve rate so the player always feels slightly behind until they buy the next thing.
- Queue cap: `queue.size() < 8 + upgrades.table` will clip demand early. Raise it alongside demand or draw overflow customers waiting outside the door so the player sees the crowd they are missing.
- `scripts/rush_director.gd`, `start`: remove `register` from the goal formula, or replace the whole formula with one based on calm throughput so that the rush target tracks what the kitchen can actually do. A reasonable shape is `goal = ceil(calm_arrivals_per_minute * 0.8) + rank`.
- `_tick` rush `arrival_gap` already derives from `rush.goal`, so it adjusts automatically.
- Tests: the balance table in `docs/HANDOFF.md` and the `test_ten_minutes` fixtures will need retuning. Add a test that `arrival_gap` strictly decreases as `sold` grows, and one that confirms a fully staffed restaurant at 300 sales keeps the queue below the cap.

---

## 3. Capped offline earnings

### Concept

On return, pay the player a fraction of what their kitchen would have earned while they were away, capped at a few hours, and show it on a "Welcome back, Boss" card with a single tap to collect. This is the strongest retention hook in the genre and it is what makes an idle game idle. It also gives the staff upgrades a second purpose: a better kitchen earns more while you are gone.

This stays within the project rules. It needs no backend and no account; it is a timestamp in the save file compared with the device clock.

### Technical

- `scripts/save_store.gd`, `save`: write `Time.get_unix_time_from_system()` into the snapshot as `saved_at`.
- `scripts/restaurant.gd`: add `calm_income_per_second()` that mirrors the real constraint, which is `min(arrival rate, serve rate, cook rate) * average sale value`. Derive it from the same constants `_tick` uses so it cannot drift from live play.
- `scripts/restaurant.gd`, `restore`: read `saved_at`, compute `away = clamp(now - saved_at, 0, 4 * 3600)`, and store `pending_offline = int(away * calm_income_per_second() * 0.5)`. Do not add it to `money` yet.
- `scripts/game.gd`: on `_ready`, if `pending_offline > 0`, draw a modal card in the style of the reset confirmation (`scripts/pause_menu.gd` shows the pattern) with the amount and a Collect button. Collecting adds to `money`, clears `pending_offline` and saves.
- Guard against clock changes: ignore negative or absurd deltas, and never pay for time before the first save.
- Only pay offline income once a cashier exists. Before that, the player's absence genuinely means no service, which also makes the first hire feel meaningful.
- Tests: add a test that restores a snapshot with `saved_at` two hours old and checks `pending_offline` equals the expected value, that a future timestamp pays nothing, and that the cap holds at four hours.

---

## 4. Grow the menu, not just the stats

### Concept

The only visible unlocks are fries and the drive-through. Add two or three more items, each with its own station, carry type and customer icon: drinks (fast, cheap, no cooking), milkshakes (slow, high value) and perhaps dessert. Customers show their order as icons above their head rather than a hidden `combo` flag, so the player reads the queue and reacts. Each new station visibly changes the floor, which is what progression should feel like.

This is content work, but it also fixes the problem that Recipe, Speed and Tray upgrades have no on-screen effect: a bigger menu makes carry capacity and walking speed obviously useful.

### Technical

The current code hard-codes burgers and fries as separate variables (`grill_stock`, `fries_stock`, `carried`, `fries_carried`, `counter_stock`, `counter_fries`). Adding a third item by copying that pattern would be painful. Refactor to a data-driven item table first.

- `scripts/restaurant.gd`: introduce a `MENU` constant, one entry per item:

  ```
  const MENU := {
    "burger": {"station": Vector2(170, 430), "cook_time": 2.2, "value": 12, "unlock": 0, "max_stock": 6},
    "fries":  {"station": Vector2(170, 660), "cook_time": 1.2, "value": 10, "unlock": 12, "max_stock": 18},
    "drink":  {"station": Vector2(170, 540), "cook_time": 0.6, "value": 5,  "unlock": 40, "max_stock": 24},
  }
  ```

  and replace the per-item variables with dictionaries keyed by item id: `station_stock`, `player_carry`, `counter`. The player's tray becomes a dictionary too, with `capacity()` as the total across items.
- Customers get an `order: Array[String]` instead of `combo: bool`. `_can_serve` checks every item in the order is on the counter; `_sell` consumes each one and sums the values.
- Staff assignment: `allowed_assignments` for cooks becomes `["balanced"] + unlocked item ids`. `_route_cook` already has a "what is short at the counter" heuristic for fries; generalise it to pick the item with the largest shortfall.
- `scripts/restaurant_art.gd`: one `draw_item(id, at, factor)` that switches on item id, used for stations, trays and order bubbles.
- `snapshot` / `restore`: this is a schema change. Bump to version 3 and write a migration that maps version 2 fields into the dictionaries. The existing validation style (bounded integers, totals checked against capacity) carries over.
- Tests: the existing conservation tests (no ghost food, exact combo consumption, midtrip carry on reload) are the ones that matter. Port them to the dictionary form before adding a third item, then add one case per new item.

---

## 5. Make rush rank mean something

### Concept

Rank currently adds one to the goal up to six and then nothing. Give each rank a reason to exist. Options, from cheapest to most involved:

- A small permanent tip multiplier per rank, shown on the HUD.
- A modifier per rank that changes how the rush plays: a food critic VIP who must be served within 10 s, a delivery-only wave that uses the drive-through, a fries-only rush, a "double value, half patience" rush.
- A cosmetic per rank (sign, floor colour, uniform) so the restaurant visibly reflects the player's record.

Also consider making a rush a decision rather than a free button: a short cooldown after a rush, or a small promotion cost. Free retries are good; free spam is not.

### Technical

- `scripts/rush_director.gd`: add a `modifier` string chosen in `start` from a small list, cycling by rank or by `wins`. Expose it in `telemetry`. Each modifier is a few lines in `restaurant.gd` where the rush already branches on `rush.active`: patience, combo probability, drive-through share, special requirements.
- Tip multiplier: `_sell` already computes `last_earned`; multiply by `1.0 + 0.02 * rush.rank` and show the current multiplier next to "Rush rank" in `scripts/game.gd` `_draw`.
- Rush cooldown: a `rush_cooldown` float on the restaurant that `rush_lock_reason` checks, decremented in `_tick`, persisted like `boss_cooldown`.
- Cosmetics: a `rank` driven colour or sign change in `scripts/restaurant_art.gd` is the cheapest visible reward and needs no new state.
- Tests: `tools/rush_journey.mjs` drives a full rush through the browser. Each modifier should get one deterministic case in `tests/test_restaurant.gd` using the same fixture approach as the balance table.

---

## 6. A long-term goal: reputation stars and prestige

### Concept

Everything is maxed in roughly half an hour and the game has no finish line. Two layers fix that.

First, a visible reputation rating (one to five stars) driven by sales and lost customers. Each star unlocks something (a menu item, a station, a rush modifier) and reaching five stars triggers a celebration screen. That alone gives the first session a destination.

Second, a prestige loop. Selling the restaurant resets money and upgrades, keeps a permanent income multiplier and opens the next location with a different floor layout, a different menu emphasis and higher base demand. This is the standard answer to "everything is maxed" in idle games and it reuses every system already built.

### Technical

- Reputation: `scripts/restaurant.gd` adds `reputation()` derived from `sold` and `lost` (from idea 1), for example stars at 25, 75, 150, 300 and 500 net sales. Use it as the `unlock` key in the `MENU` table from idea 4 and as the demand driver in idea 2 so there is one progression variable.
- Prestige: add `location: int` and `prestige_multiplier: float` to the snapshot. `prestige()` writes a fresh restaurant with those two values preserved. Station positions are already constants (`GRILL`, `COUNTER`, `FRIES`, `DRIVE`); turn them into a per-location layout table so the second location can look different without touching movement code. `scripts/game.gd` tap-to-station rectangles in `_press` need to come from the same table.
- Persistence: both are additive fields with defaults, so version 2 saves still load. The reset flow in `SaveStore.reset_progress` is the template for a safe prestige write (write fresh state first, then swap).
- Tests: prestige must conserve nothing except the two kept fields; assert that explicitly. Add a save round trip for location two.

---

## 7. Turn boss boost into a skill moment

### Concept

The boost currently creates free food on a cooldown, which removes the only manual rhythm in the game. Replace it with a short timing interaction at the grill: a sizzle bar sweeps and a tap in the hot zone doubles the batch, a miss burns it. At the counter, keep the "serve now" behaviour but make it a brief tap-the-orders sequence. The boost becomes something the player is good at rather than a button to press when it lights up.

If a skill check feels like too much for the audience, the cheaper fix is to make the boost cost something (a few dollars of ingredients) so it is a trade rather than a gift.

### Technical

- `scripts/restaurant.gd`, `boss_action`: split into `boss_prep_start()` which begins a one-second window and `boss_prep_resolve(hit: bool)` which grants the batch, doubled on a hit and zero on a miss. The restaurant stays deterministic; the timing judgement happens in `scripts/game.gd` using the existing `clock`.
- `scripts/rush_hud.gd`, `draw`: the Boss boost card becomes the sizzle bar while a window is open. `handle` maps a second tap to `boss_prep_resolve`.
- Keep the ingredient cost option trivial: subtract `2 * batch` from `money` in `boss_action` and refuse when short.
- Tests: the existing "ineffective boost preserves cooldown" test still applies. Add hit and miss cases and assert the batch is never created without a resolve.

---

## 8. Smaller UI wins

These are independent of each other and of the ideas above.

### Tap a worker to assign them

**Concept.** The Next-and-cycle buttons in Hire staff are abstract. Tapping a worker on the floor should open a small job picker above them.

**Technical.** `scripts/game.gd` `_press` already tests island rectangles before treating a tap as movement. Add a hit test against `model.staff` positions (a 60 px radius is enough at this art scale) ahead of the floor check, store `selected_worker`, and draw a three-button row from `allowed_assignments(index)` using `RushHUD.JOB_NAMES`. Reuse `assign_staff`.

### Show what an upgrade does

**Concept.** Cards show a price and nothing else. "Recipe $40" tells the player nothing. Show the effect: "+$4 per burger", "+2 tray", "+0.3 burgers/s".

**Technical.** `scripts/game.gd` `_card` takes a `description` array. Add a `describe(id)` helper on the restaurant that returns the delta for the next level, derived from the same formulas `_tick` uses, and pass it in. The Expand tab already does this for its three cards.

### Next unlock progress

**Concept.** Fries unlock at 12 sales and the drive-through at 25, but the only hint is the lock text on the card. A thin bar under the "served" counter reading "Fries in 7 sales" keeps the player oriented.

**Technical.** `lock_reason` already knows the thresholds. Add `next_unlock()` returning `{id, remaining}` and draw it in `_draw` beside `sold`. Idea 6 generalises this into star progress.

### Customer order bubbles

**Concept.** Show the order as icons above each customer. This is the single most legible thing a restaurant game can draw and it makes combos and specials obvious without text.

**Technical.** `scripts/restaurant_art.gd` has `burger` and `fries` draw helpers. Draw them at 0.5 scale above `customer.position` based on `combo` and `special`, with a gold outline for specials. If idea 4 lands, iterate `customer.order` instead.

---

## Suggested order of work

1. Ideas 1 and 2 together. Smallest change, largest effect, no new content, and they make the existing upgrade tree honest.
2. Idea 3, offline earnings. One timestamp and one modal.
3. Idea 8 UI wins, in any order, as filler between larger pieces.
4. Idea 4, the menu refactor. Do the dictionary refactor on its own first with no new items, then add items.
5. Ideas 5 and 6, rush meaning and prestige, once there is content for them to gate.
6. Idea 7 last; it is a feel change and easier to judge once the loop around it is right.

## Test and balance impact

- `tests/test_restaurant.gd` `test_ten_minutes` and the balance fixtures in `docs/HANDOFF.md` assume the current fixed arrival rate. Ideas 1 and 2 change the economy's shape, so expect to retune the thresholds in that test and re-record the balance table.
- `tools/browser_smoke.mjs` and `tools/rush_journey.mjs` read state through the `?smoke=1` telemetry bridge in `scripts/game.gd` `_process`. Any new state (lost customers, reputation, pending offline income, rush modifier) should be added to that dictionary so browser tests can assert on it without touching simulation state.
- Keep the simulation in `restaurant.gd` free of scene and time APIs, as it is now. Offline earnings should read the clock in `save_store.gd` or `game.gd` and pass a number in, so the deterministic tests can supply their own timestamps.
