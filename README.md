# Burger Boss

An original, offline arcade restaurant game built in Godot **4.4.1**, GDScript and the Compatibility renderer. Cook burgers, carry them to the counter, serve customers, then grow from a one-person shop into an automated restaurant. Portrait touch play comes first; desktop keyboard and mouse work too.

## Play

Open `project.godot` in Godot 4.4.1 and run the main scene.

- Tap/click the floor to walk. Drag to steer with a virtual joystick, or use WASD/arrow keys.
- Stand by the orange grill to cook and pick up burgers. Carry them to the blue counter and stay there to collect payment.
- Buy upgrades at the bottom. **Team & more** contains cooks, cashiers, tables, fries and the drive-through. A cook costs $90; a cashier costs $120. All purchases use money earned in play.
- Cooks walk between the grill and counter carrying burgers. Cashiers serve the counter and visit the drive-through when unlocked. Grill/register, movement speed, recipe value and tray upgrades change actual gameplay.
- Fries unlock after 12 sales and add optional combo income; drive-through unlocks after 25. Tables attract more customers and provide a dining bonus.
- Use the pause button or Escape to pause and save. Sound can be muted with SFX. Switching away pauses the simulation; there is no offline income.

Progress saves approximately every eight seconds and after purchases, pausing and losing focus. Browser saves are local to the browser, device and site origin. Private browsing or blocked storage can prevent persistence; the UI reports write failures. Keep site data to keep progress.

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

The browser suite serves the actual release export over HTTP and checks Chromium desktop, Chromium mobile touch and WebKit mobile emulation. It tests a fresh first sale, pause/save and reload, and collects screenshots and a JSON report under `build/browser/`. The `?smoke=1` read-only status bridge supports assertions without granting money or changing simulation state. Use `SMOKE_SECONDS=600 npm run smoke` for an optional real-time extended run on each configured browser.

To play the exported game locally:

```sh
python3 -m http.server 8000 --directory public
```

Visit `http://localhost:8000`. Opening `index.html` directly as a file does not work. The export is single-threaded and does not require cross-origin isolation headers.

## CI and deployment

[GitHub Actions](https://github.com/iugo-glen/burger-boss/actions) validates pull requests and main, exports HTML5, and retains web builds and test evidence as artifacts. Download **burger-boss-web**, extract it and serve it over HTTP to review a build.

**Hosted demo is pending owner setup.** The upstream deployment failed because GitHub Pages was not configured. The repository owner must:

1. Open **Settings → Pages**, enable Pages where supported by the private repository's account plan, and select **GitHub Actions** as the source.
2. Merge the build PR, then the game PR into `main`.
3. Set **Settings → Secrets and variables → Actions → Variables → PAGES_ENABLED** to `true`, or manually run the workflow on main with its deploy input selected.
4. Use the deployment URL returned by the successful Pages job. No live demo URL is claimed before deployment succeeds.

No repository visibility or secrets are changed by this implementation. Builds and browser tests pass independently of Pages configuration.

## Implementation and limits

`restaurant.gd` owns simulation/economy; `save_store.gd` owns persistence; the scene coordinator, art renderer and synthesized sound handle presentation. Assets and code were created for this game; no source or assets were copied from reference games. There are no accounts, paid dependencies, analytics, runtime network services or monetization.

The simulation uses an open restaurant floor and direct station routes. It has a finite set of upgrades rather than unlimited content. Saves use a validated versioned schema; corrupt or unsupported saves fall back to a playable fresh restaurant. The earlier unversioned prototype save is unsupported. Clearing site data resets progress.

Real iPhone/iPad Safari testing still requires a physical device. WebKit automation and touch emulation do not establish real iOS support. See [the handoff](docs/HANDOFF.md) for milestone coverage, validation evidence and remaining owner/device actions.
