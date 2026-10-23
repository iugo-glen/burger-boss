# Burger Boss implementation handoff

Scope: [issue #1](https://github.com/iugo-glen/burger-boss/issues/1), all five milestones. The implementation uses original GDScript, procedural vector art and synthesized audio, with no third-party game assets or runtime services.

## Baseline diagnosis

The upstream Actions run [39893216248](https://github.com/iugo-glen/burger-boss/actions/runs/39893216248) imported and exported the prototype with Godot 4.4.1 successfully. Deployment failed in `actions/configure-pages` with `Get Pages site failed ... Not Found`. The workflow previously ran only on main, did not test pull requests, and relied on Godot exit codes without checking diagnostic output.

Local runtime setup must put Godot's XDG data/config/cache directories in writable locations. The environment's default Godot is 4.6.3; acceptance validation uses the downloaded 4.4.1 binary and matching web templates.

## Account and device intervention

- Repository owner: open **Settings → Pages**, enable Pages if available for the account's private repository plan, and select **GitHub Actions** as the build source. No repository visibility or secrets have been changed. See the README for the deployment opt-in after configuration.
- A real iPhone/iPad running current Safari must be tested by a person with that device. Desktop browser automation and mobile viewport emulation do not prove real iOS compatibility.

## Milestones implemented

| Milestone | Working implementation |
| --- | --- |
| M1: reliable loop | WASD/arrows, tap movement and drag joystick; timed grilling, finite tray, visible burger carrying, counter deposits, arriving queues and customer payments. |
| M2: progression | Four grills, three registers, movement/recipe/tray upgrades, tables with occupied seats, optional fries combos after 12 sales, drive-through after 25 sales. Costs, caps and locks are enforced by the simulation. |
| M3: automation | Up to three cooks and two cashiers navigate between stations with visible job states. Cooks physically carry stock; cashiers serve arrivals and visit the drive-through. Upgrades affect their actual work rates. |
| M4: polish | Original layered cartoon furniture, characters, burgers, walking/steam/payment animation, tutorial, two upgrade pages, synthesized sound/mute, portrait layout, pause/focus handling, autosave and validated persistence. |
| M5: web demo | Exact Godot 4.4.1 build/test/export pipeline, strict diagnostic checks, PR validation, web artifacts, browser automation and isolated opt-in Pages deployment. Hosted release and real iOS testing remain subject to the account/device actions above. |

## Validation evidence

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

This is a finite, self-contained restaurant demo. Navigation uses direct station routes across an open floor; it does not provide obstacle avoidance or a pathfinding grid. Upgrades are capped. Fries are an optional player-run station; they never block a customer's burger order. No offline income accrues while paused/backgrounded. Browser storage belongs to each origin/device, and private browsing or cleared site data can remove saves. Earlier unversioned prototype saves are unsupported and start fresh safely.

The release has no external runtime services, account login, analytics, monetization or paid dependencies. Code, vector art and synthesized audio were created for this implementation. Other games informed the design only.

## Physical Safari acceptance checklist

On the successful deployment URL, use current Safari on an iPhone/iPad: serve a first burger with taps, steer with a drag, buy an upgrade and hire staff, background/resume the tab, reload and confirm currency/upgrades, check portrait and landscape sizing, toggle sound after a gesture, and play for ten minutes. Record the device/iOS version and any console errors. This checklist is pending; emulated results below are reported separately.
