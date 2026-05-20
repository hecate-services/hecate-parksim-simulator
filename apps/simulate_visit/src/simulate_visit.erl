%%% @doc One physical visit through the lane equipment. Replaces the
%%% old logical session ladder: the simulator now emulates the
%%% hardware (a driver + vehicle), and the device divisions
%%% (entry-island / payment-terminal / exit-island) react. See
%%% PLAN_PARKSIM_LANE_EQUIPMENT.md §7.
%%%
%%% A visit holds the physical credential it carries — a `card_id`
%%% (ticket visit) minted here, or a `permit_ref` + plate (permit
%%% visit) — and threads it through every device call so the emitted
%%% events correlate.
%%%
%%% NOTE (follow-up): in a live run the entry island's saga mints its
%%% own card_id when it dispenses; reconciling the simulator's card_id
%%% with the dispensed one needs a read-back. In dry_run the simulator's
%%% self-consistent token is what lazyreckon sees.
-module(simulate_visit).

-export([start_visit/1]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

%% @doc Spawn one visit process. Params:
%%   lot        :: #parksim_lot{}
%%   plate      :: binary()
%%   credential :: ticket | {permit, PermitRef}
-spec start_visit(map()) -> {ok, pid()}.
start_visit(Params) ->
    {ok, proc_lib:spawn(fun() -> run(Params) end)}.

run(#{lot := Lot, plate := Plate, credential := Credential}) ->
    Rng = rand:seed_s(exsss, {erlang:phash2(self()),
                              erlang:phash2(make_ref()),
                              erlang:system_time(microsecond)}),
    LotId = Lot#parksim_lot.id,
    Ctx0  = #{lot_id        => LotId,
              entry_island  => island_id(LotId, <<"entry">>),
              exit_island   => island_id(LotId, <<"exit">>),
              terminal      => terminal_id(LotId),
              plate         => Plate,
              credential    => Credential,
              card_id       => card_id(Credential)},
    simulate_entry_island:admit(Ctx0),
    {Dwell, Rng1} = sample_dwell(Rng, Lot),
    simulate_clock:sleep_simulated(Dwell * 1000),
    walk_out(roll_abandon(Rng1), Ctx0).

%% Abandoned visits never leave (no payment, no exit).
walk_out({true, _Rng}, _Ctx) -> ok;
walk_out({false, Rng}, Ctx) ->
    maybe_pay(maps:get(credential, Ctx), Ctx, Rng),
    simulate_exit_island:egress(Ctx).

%% Ticket visits pay on foot before leaving; permit visits do not.
maybe_pay(ticket, Ctx, Rng) ->
    {Pause, _} = uniform_int_s(Rng, 2, 90),
    simulate_clock:sleep_simulated(Pause * 1000),
    simulate_payment_terminal:pay(Ctx);
maybe_pay({permit, _Ref}, _Ctx, _Rng) ->
    ok.

%%--------------------------------------------------------------------
%% Identity derivation (matches the commission PMs)

island_id(LotId, Kind) -> <<LotId/binary, ":", Kind/binary, ":1">>.
terminal_id(LotId)     -> <<LotId/binary, ":pay:1">>.

card_id(ticket)        -> <<"card-", (hex(crypto:strong_rand_bytes(8)))/binary>>;
card_id({permit, _})   -> undefined.

%%--------------------------------------------------------------------
%% Distributions

%% LogNormal(mu, sigma) clipped to [60, 24h] seconds.
sample_dwell(Rng, #parksim_lot{dwell_mu = Mu, dwell_sigma = Sigma}) ->
    {Z, Rng1} = rand:normal_s(Rng),
    X = math:exp(Mu + Sigma * Z),
    {max(60, min(round(X), 24 * 3600)), Rng1}.

%% ~0.7% of visits abandon (never exit).
roll_abandon(Rng) ->
    {U, Rng1} = rand:uniform_s(Rng),
    {U =< 0.007, Rng1}.

uniform_int_s(Rng, Lo, Hi) when Hi >= Lo ->
    {U, Rng1} = rand:uniform_s(Hi - Lo + 1, Rng),
    {Lo + U - 1, Rng1}.

hex(Bin) -> << <<(nibble(N))>> || <<N:4>> <= Bin >>.
nibble(N) when N < 10 -> $0 + N;
nibble(N)             -> $a + (N - 10).
