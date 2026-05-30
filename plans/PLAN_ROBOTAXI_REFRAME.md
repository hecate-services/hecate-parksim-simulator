# Plan: Reframe Parksim as a Robotaxi Fleet Simulator

**Status:** Active — design locked, Phase 1 not yet started
**Date:** 2026-05-30
**Repo:** `codeberg.org/hecate-services/hecate-parksim`

---

## 1. The reframe in one sentence

Parksim stops being a passive parking counter (anonymous cars arrive, pay,
leave) and becomes a living **robotaxi fleet simulator**: ~48 self-driving
vehicles, owned by **4 competing operators**, cruising one shared city
(Leuven), picking up passengers, collecting fares, draining battery, and
docking into facilities to **charge / clean / maintain** — all rendered on
a live map the realm assembles from the 4 operators' mesh feeds.

---

## 2. Locked decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Vehicle is the aggregate** (`guide_vehicle_lifecycle`). Trips are events on the vehicle's stream, not a separate Trip aggregate. | One lifecycle named; no passenger-side bookings to model. Trip-as-aggregate stays a future option. |
| 2 | **4 operators, one city.** Each operator = one beam node = one mesh publisher, owns ~12 vehicles + its depot(s). `company_id` = `TENANT_ID`. | Clean ownership boundary per node; "4 companies share one city" reads as a real market; organic resilience story (node down → that company greys out). |
| 3 | **Fleet ~48 total, 12/company.** | User target ~50, divided cleanly across 4 nodes. |
| 4 | **Position is telemetry, NOT a domain event.** Milestones are events. | 50 vehicles × position/sec would be a write storm into ReckonDB (the CPU-pin shape). Milestones are sparse (~1 event/sec fleet-wide). |
| 5 | **OSRM road routing from the start**, **one OSRM container per node** (sidecar). Each operator's beam runs its own `osrm-routed` on `localhost`; the sim talks to `127.0.0.1`. Vehicles follow real Leuven streets day one. | User chose roads-from-start + per-node. Per-node is operationally simpler: no cross-node LAN dependency, identical deploy unit on every node, and node-down takes its own router with its fleet (clean resilience story — no shared SPOF). Cost: 4× the same read-only graph in RAM (~1–2 GB each; beams have 16–32 GB, fine). A **straight-line fallback** stays in the router client regardless. |
| 6 | **Transmodel/NeTEx/GTFS are NOT for routing** (they model fixed-line public transit). GTFS stop coords *may* seed **demand hotspots** (where ride requests originate) — open-data flourish, demand side only. | Robotaxi = on-demand point-to-point road routing, which is OSM + OSRM, not a transit standard. |
| 7 | **Build order: routing infra (OSRM) first, then the sim against it.** | Roads from day one; the sim's kinematics are written against real polylines, not retrofitted. |

---

## 3. Domain–event vs telemetry split (the load-bearing principle)

| Kind | Examples | Storage | Frequency |
|------|----------|---------|-----------|
| **Domain events** (event-sourced) | `vehicle_commissioned`, `vehicle_dispatched`, `passenger_picked_up`, `passenger_dropped_off` + `fare_collected`, `vehicle_returned`, `vehicle_docked`, `vehicle_serviced`, `vehicle_released`, `battery_depleted` | ReckonDB streams (one per vehicle) | sparse (~1/sec fleet-wide) |
| **Telemetry** (NOT events) | lat/lng, heading, battery %, speed, phase | in-memory in the sim; streamed as a **mesh fact** | high (~1–2 s/vehicle) |
| **Integration facts** (mesh) | per-operator fleet summary; per-vehicle telemetry | mesh topics, consumed by realm | summary 5 s; telemetry 1–2 s |

The simulator is the **fleet brain** (kinematics + dispatch policy). The
**aggregate** enforces business rules (no trip under X% battery; no dock
without a free bay) and writes the audit trail. **Projections** build read
models. The **mesh** carries telemetry + summary to the realm. Position
never touches the store.

---

## 4. The vehicle lifecycle

```
commissioned → cruising → dispatched → on-trip → (fare) → cruising …
                  │ (battery low OR service due)
                  ▼
              returning → docked → servicing → released → cruising
                  │ (battery hits 0 first)
                  ▼
              depleted (stranded → rescue/tow → released)
```

**Status bit flags** (per house rule — integers, `evoq_bit_flags`):

```erlang
-define(VEH_COMMISSIONED, 1).    %% 2^0 — joined the fleet
-define(VEH_CRUISING,     2).    %% 2^1 — idle, available, roaming
-define(VEH_DISPATCHED,   4).    %% 2^2 — assigned a fare, heading to pickup
-define(VEH_ON_TRIP,      8).    %% 2^3 — passenger aboard, meter running
-define(VEH_RETURNING,   16).    %% 2^4 — heading to a facility
-define(VEH_DOCKED,      32).    %% 2^5 — occupying a bay
-define(VEH_SERVICING,   64).    %% 2^6 — charge | clean | maintain in progress
-define(VEH_DEPLETED,   128).    %% 2^7 — battery 0, stranded
```

### Desks (vertical slices) in `guide_vehicle_lifecycle`

| Desk | Command → Event |
|------|-----------------|
| `commission_vehicle` | → `vehicle_commissioned_v1` (joins fleet, full battery, at depot) |
| `dispatch_vehicle` | → `vehicle_dispatched_v1` (assigned a fare, heading to pickup) |
| `pick_up_passenger` | → `passenger_picked_up_v1` (trip starts, meter on) |
| `drop_off_passenger` | → `passenger_dropped_off_v1` + `fare_collected_v1` |
| `dock_vehicle` | → `vehicle_docked_v1` (took a bay) |
| `service_vehicle` | → `vehicle_serviced_v1` (`kind`: charge \| clean \| maintain) |
| `release_vehicle` | → `vehicle_released_v1` (bay freed, back to cruising) |
| `deplete_battery` | → `battery_depleted_v1` (stranded — the failure mode) |

Bay occupancy is a **projection** fed by dock/release events (the global
fleet brain allocates bays — no distributed-allocation race). This reuses
the capacity logic already built for parking lots (`lot_in_progress` →
`bays_occupied`).

---

## 5. Migration map — reuse vs rewrite

All **infrastructure stays** (hecate_om mesh client, reckon_db store, evoq
dispatch, CI/deploy, the realm consumer shell). We swap the *domain*.

| Today | Becomes | Reuse |
|-------|---------|-------|
| `guide_parking_session_lifecycle` | `guide_vehicle_lifecycle` | pattern + dock/release verbs |
| `capture_payment` desk | `collect_fare` (→ `drop_off_passenger`) | rename |
| `simulate_arrivals` (NHPP Lewis–Shedler) | `simulate_demand` (ride requests) | **thinning math reused verbatim** |
| `simulate_visit` (per-visit FSM) | per-vehicle FSM inside `simulate_fleet` | logic reused |
| `parksim_simulator_config` (city lots) | `fleet_config` (city geometry + facilities + fleet roster) | restructured |
| `project_parking_sessions` | `project_fleet` | restructured |
| `query_parking_sessions` | `query_fleet` | restructured |
| `emit_city_summary` | `emit_fleet_summary` + `emit_fleet_telemetry` | extended (telemetry is new) |
| `scavenge_aged_sessions` | drop (vehicles are persistent, not aged out) | removed |

**Net-new code:** the in-memory kinematics engine (`simulate_fleet`) + the
telemetry mesh fact. That is the real new work.

---

## 6. Build order

Roads from the start, so step 0 is the routing infra; everything else is
written against real polylines.

### 6.0 Routing infra — per-node OSRM sidecar (FIRST), option A
- **Option A (no new repo):** the OSRM unit is a Quadlet `.container` /
  compose file + a `prepare-belgium-graph.sh` preprocessing script living in
  the **deploy/infra config** (`macula-demo/infrastructure/`, beside the
  parksim compose), pinned to the upstream
  `ghcr.io/project-osrm/osrm-backend` image. OSRM is a consumed dependency
  (like PostgreSQL/reckon_db), NOT a Hecate service — no `hecate_om`, no mesh,
  no wrapper repo.
- **Preprocess once, distribute the prepared graph.** Run
  `osrm-extract → osrm-partition → osrm-customize` (MLD pipeline) **once** on
  a capable box (HQ/dev) over a Belgium Geofabrik `.osm.pbf`. Ship the
  prepared `.osrm.*` files to each node's data dir. Each node then runs only
  `osrm-routed` (cheap at query time) — avoids 4× heavy preprocessing on the
  weak J4105 Celerons.
- **Per-node sidecar:** each beam runs its own `osrm-routed` bound to
  `127.0.0.1:5000`. The sim queries `GET /route/v1/driving/{lon,lat};{lon,lat}`
  → `{geometry (polyline), distance_m, duration_s}` on localhost — no LAN hop,
  no shared SPOF.
- Sovereign stack: OSM map commons + OSRM self-hosted, no Big Tech, no API
  keys — on "We are Europe".
- **GTFS demand seeding** (optional flourish): De Lijn + SNCB stop
  coordinates as ride-request hotspots — real open data, demand side only.

### 6.1 Domain — `guide_vehicle_lifecycle`
- 8 desks (§4), each: command `_v1`, event `_v1`, `maybe_*` handler, dispatch wrapper.
- `vehicle_aggregate` + `vehicle_state` (bit-flag status, battery %, position, current trip, assigned bay).
- Consistency: **eventual** (sequential dispatches in one process read their own writes — the lesson from the parking revert; do NOT use strong).

### 6.2 Router client — `route_leg`
- Thin OSRM client: `route_leg(From, To)` → `{Polyline, DistanceM, DurationS}`,
  hitting the **local** sidecar (`127.0.0.1:5000`, env-configurable).
- **Graceful fallback:** OSRM unreachable → straight-line interpolation
  (×1.3 distance fudge for battery). The sim runs with or without routing
  infra; a router outage degrades visuals, never blocks the fleet.
- Queried a few times per trip (~40 calls/min per node at peak — trivial for
  a localhost OSRM).

### 6.3 Simulator — `simulate_fleet` (the brain)
- Per-operator (reads `company_id` = `TENANT_ID`). Owns ~12 vehicles.
- In-memory kinematic state per vehicle: position, heading, speed, battery, phase, current **road polyline** (from `route_leg`), current bay.
- **Tick loop** (e.g. 1 s sim-time, scaled): advance each vehicle along its polyline; drain battery ∝ real road distance covered; on polyline-exhaustion fire the milestone command into the aggregate.
- **Dispatch policy:** idle (`cruising`) vehicle + open ride request → pick pickup hotspot → `route_leg` to pickup → on arrival `pick_up_passenger` → `route_leg` to dropoff → `drop_off_passenger` + fare. Battery low or service due → `route_leg` to nearest facility with a free bay → `dock_vehicle` → `service_vehicle` (duration by kind) → `release_vehicle`.
- **Demand** via `simulate_demand` (NHPP thinning reused): ride requests per minute follow a day/night profile; origins biased to hotspots.
- **Battery 0 mid-leg** → `deplete_battery` (stranded); simple rescue after a delay → tow to facility → service → release.

### 6.4 Config — `fleet_config`
- City polygon (Leuven bounds) + a handful of **facilities** (depots) with bay counts and service kinds, at real Leuven coordinates.
- **4 operators** with names + colors + home depot + roster size.
- Demand hotspots (hand-placed first; GTFS-seeded optionally).
- Vehicle/economics params: cruise speed, battery capacity, drain rate, fare model (base + per-km + per-min), service durations.

### 6.5 Projection + query — `project_fleet`, `query_fleet`
- Read models: vehicles (current phase, battery, position-at-last-event, lifetime trips/fares/energy), facilities (bay occupancy), operator rollup (active/charging/stranded, trips today, gross fares, energy kWh, net).
- HTTP read API on the existing edge port (replaces `/api/sessions/*`).

### 6.6 Mesh publishers
- `emit_fleet_summary` (5 s): per-operator rollup fact → `fleet/<company>/summary`.
- `emit_fleet_telemetry` (1–2 s): array of `{vehicle_id, lat, lng, heading, battery, phase}` → `fleet/<company>/telemetry`. **Term in, CBOR on the wire — never JSON-encode the payload.**
- Optional: publish the active polyline for a clicked vehicle so the realm can draw its live route.

### 6.7 Realm consumer + map (`macula-realm/demo`)
- Subscribe `fleet/+/summary` and `fleet/+/telemetry` for the 4 operators.
- **Leaflet map** of Leuven (real tiles): ~48 dots moving along streets, colored **by company**, glyph/shade by phase (cruising / on-trip / returning / charging / stranded). Facilities as buildings with bay-occupancy. Live counters: trips, gross fares, energy kWh, net, charging, stranded — per company + city total.
- Reuses the existing TopologyMap hook know-how.

### 6.8 Deploy
- Same path: docker-compose on beam00–03, one operator per node via `TENANT_ID` (= company). Reset data once on cutover (schema change).
- Each node also runs its **OSRM sidecar** (compose service beside parksim, `127.0.0.1:5000`), with the prepared Belgium graph in a bind-mounted data dir. Map `company_id` → node: beam00..03 = the 4 operators.

### Done = 4 companies' cabs visibly driving Leuven's real streets on the realm map, taking fares, charging at depots, occasional strandings; node-down greys a company out.

---

## 8. Why this is a better Macula demo

- **Living map** beats bar charts: motion sells the mesh.
- **Federated edge → mesh → realm** intact and richer: 4 operators, one
  assembled city.
- **Resilience, organic and true:** node outage greys a company's fleet on
  the map; recovery resumes it. (Replaces the deleted scripted war-scenario.)
- **Springboard to the other workload classes:** on-board LLM passenger Q&A
  (LLM serving); federated demand prediction across operators (federated AI).
- **Sovereign stack:** OSM + OSRM, no Big Tech, no API keys — on "We are
  Europe."

---

## 9. Open follow-ups (not blocking the build)

- Company names + colors (propose 4 Belgian-flavored operators).
- `@parksim_url` / map URL wiring in the realm demo (carried over from the
  prior dashboard task).
- Cross-operator vehicle handoff as a later "wow" (a cab crossing into
  another node's coverage).
- Pick the box that does the one-time graph preprocessing (HQ/dev), then
  distribute the prepared `.osrm.*` files to each node.
- **Stale README:** current `README.md` claims parksim is a *client*
  simulator (fires RPCs, owns no state). The code actually owns the domain
  (aggregates + stores). Rewrite the README for the robotaxi reframe.
