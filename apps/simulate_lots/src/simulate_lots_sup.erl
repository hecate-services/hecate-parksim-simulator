%%% @doc Spawns a cadence worker per lot; also runs `boot/0` once at
%%% start so the lots exist on the service side before traffic begins.
-module(simulate_lots_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Fire one-shot boot — open every lot, set capacity, assign zones.
    spawn(fun() -> simulate_lots:boot() end),
    Preset = parksim_simulator_config:preset(),
    Children = [cadence_child(L) || L <- Preset#parksim_preset.lots],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.

cadence_child(#parksim_lot{id = LotId} = Lot) ->
    Name = list_to_atom("simulate_lot_cadence_" ++ binary_to_list(LotId)),
    #{id => Name,
      start => {simulate_lots, start_link, [Name, Lot]},
      restart => permanent, shutdown => 5000,
      type => worker, modules => [simulate_lots]}.
