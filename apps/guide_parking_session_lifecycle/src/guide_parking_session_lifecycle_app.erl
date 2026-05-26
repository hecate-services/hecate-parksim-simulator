%%% @doc guide_parking_session_lifecycle OTP application entry.
-module(guide_parking_session_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_parking_session_lifecycle_sup:start_link().

stop(_State) ->
    ok.
