# Burger Boss

An original, offline arcade restaurant game built in Godot **4.4.1**, GDScript and the Compatibility renderer. Build your team, prepare burgers and fries, then take charge of an optional lunch rush. Portrait touch play comes first; desktop keyboard and mouse work too.

## Play

Open `project.godot` in Godot 4.4.1 and run the main scene.

- Tap/click the floor to walk. Drag to steer with a virtual joystick, or use WASD/arrow keys.
- Stand by the orange grill to cook and pick up burgers. Carry them to the blue counter and stay there to collect payment.
- Use the permanent bottom tabs: **Upgrades**, **Hire staff** and **Expand**. Hire staff contains cooks ($90) and cashiers ($120), with their roles explained. Expand contains tables, fries and the drive-through. All purchases use money earned in play.
- Fries unlock after 12 sales. Combo customers need **one burger and one portion of fries at the counter**. Work at the fries station and carry sides to the counter, or assign a cook to do it. Drive-through unlocks after 25 sales; it shares the counter's food stock. Tables attract more customers and provide a dining bonus.
- In **Hire staff**, use the worker selector to choose an individual cook or cashier, then tap their job to cycle it. Cooks can work automatically, make burgers or make fries. Cashiers can work automatically, serve the counter or serve the drive-through. Separate workers can have different jobs. Their movement, production and deliveries are simulated.
- After **25 sales, a cook, a cashier and the fries station**, tap **Start lunch rush · Free**. The 60-second promotion attracts extra customers. Complete the displayed order, combo and Boss-special targets to earn a bonus and increase your rank. Prepare stock and assignments first; targets scale with your kitchen and rank.
- Gold Boss-special orders need burger + fries and the boss present at their serving station. Visit the counter or drive-through to hand them off. Use **Boss boost** while at a station to prepare a batch or unload and expedite complete orders. It recharges in eight seconds; an action that cannot help does not spend it.
- A failed rush costs no penalty and can be retried free. Normal service continues outside promotions. Your upgraded restaurant can still run calmly while you decide when to take on a challenge.
- Use the pause button or Escape to pause and save. Sound can be muted with SFX. Switching away pauses the simulation; there is no offline income.
- Close the tutorial with its **X**; it stays dismissed after reloading. **Help** brings it back. Bottom notifications fade away automatically and can also be closed.

Progress saves approximately every eight seconds and after purchases, assignments, pausing and losing focus. Existing version-2 saves carry over, including maxed restaurants and food in transit. Reloading cancels an unfinished optional rush without a penalty; earned progress, rank and inventory remain saved. Browser saves are local to the browser, device and site origin. Private browsing or blocked storage can prevent persistence; the UI reports write failures. Keep site data to keep progress.

## Build and test

Requirements: Linux x86_64 for the helper installer, Bash, curl, unzip, Node.js 22+ and npm. On other platforms install Godot 4.4.1 and its matching web export templates manually, then set `GODOT_BIN` to the engine executable.

```sh
bash tools/install_godot.sh
bash tools/validate.sh
npm ci
npx playwright install --with-deps chromium webkit
npm run smoke
```

`tools/validate.sh` checks the exact engine version, imports, runs a scene smoke test and the deterministic system tests, then exports `public/index.html`. It fails on Godot error diagnostics even if the engine returns exit code zero. Override `GODOT_BIN` to use an existing 4.4.1 installation. For restricted environments, point `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` at writable directories when installing and running Godot.

The browser suite serves the actual release export over HTTP and checks Chromium desktop, Chromium mobile touch and WebKit mobile emulation. It tests fresh service, controls, hiring, dismissible guidance and save/reload. Mobile Chromium additionally earns the rush unlock through touch play, assigns staff, prepares food, completes a promotion and checks failure, retry and interrupted-rush recovery. Screenshots and JSON evidence go under `build/browser/`. The `?smoke=1` read-only status bridge supports assertions without granting money or changing simulation state. Use `SMOKE_ENGINES=mobile-chromium SMOKE_SECONDS=600 SMOKE_REPORT=build/browser/soak-report.json npm run smoke` for an optional real-time ten-minute touch session. Omit `SMOKE_ENGINES` to run each configured browser.

To play the exported game locally:

```sh
python3 -m http.server 8000 --directory public
```

Visit `http://localhost:8000`. Opening `index.html` directly as a file does not work. The export is single-threaded and does not require cross-origin isolation headers.

## CI and deployment

[GitHub Actions](https://github.com/iugo-glen/burger-boss/actions) validates pull requests and main, exports HTML5, and retains web builds and test evidence as artifacts. Download **burger-boss-web**, extract it and serve it over HTTP to review a build.

**[Play the hosted game](https://iugo-glen.github.io/burger-boss/).** GitHub Pages is configured with GitHub Actions as its source.

Merging an update into `main` automatically validates and publishes it. You can also manually run **Validate and deploy Godot web game** on main to rebuild and republish. Pull requests run validation without publishing.

No repository visibility or secrets are changed by this implementation. Builds and browser tests pass independently of Pages configuration.

## Implementation and limits

`restaurant.gd` owns simulation/economy; `rush_director.gd` owns challenge progress; `save_store.gd` owns persistence; `rush_hud.gd`, the scene coordinator, art renderer and synthesized sound handle presentation. Assets and code were created for this game; no source or assets were copied from reference games. There are no accounts, paid dependencies, analytics, runtime network services or monetization.

This update adds one repeatable lunch-rush scenario. The simulation uses an open restaurant floor and direct station routes. It has a finite set of upgrades; further locations, advertising campaigns and restaurant chapters are not implemented. Saves use a validated versioned schema; corrupt or unsupported saves fall back to a playable fresh restaurant. The earlier unversioned prototype save is unsupported. Clearing site data resets progress.

Real iPhone/iPad Safari testing still requires a physical device. WebKit automation and touch emulation do not establish real iOS support. See [the handoff](docs/HANDOFF.md) for milestone coverage, validation evidence and remaining owner/device actions.
