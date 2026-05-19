%%% @doc Spawns one arrivals worker per configured lot.
-module(simulate_arrivals_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Preset  = parksim_simulator_config:preset(),
    PoolRng = rand:seed_s(exsss, {parksim_simulator_config:seed(), 0, 0}),
    Lots    = Preset#parksim_preset.lots,
    %% Build a shared plate pool once, hand each worker a slice of the
    %% same pool (so plates can be drawn cross-lot for realism).
    {Plates, _Rng1} = parksim_simulator_plates:new_pool(
        PoolRng, Preset#parksim_preset.plate_pool_size),
    Children = [arrivals_child(Lot, Plates, Idx)
                || {Idx, Lot} <- lists:zip(lists:seq(1, length(Lots)), Lots)],
    {ok, {SupFlags, Children}}.

arrivals_child(#parksim_lot{id = LotId} = Lot, Plates, Idx) ->
    Name = list_to_atom("simulate_arrivals_" ++ binary_to_list(LotId)),
    #{id => Name,
      start => {simulate_arrivals, start_link, [Name, Lot, Plates, Idx]},
      restart => permanent, shutdown => 5000,
      type => worker, modules => [simulate_arrivals]}.
