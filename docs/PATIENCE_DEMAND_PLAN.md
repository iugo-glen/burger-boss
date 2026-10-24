# Career patience and demand plan

Scope: ideas 1 and 2 from [the gameplay review](https://github.com/iugo-glen/burger-boss/blob/docs/gameplay-review/docs/GAMEPLAY_REVIEW.md), career only as confirmed by the owner. Score Attack and Fastest to max retain their current simulation rules and comparable personal bests. Stop at a green pull request; do not merge or start idea 3.

## Changes

- Give calm career customers 45 seconds of patience plus 5 seconds per table. Career rush orders retain 30 seconds. Count down only at the current queue position, once per tick, and show departures and patience clearly.
- Persist a validated optional calm-career lost counter, defaulting to zero for existing version 2 saves. Export it and derived demand, queue capacity and arrival interval through telemetry. Keep presentation effects outside the deterministic simulation.
- Derive calm demand from sales and tables: 18 + 0.08 * min(sold, 300) + 1.5 * tables arrivals per minute. Grow the queue from 8 to at most 14 within the current floor layout.
- Remove the register term from career rush targets. Preserve the existing challenge-mode target formula.

## Tests and balance targets

Retune and extend existing restaurant tests without removing invariants: settled-only expiry, no payment for lost customers, old-save defaults and transactional rejection, increasing demand, queue bounds, rush balance and ten-minute sustained sales. Preserve all score-mode balance results. Extend real browser journeys to observe a calm departure, unchanged income, visible feedback and lost-counter persistence.

Aim for at least the existing nine sales in every minute of the natural ten-minute fixture, with no deadlock. Mature, deliberately assigned staff at 300 sales should sustain at least 45 sales per minute against 48 arrivals, with a peak queue below 14 and no sustained losses. Measure both empty and stocked starts, and report Auto-assignment congestion honestly. Re-record the full rush balance table in HANDOFF.md.

## Review corrections

The review predates scoring modes. Its example demand formula actually gives approximately 18, 35 and 60 arrivals per minute, rather than its stated 18, 30 and 48; the proposed linear curve follows the stated gentler targets. Patience events and bars already exist for challenges and rushes, so extend those facilities while preserving challenge behaviour. A queue above 14 needs a layout change; this PR bounds growth instead.

## Checks before opening the plan PR

On unchanged main e9e04cf, bash tools/validate.sh passed Godot 4.4.1 import, runtime, 1,407 restaurant checks, 50 score checks and HTML5 export. Default npm run smoke passed desktop Chromium, mobile Chromium and mobile WebKit with no runtime errors, including a full 300-second score run. The existing natural ten-minute fixture recorded 154 additional sales and a minimum of nine sales per minute.

Implementation validation results will be added to the PR after rerunning both commands.
