%%% @doc Domain supervisor for the parking-session-lifecycle CMD app.
%%%
%%% Desks (initiate_parking_session, capture_payment,
%%% archive_parking_session) are pure-function command paths dispatched
%%% via evoq_dispatcher — they don't own processes, so no children here.
-module(guide_parking_session_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [],
    {ok, {SupFlags, Children}}.
