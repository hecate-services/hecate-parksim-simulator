%%% @doc Boots a rate per lot, seeds the permit roster, and keeps a
%%% ticker for surge windows + permit lifecycle cadence.
-module(simulate_pricing_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Fire one-shot boot — publish a rate per lot and seed the permit roster.
    spawn(fun() -> simulate_pricing:boot() end),
    Children = [
        #{id => simulate_pricing_ticker,
          start => {simulate_pricing, start_link, []},
          restart => permanent, shutdown => 5000,
          type => worker, modules => [simulate_pricing]}
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
