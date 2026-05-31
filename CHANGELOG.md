# Changelog

All notable changes to **hecate-parksim-simulator** are documented here.

## [Unreleased]

## [0.2.0] - 2026-05-31

### Changed

- **Robotaxi / ClankerCab reframe** (170e0f3). Reframed the simulator as a
  federated autonomous-cab fleet: `guide_vehicle_lifecycle`, `project_fleet`,
  `query_fleet`, `simulate_fleet` emitting per-operator
  `fleet/<tenant>/{summary,telemetry}` facts on the `io.macula` mesh — the
  source the realm-side ClankerCab LiveView consumes. (Parking-session apps
  retained alongside.)
- **Physical-device-first rebuild** (PLAN_PARKSIM_LANE_EQUIPMENT.md §7).
  The simulator now emulates the lane *hardware* instead of firing
  logical session commands. Retired the `simulate_sessions` app;
  added `simulate_visit` (the per-visit walk) with three device-stimulus
  emitters: `simulate_entry_island`, `simulate_payment_terminal`,
  `simulate_exit_island`. A visit carries a physical credential
  (minted `card_id` for ticket visits, or a `permit_ref` for permit
  visits) threaded through every device call.
- `simulate_arrivals` now decides ticket vs permit per arrival from the
  lot's `permit_share` and starts a `simulate_visit`.
- `simulate_lots` `open_lot` now declares the lot's lane-equipment
  inventory inline (one entry island, one exit island, one terminal) so
  the equipment divisions' commission PMs fan out.
- Added entry-island / exit-island / payment-terminal capability
  constants.

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
