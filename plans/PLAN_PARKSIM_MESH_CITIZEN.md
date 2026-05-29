# PLAN: make parksim a proper meshed realm citizen

**Status:** Open — not started.
**Date:** 2026-05-29
**Priority:** Medium (the viewing demo works without it; this is correctness, not a blocker).

---

## Context

parksim is an `hecate_om_service` — i.e. a Layer-2 realm service. Mesh
presence is *constitutive* of that: an om service is supposed to connect
to the realm, advertise its capability, and be discoverable. The `macula`
SDK dependency is therefore correct and load-bearing, **not** bloat.

But the cluster we deployed on beam00-03 (2026-05-29) runs parksim
**dark**: the Macula SDK boots its sup tree (`macula_root`,
`macula_metrics`, `macula_quic` NIF), but there is nothing for it to attach
to and nothing configured to advertise. Confirmed on beam00:

- container has **no `/run/macula`, no `MACULA_*`/realm env**;
- the beam hosts run **no `macula-station`** (Layer 0) — `hecate-daemon`
  runs as a mesh *client* to the Hetzner/Leuven relays, not a station;
- `docker-compose.parksim.yml` mounts no realm cert and sets no
  `MACULA_RELAYS`;
- the boot log shows **no station-connect, no capability advertise, no
  realm line**.

So parksim is a correct *local event source* (events flow to its
per-tenant reckon-db store, federated by the gateway catalogue and read by
lazyreckon over gRPC→dist) but a *half-citizen* of the realm: reachable via
the gateway's back-channel Erlang dist, invisible on the mesh.

**This plan does NOT touch the lazyreckon viewing path** — that works today
and is independent of mesh presence.

---

## What "meshed properly" requires

Mirror how `hecate-daemon` attaches on the same beams (it connects directly
to relays; no local station needed):

1. **Realm service-principal cert.** Each parksim instance needs an
   identity minted by `hecate-realm` (service principal, not a human
   member). Decide granularity: one cert per tenant, or one per node.
   Mount read-only into the container (the retired gitops quadlet gestured
   at `/etc/hecate/secrets/hecate-parksim-simulator`).
2. **Relay wiring.** Add to `hecate-parksim.env` (per beam), matching the
   daemon's values:
   - `MACULA_RELAYS=https://station-be-leuven-*.macula.io:4433,...`
   - `HECATE_MESH_REALM=io.macula`
   - `HECATE_MESH_AUTOSTART=1` (or the om substrate's equivalent)
3. **om advertise config.** Determine what `hecate_om` reads to advertise a
   capability and on which topic/MRI, and what parksim *should* advertise
   (presence only? a query capability? a FACT stream of parking activity?).
   → needs a read of the `hecate-om` substrate API.
4. **Deploy changes.** Mount the cert + add the env in
   `docker-compose.parksim.yml` / `scripts/deploy-parksim.sh` (or the
   per-beam `hecate-parksim.env`).

---

## Open questions

- **What does parksim advertise?** Presence as a realm service, a queryable
  capability (e.g. "parking sessions for tenant X"), or does it publish
  parking-activity **FACTs** to a mesh topic for other contexts to consume?
  (Domain events stay local in reckon-db; any mesh exposure must be an
  explicit integration FACT with a stable public schema — do not bridge
  raw domain events to the mesh.)
- **Cert granularity** — per tenant vs per node.
- **Does `hecate_om` advertise automatically once relays + cert are
  present, or is there an explicit advertise call to wire?**
- Should mesh presence be gated behind a flag so a dark/local mode stays
  available for isolated testing?

---

## Acceptance

- parksim boot log shows relay connect + realm attach + capability
  advertise.
- parksim is discoverable as a realm capability (e.g. visible to a
  console/observer querying the realm), not only reachable via the
  gateway's dist back-channel.
- The lazyreckon viewing path still works unchanged.

---

## References

- Tier model: Layer 2 = realm-bound service; `macula-`/`hecate-` naming
  rule ("`macula-` = depends on the Macula SDK").
- Daemon relay wiring: `macula-demo/infrastructure/beam00.lab/hecate-daemon.env.example`
  (`MACULA_RELAYS`, `HECATE_MESH_REALM=io.macula`, `HECATE_MESH_AUTOSTART=1`).
- Current dark deploy: `macula-demo/infrastructure/scripts/docker-compose.parksim.yml`,
  `beam{00-03}.lab/hecate-parksim.env`, `scripts/deploy-parksim.sh`.
- Domain-events-vs-integration-facts boundary (do not bridge raw events to mesh).
