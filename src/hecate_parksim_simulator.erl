%%% @doc Public facade for hecate-parksim-simulator.
-module(hecate_parksim_simulator).

-export([info/0, health/0, capabilities/0]).

-spec info() -> map().
info() -> hecate_parksim_simulator_service:info().

-spec health() -> hecate_om_service:health().
health() -> hecate_om:health().

-spec capabilities() -> [hecate_om_service:capability()].
capabilities() -> hecate_parksim_simulator_service:capabilities().
