%%% @doc eunit tests for the fleet mesh-fact builders.
%%%
%%% Asserts the integration-fact CONTRACT shape (the stable subset realm
%%% consumers depend on) and that the builders are degrade-safe: with the
%%% read model + sim NOT running, `to_fact/1' must still return a well-formed
%%% fact (the `safe/2' fallbacks kick in), never crash. This guards the
%%% promise that a dark service skips a tick rather than falling over.
-module(emit_fleet_facts_tests).
-include_lib("eunit/include/eunit.hrl").

%% Summary fact carries the contract keys even when the store is down.
summary_fact_shape_test() ->
    F = emit_fleet_summary:to_fact(<<"leuven">>),
    ?assertEqual(fleet_summary, maps:get(type, F)),
    ?assertEqual(<<"leuven">>, maps:get(company, F)),
    Keys = [total, cruising, dispatched, on_trip, returning, docked,
            servicing, charging, depleted, active, trips, revenue_cents,
            facilities, observed_at],
    [?assert(maps:is_key(K, F)) || K <- Keys],
    %% counts default to 0 (read model down), facilities to [] — never crash.
    ?assertEqual(0, maps:get(total, F)),
    ?assertEqual([], maps:get(facilities, F)),
    ?assert(is_integer(maps:get(observed_at, F))).

%% Telemetry fact carries an (empty, when the sim is down) vehicles list.
telemetry_fact_shape_test() ->
    F = emit_fleet_telemetry:to_fact(<<"brussels">>),
    ?assertEqual(fleet_telemetry, maps:get(type, F)),
    ?assertEqual(<<"brussels">>, maps:get(company, F)),
    ?assertEqual([], maps:get(vehicles, F)),
    ?assert(is_integer(maps:get(observed_at, F))).
