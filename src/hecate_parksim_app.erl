%%% @doc hecate-parksim OTP application entry.
-module(hecate_parksim_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    hecate_om:boot(hecate_parksim_service).

stop(_State) ->
    ok.
