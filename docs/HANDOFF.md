# Burger Boss implementation handoff

Scope: [issue #1](https://github.com/iugo-glen/burger-boss/issues/1), all five milestones. The implementation uses original GDScript, procedural vector art and synthesised audio, with no third-party game assets or runtime services.

## Career patience and demand update

This change implements gameplay-review ideas 1 and 2 for career only. Calm customers receive 45 seconds plus 5 seconds per table, while rush orders retain 30 seconds. Their countdown runs once per simulation tick, only within 18 pixels of their current queue position, before service. Departures consume no food and pay no money. Departure animation is presentation state kept outside the deterministic simulation. The optional version-2 `lost` save field records calm departures; older saves default to zero and invalid values fail without changing live progress. Patience bars and departure feedback expose the pressure on service.

Calm career demand is `18 + 0.08 * min(sold, 300) + 1.5 * tables` arrivals per minute. This gives 18 at a fresh restaurant, 30 at 150 sales without tables, and 48 at 300 sales with four tables. Queue capacity grows from 8 to a maximum of 14 inside the existing floor. Register purchases no longer raise career rush targets. Score Attack and Fastest to max retain their original arrival rates, queue capacity, patience and register-dependent rush targets.

Godot 4.4.1 deterministic tests pass with 1,766 restaurant checks and 55 challenge checks. New checks cover settled-only expiry, countdown frequency, walking and queue reflow, expiry before ready service, no payment or food consumption on departure, calm and rush loss accounting, restored calm patience after a rush, persistence defaults and invalid-save transactionality, demand growth and cap, visible queue bounds, register-independent career rush targets, natural progression and mature staffing. Existing assertions remain, with progression-dependent fixtures retuned against their starting sales. Build, export and browser evidence for this update is recorded in its pull request.

The natural ten-minute fixture earns its cook and cashier through manual sales, then buys a table, grill, recipe and drive-through from income. It made **147 additional sales**, retained **at least 9 sales in every minute**, and ended with $2,096 and no deadlock. This compares with the previous 154 additional sales and the same minimum of nine per minute.

Controlled mature fixtures start at 300 sales with all upgrades and run for ten minutes, with the boss away from service and no added stock during the run. Empty starts have no station, counter or player food. Stocked starts have 18 burgers at the grill, 18 fries, and 30 of each item at the counter. Deliberate assignments use two grill cooks, one fries cook and one cashier per lane. Auto uses the default Balanced assignments. These fixtures measure capacity, rather than earned progression or human play.

| Mature calm staffing | Sales, empty / stocked | Lowest minute, empty / stocked | Peak queue, empty / stocked | Calm losses, empty / stocked |
| --- | --- | --- | --- | --- |
| Auto | 349 / 349 | 31 / 30 | 14 / 14 | 0 / 0 |
| Deliberate ingredient and lane split | 462 / 462 | 45 / 45 | 8 / 5 | 0 / 0 |

Auto averages 34.9 sales per minute and remains congested at the queue cap, so the nominal demand rate is not a promise of served sales. Assigned staffing averages 46.2 sales per minute and meets the target of at least 45 sales in every minute with a queue below 14. The interval is sampled in 0.1-second simulation steps, which makes a nominal 1.25-second arrival interval produce arrivals every 1.3 seconds; the existing timer reset behaviour is retained and the observed throughput reflects that live simulation behaviour.

The full career rush comparison uses matching empty and stocked snapshots, with the boss either away or moving between stations, delivering real ingredients and using boosts no more often than every ten seconds. Stocked rush fixtures also fill both player trays. Every active variant fulfils its order, combo and Boss-special goals, wins and earns rank; every idle variant fails.

| Restaurant | Target | Idle orders, empty / stocked | Active orders, empty / stocked | Active boosts, empty / stocked |
| --- | --- | --- | --- | --- |
| First rush team | 10 | 3 / 8 | 11 / 11 | 4 / 3 |
| Middle upgrades | 14 | 12 / 12 | 15 / 15 | 3 / 3 |
| Fully upgraded | 20 | 13 / 13 | 20 / 20 | 4 / 3 |
| Fully upgraded, rank six | 26 | 13 / 13 | 27 / 29 | 4 / 4 |

Challenge regression fixtures retain the exact previous results: manual Score Attack **34,172** points from 86 sales and eight departures, managed Score Attack **38,189** points from 94 sales and eight departures, and Fastest to max **428 active seconds** from 147 sales. These are deterministic simulations, not human records. The older validation counts, balance tables and career patience descriptions below are historical evidence for earlier releases.

## Score challenges

The new Challenges menu is available from Pause. Five-minute Score Attack uses a fresh restaurant, service points, a speed bonus and a streak multiplier. Fastest to max starts from the same baseline and stops when all finite upgrade categories reach their caps. Neither mode replaces career progress. The scene retains the career model, prevents challenge autosaves from reaching the career save, and returns to that model when the attempt is exited. Completed personal records use separate storage. Unfinished attempts are abandoned on reload.

Scoring is (100 + up to 50 remaining-patience bonus) times the current service multiplier. Consecutive sales 1–5 use ×1, 6–10 use ×2 and 11 onward use ×3. A customer leaving resets the streak. Ordinary challenge customers have 30 seconds of patience. Career patience now follows the career update above. Medals require 8,000 / 20,000 / 35,000 points. Pausing/backgrounding stops active simulation time. The five-minute boundary is clipped exactly, and completed restaurants reject further gameplay actions.

Godot 4.4.1 import, runtime and HTML5 export pass. The existing 1,407 assertions pass, and 50 new challenge assertions cover individual/multi-sale scoring, patience expiry, exact timing, frozen results, complete finite speedrun caps, record validation, best-score/time ordering, failed writes/renames and normal earned progression. One-second decision simulations scored 34,172 (manual, Silver) and 38,189 (managed, Gold); unattended play scored zero. A speedrun bought every upgrade through 147 real simulated sales in 428 active seconds with no injected money or stock. These are deterministic balance simulations, not human-play records.

Browser journeys exercise challenge selection, real earned points, pause, cancellation, explicit abandonment, career preservation and reload. Mobile Chromium additionally plays a full five-minute score attempt, verifies the result and personal record, and replays. Final browser/CI evidence is recorded in the scoring pull request. Physical iPhone/iPad testing remains a device check; no account configuration changes are required for the existing GitHub Pages pipeline.

## Starting over

The pause menu now exposes **Resume** and **Start over**. A separate confirmation explains that starting over erases this device's money, staff, upgrades, food and rush rank. Cancel and Escape retain progress. The dialog pauses the simulation and blocks underlying controls. Confirming writes a fresh save before replacing the active restaurant; if storage fails, the current restaurant and saved progress are retained. Saves use a temporary file followed by a checked rename rather than deleting or truncating the primary save first.

Successful restart clears the old session state, returns to the initial restaurant and restores the tutorial. It does not clear browser site data or change progress on other devices. GitHub Pages deployment remains automatic after a successful main build. Physical iPhone/iPad Safari acceptance remains a device check.

Godot 4.4.1 headless import, runtime, **1,407 assertions with zero failures**, and Compatibility HTML5 export passed. The 22 new persistence checks use isolated test paths and exercise a rich save, failed temporary-file creation, failed rename, old-save preservation, complete reset and reload. Browser regressions cover real Cancel/Escape/confirmation controls, blocked background input, held keys, reset reload and later autosave; the full mobile journey also exercises resetting an active rush with earned rank and staff. Current browser/CI results are recorded in the reset pull request and retained artifacts.

## Lunch-rush gameplay update

The earlier restaurant became passive once staff and upgrades were purchased. This update adds a repeatable, optional 60-second promotion that brings extra customers and has three visible targets: orders, burger-and-fries combos and gold Boss-special handoffs. A special consumes real ingredients and requires the boss near that order's counter or drive-through station. Successful promotions award money and rank; targets grow with kitchen capacity and the first six ranks. Waiting customers are included when a promotion starts so a full normal queue cannot waste the timer.

The boss can prepare, carry and deliver either ingredient, use an eight-second contextual boost, and give each cook or cashier a separate assignment. In Hire staff, **Next** selects a worker and the adjacent job button cycles that worker's task. Balanced cooks maintain both food supplies; dedicated jobs allow burger/fries and counter/drive-through splits. Food stocks, carried fries, active jobs, combo tickets and rush patience are visible.

Failure only loses the optional bonus. Retry is free, and remaining rush orders become ordinary burger orders so calm service can recover. Existing version-2 saves migrate without resetting money, upgrades or carried food. Saves now preserve ingredients, worker jobs and mastery. Reloading an unfinished promotion explicitly cancels it without a penalty; it does not run down a hidden timer.

This is one focused scenario. It does not implement a chain of restaurant locations, a campaign system or unlimited upgrades. A prepared team can make a rush easier, and the owner can choose to stay in calm service. There are no wages, compulsory maintenance tasks or reputation penalties.

### Gameplay-update validation (historical)

Godot **4.4.1** headless import, scene runtime, **1,385 assertions with zero failures**, and Compatibility HTML5 release export passed. The assertion count includes per-second invariants rather than 1,385 independent scenarios. The ten-minute simulation made **154 additional sales**, with at least **9 sales in each minute** and no service deadlock.

The balance test compares identical snapshots with the boss away from service versus actual movement, ingredient deliveries and boosts at least ten seconds apart. Empty and fully stocked variants are both tested. Higher-tier fixtures deliberately set upgrades for controlled balance measurement; they are not evidence that progression was earned through browser play.

| Restaurant | Target | Idle orders, empty / stocked | Active orders, empty / stocked |
| --- | --- | --- | --- |
| First rush team | 12 | 3 / 8 | 12 / 12 |
| Middle upgrades | 18 | 12 / 12 | 19 / 19 |
| Fully upgraded | 26 | 11 / 11 | 27 / 29 |
| Fully upgraded, rank six | 32 | 10 / 10 | 32 / 32 |

Every active variant met its combo and Boss-special targets and won using three to five boosts. Every unattended variant failed. Being present with a prepared, well-assigned team is a valid strategy; the game does not require continuous movement for its own sake.

Regression checks cover exact combo ingredient consumption, no ghost payments, ineffective boosts preserving cooldown, job-driven navigation and deliveries, full ingredient-counter recovery, conservation and reload of rescue cargo, invalid save transactionality, old maxed version-2 saves, promoted full queues, patience, failed-rush recovery and interrupted-rush cancellation. Independent review reproduced and verified the cargo fixes and found no unresolved critical source defect.

## Baseline diagnosis

The upstream Actions run [39893216248](https://github.com/iugo-glen/burger-boss/actions/runs/39893216248) imported and exported the prototype with Godot 4.4.1 successfully. Deployment failed in `actions/configure-pages` with `Get Pages site failed ... Not Found`. The workflow previously ran only on main, did not test pull requests, and relied on Godot exit codes without checking diagnostic output.

Local runtime setup must put Godot's XDG data/config/cache directories in writable locations. The environment's default Godot is 4.6.3; acceptance validation uses the downloaded 4.4.1 binary and matching web templates.

## Account and device intervention

- Pages is now configured with GitHub Actions as its source, and [the hosted game is live](https://iugo-glen.github.io/burger-boss/). Successful `main` builds now publish automatically; pull requests only validate. No secrets were changed by this implementation.
- A real iPhone/iPad running current Safari must be tested by a person with that device. Desktop browser automation and mobile viewport emulation do not prove real iOS compatibility.

## Milestones implemented

| Milestone | Working implementation |
| --- | --- |
| M1: reliable loop | WASD/arrows, tap movement and drag joystick; timed grilling, finite tray, visible burger carrying, counter deposits, arriving queues and customer payments. |
| M2: progression | Four grills, three registers, movement/recipe/tray upgrades, tables with occupied seats, optional fries combos after 12 sales, drive-through after 25 sales. Costs, caps and locks are enforced by the simulation. |
| M3: automation | Up to three cooks and two cashiers navigate between stations with visible job states. Cooks physically carry stock; cashiers serve arrivals and visit the drive-through. Upgrades affect their actual work rates. |
| M4: polish | Original layered cartoon furniture, characters, burgers, walking/steam/payment animation, dismissible tutorial with Help, permanent Upgrades/Hire staff/Expand tabs, timed dismissible notifications, synthesised sound/mute, portrait layout, pause/focus handling, autosave and validated persistence. |
| M5: web demo | Exact Godot 4.4.1 build/test/export pipeline, strict diagnostic checks, PR validation, web artifacts, browser automation and isolated opt-in Pages deployment. Hosted release and real iOS testing remain subject to the account/device actions above. |

## Original implementation validation evidence

- The baseline build PR is [#2](https://github.com/iugo-glen/burger-boss/pull/2), with a [passing Actions run](https://github.com/iugo-glen/burger-boss/actions/runs/39894440475).
- Integrated Godot **4.4.1** headless import, scene runtime and single-thread Compatibility HTML5 release export passed. Generated output, tooling, tests and documentation are excluded from release resources.
- **1,243 assertions, zero failures**, including per-second invariants in a simulated ten-minute run. This count is not a count of independent test scenarios.
- The fresh manual service test makes its first sale in under 60 seconds. The ten-minute simulation earns both staff roles, buys progression through drive-through, makes **105 additional sales** and serves at least **8 customers in every minute**, without gifted money.
- Persistence checks include JSON/disk round trips, corrupt/truncated/wrong-type/nonfinite/out-of-range data, no mutation on invalid restore, visible staff restoration, midtrip burger conservation and reverse hiring order.
- Independent review found and fixed service before queue arrival, lost staff inventory on reload, reverse hire ordering, occupied table seat reuse, drive queue bounds, tutorial/input issues and generated resource inclusion. No critical source defect remained identified at final review.

The actual HTML5 release was played through controls in all three browser contexts. Each earned $36 from three burgers, bought the $35 speed upgrade, paused and reloaded with three sales, $1 and the purchased upgrade intact. No Godot or JavaScript runtime errors were reported.

| Browser | First sale on a fresh save |
| --- | --- |
| Desktop Chromium | 13.55 seconds |
| Mobile Chromium touch emulation | 12.24 seconds |
| Mobile WebKit emulation | 12.27 seconds |

Local evidence: `build/logs/` (engine logs), `build/browser/report.json` (browser assertions), `build/browser/*-played.png` (screenshots). CI retains corresponding artifacts. These browser timings are test-run observations, not guarantees about individual devices.

The game implementation is [PR #3](https://github.com/iugo-glen/burger-boss/pull/3), stacked on #2. Its PR description records the final GitHub CI and real-time ten-minute touch-session results. Browser-control regressions additionally verify pause freezes simulation time, WASD stops on release and Chromium's actual touch start/move/end events steer the joystick and stop on release.

## Practical limitations

This is a finite, self-contained restaurant demo with one repeatable lunch-rush scenario. Navigation uses direct station routes across an open floor; it does not provide obstacle avoidance or a pathfinding grid. Upgrades are capped. Combo orders consume actual burgers and fries; automatic cooks balance ingredients, or the player can assign individual workers. Rush-only Boss specials require the boss at the serving station. No offline income accrues while paused/backgrounded. Browser storage belongs to each origin/device, and private browsing or cleared site data can remove saves. Earlier unversioned prototype saves are unsupported and start fresh safely. Version-2 saves remain supported. An interrupted rush is cancelled safely on reload while earned progression and inventory are restored.

The release has no external runtime services, account login, analytics, monetisation or paid dependencies. Code, vector art and synthesised audio were created for this implementation. Other games informed the design only.

## Physical Safari acceptance checklist

On the successful deployment URL, use current Safari on an iPhone/iPad: serve a first burger with taps, steer with a drag, buy an upgrade and hire staff, background/resume the tab, reload and confirm currency/upgrades, check portrait and landscape sizing, toggle sound after a gesture, and play for ten minutes. Record the device/iOS version and any console errors. This checklist is pending; emulated results below are reported separately.
