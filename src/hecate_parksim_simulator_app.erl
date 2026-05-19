%%% @doc hecate-parksim-simulator OTP application entry.
-module(hecate_parksim_simulator_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    hecate_om:boot(hecate_parksim_simulator_service).

stop(_State) ->
    ok.
