%%% @doc Supervisor for the robotaxi fleet brain. Owns the single
%%% `simulate_fleet' gen_server (one per node = one operator).
-module(simulate_fleet_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    Fleet = #{id => simulate_fleet,
              start => {simulate_fleet, start_link, []}},
    {ok, {SupFlags, [Fleet]}}.
