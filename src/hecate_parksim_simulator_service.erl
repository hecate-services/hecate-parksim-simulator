%%% @doc parksim-simulator — implements the hecate_om_service behaviour.
%%%
%%% The simulator is a realm-bound *client* of the parksim trio: it
%%% calls capabilities, it doesn't advertise any of its own.
-module(hecate_parksim_simulator_service).
-behaviour(hecate_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).

info() ->
    #{
        name        => <<"hecate-parksim-simulator">>,
        version     => <<"0.1.0">>,
        description => <<"Realm-bound traffic simulator for the parksim service family">>
    }.

start(_Opts) ->
    hecate_parksim_simulator_sup:start_link().

stop(_State) ->
    ok.

health() ->
    ok.

capabilities() ->
    %% The simulator publishes nothing on the mesh; it consumes.
    [].

identity_spec() ->
    #{
        scope     => <<"hecate-parksim-simulator">>,
        actions   => [<<"call_parksim_capabilities">>],
        resources => [<<"hecate-parksim-entry2exit/*">>,
                      <<"hecate-parksim-lot/*">>,
                      <<"hecate-parksim-pricing/*">>],
        ttl_days  => 30
    }.
