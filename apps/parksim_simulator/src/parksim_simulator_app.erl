-module(parksim_simulator_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    parksim_simulator_sup:start_link().

stop(_State) ->
    ok.
