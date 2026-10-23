# Burger Boss

Original, experimental Godot 4.4 arcade-idle burger shop. Inspired by the progression and player-operated gameplay of arcade tycoon games. No OutBox or other third-party repository source code is copied.

## Play locally

1. Install Godot 4.4.1.
2. Open `project.godot` in Godot.
3. Run the project.
4. Click/tap to move, or use arrow keys / WASD.
5. Stand near the grill to cook burgers. Stand by the counter to serve waiting customers.
6. Upgrade the grill and register, hire cooks and cashiers, add tables, and eventually unlock a drive-through.

Money and progression save in local user storage approximately every ten seconds.

## Automated web build

Pushes to `main` trigger [GitHub Actions](https://github.com/iugo-glen/burger-boss/actions), which imports the project, validates it headlessly and exports an HTML5 game. To publish, enable **GitHub Pages** with the **GitHub Actions** source in the repository settings.

**Status:** This is an initial playable code prototype, not a polished game. The automated engine validation and browser deployment must succeed before declaring it tested. Current visuals are 2D placeholders. iPhone Safari behaviour is not yet verified.

## Planned improvements

Isometric characters and assets, animated restaurant stations, better worker navigation, sound, richer customer logic, daily goals, progression balancing and device testing.

## Licensing and provenance

The current code was written specifically for this experiment. Other public repos were used only as design inspiration. Publicly visible source code is not automatically open-licensed.
