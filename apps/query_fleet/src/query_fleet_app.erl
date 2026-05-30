%%% @doc query_fleet OTP application + cowboy listener.
%%%
%%% Listens on a distinct port from the parking query app so both can run
%%% during the robotaxi transition (parking on 8473, fleet on 8474).
-module(query_fleet_app).
-behaviour(application).

-export([start/2, stop/1]).

-define(PORT, 8474).

start(_StartType, _StartArgs) ->
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/api/fleet/overview",   query_fleet_api, overview},
            {"/api/fleet/vehicles",   query_fleet_api, vehicles},
            {"/api/fleet/facilities", query_fleet_api, facilities},
            {"/api/fleet/recent",     query_fleet_api, recent},
            {"/health",               query_fleet_api, health}
        ]}
    ]),
    {ok, _} = cowboy:start_clear(query_fleet_http,
                                 [{port, ?PORT}],
                                 #{env => #{dispatch => Dispatch}}),
    query_fleet_sup:start_link().

stop(_State) ->
    cowboy:stop_listener(query_fleet_http),
    ok.
