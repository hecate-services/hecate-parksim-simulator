%%% @doc project_fleet OTP application entry.
-module(project_fleet_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    project_fleet_sup:start_link().

stop(_State) ->
    ok.
