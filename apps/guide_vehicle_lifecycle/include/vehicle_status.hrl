%%% @doc Phase bit-flag macros for the vehicle aggregate.
%%%
%%% Powers of two, kept in a non_neg_integer in
%%% `#vehicle_state.status_flags` and folded with `evoq_bit_flags`.
%%%
%%% UNLIKE the parking_session flags (which ACCUMULATE — a session is
%%% both DOCKED and PAID at once), a vehicle's operating phase is a STATE
%%% MACHINE: exactly one phase bit is set at a time. Each event clears the
%%% prior phase and sets the new one (see vehicle_state:set_phase/2). The
%%% legal transitions are enforced by each handler's preconditions, not by
%%% the bit layout.
%%%
%%%   commissioned -> cruising -> dispatched -> on_trip -> cruising ...
%%%                      |  (battery low OR service due)
%%%                      v
%%%                  returning -> docked -> servicing -> (released) cruising
%%%                      |  (battery hits 0 first)
%%%                      v
%%%                  depleted (stranded -> rescue -> released)

-define(VEH_COMMISSIONED, 1).    %% 2^0 — joined the fleet, idle at depot
-define(VEH_CRUISING,     2).    %% 2^1 — available, roaming for fares
-define(VEH_DISPATCHED,   4).    %% 2^2 — assigned a fare, en route to pickup
-define(VEH_ON_TRIP,      8).    %% 2^3 — passenger aboard, meter running
-define(VEH_RETURNING,   16).    %% 2^4 — heading to a facility (charge/service)
-define(VEH_DOCKED,      32).    %% 2^5 — occupying a bay
-define(VEH_SERVICING,   64).    %% 2^6 — charge | clean | maintain in progress
-define(VEH_DEPLETED,   128).    %% 2^7 — battery 0, stranded

%% All phase bits — used to clear the current phase before setting the next.
-define(VEH_ALL_PHASES, [?VEH_COMMISSIONED, ?VEH_CRUISING, ?VEH_DISPATCHED,
                         ?VEH_ON_TRIP, ?VEH_RETURNING, ?VEH_DOCKED,
                         ?VEH_SERVICING, ?VEH_DEPLETED]).
