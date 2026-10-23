# Agent instructions — Burger Boss

## Mission
Ship a genuinely playable, attractive arcade-idle burger restaurant game with Godot 4.4, exportable to HTML5 and later iOS. Mobile portrait first, mouse/keyboard second. Use original code/assets or appropriately licensed sources with attribution.

## Operating rules
- Begin by running Godot 4.4 headless import and web export. Inspect Actions logs; the current repo is an unverified prototype with likely defects. Fix CI before adding features.
- Work iteratively with small commits, automated tests, and verifiable outputs. Never claim runtime success without running it.
- Implement clean, independently testable gameplay systems. Avoid monolithic game.gd by splitting into scripts/scenes/resources.
- Preserve Godot Compatibility renderer and GDScript for Safari HTML5 compatibility.
- Keep the game offline, no account, monetization, backend, analytics, or paid dependencies.
- Use no unlicensed source code from OutBox or other public repos.
- Do not alter repository visibility or secrets. Use PRs for significant changes.
- No arbitrary time estimates. Do not ask for preferences on minor design choices; choose sensible defaults.
- If multi-agent orchestration is available, split into gameplay/economy, art/UI, QA/CI and integrate after tests. Otherwise perform sequentially.
- Include a concise handoff report with features, test results, remaining bugs, web preview and exact deployment requirements.

## Definition of done
- Godot imports headlessly and web export succeeds in GitHub Actions.
- A mobile portrait browser player can move, cook, carry burgers, serve customers, earn/spend, upgrade, hire staff, unlock tables/drive-through, and save/restore progress.
- Visual feedback/animations, comprehensible UI, accessible touch controls, sensible balanced progression.
- Staff actually navigate and do work visibly, not just counters.
- Gameplay can run at least 10 minutes without deadlocks or blockers.
- Tests cover economy, upgrades, serialization, unlocks and queue progression.
- No serious Godot parser errors, workflow errors or avoidable Safari constraints.
