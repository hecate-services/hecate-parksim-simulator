%%% @doc Domain supervisor for the parking-session-lifecycle CMD app.
%%%
%%% Desks (initiate_parking_session, dock_vehicle, undock_vehicle,
%%% capture_payment, archive_parking_session) are pure-function command
%%% paths dispatched via evoq_dispatcher — they own no processes. The
%%% one stateful child is the retention sweep, which snapshots archived
%%% session dossiers and scavenges their aged-out event streams.
-module(guide_parking_session_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        #{id    => retain_parking_sessions,
          start => {retain_parking_sessions, start_link, []},
          type  => worker}
    ],
    {ok, {SupFlags, Children}}.
