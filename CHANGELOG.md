# Changelog

All notable changes to **hecate-parksim-simulator** are documented here.

## [0.1.0] - 2026-05-19

### Added

- Initial scaffold. Replaces the retired Go driver
  (`hecate-parksim-driver`) with an Erlang sibling that speaks the
  same wire (mesh) as everything else in the family.
- Umbrella with five sub-apps: `parksim_simulator` (mesh wrapper +
  capability constants + scenario presets + plate pool),
  `simulate_clock`, `simulate_arrivals`, `simulate_sessions`,
  `simulate_lots`, `simulate_pricing`.
- Cowboy admin surface (`/health`, `/api/run`, `/api/event`,
  `/api/evacuate`) on port 8473.
- `dry_run` mode logs mesh calls instead of dispatching — default
  true so the simulator works against an empty mesh.
- Three preset shapes (`demo` / `city` / `stress`) per
  `PLAN_PARKSIM_TRAFFIC_MODEL.md` §1.
- NHPP arrivals via Lewis–Shedler thinning; lognormal dwell;
  categorical payment outcomes matching §4.1; weekly maintenance
  windows, daily sensor calibrations, 2-hourly sweeps; optional
  evacuation drill at sim-hour 4.
