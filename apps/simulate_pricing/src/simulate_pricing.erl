%%% @doc Pricing cadence: boots a rate per lot, seeds the permit
%%% roster, fires weekly surge windows + permit lifecycle ticks.
-module(simulate_pricing).
-behaviour(gen_server).

-export([start_link/0, boot/0, inject_event/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

-record(state, {
    rng :: rand:state()
}).

%% --- API ------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Boots one rate per lot + the initial permit roster.
boot() ->
    Preset = parksim_simulator_config:preset(),
    Now    = simulate_clock:now_iso8601(),
    Caps   = parksim_simulator_capabilities,
    Mesh   = parksim_simulator_mesh,
    Tiers  = default_tier_table(),
    lists:foreach(
        fun(#parksim_lot{id = LotId}) ->
            RateId = uuid_v4(),
            _ = Mesh:call(Caps:draft_rate(),
                          #{rate_id  => RateId,
                            lot_id   => LotId,
                            tiers    => Tiers,
                            currency => <<"EUR">>,
                            at       => Now}),
            _ = Mesh:call(Caps:publish_rate(),
                          #{rate_id      => RateId,
                            lot_id       => LotId,
                            effective_at => Now,
                            at           => Now})
        end,
        Preset#parksim_preset.lots),
    seed_permit_roster(Preset),
    ok.

%% Fire an ad-hoc surge window.
inject_event(#{kind := _Kind, at := At, duration_s := DurS, multiplier := Mult}) ->
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    WindowId = uuid_v4(),
    %% Synthetic rate id; the issue_quote PM only kicks in if the
    %% pricing service can resolve a real rate from its read model.
    RateId   = <<"ad-hoc-rate">>,
    ClosesAt = add_seconds(At, DurS),
    Mesh:call(Caps:open_surge_window(),
              #{rate_id    => RateId,
                window_id  => WindowId,
                multiplier => Mult,
                opens_at   => At,
                closes_at  => ClosesAt,
                at         => simulate_clock:now_iso8601()}),
    spawn(fun() ->
        simulate_clock:sleep_simulated(DurS * 1000),
        _ = Mesh:call(Caps:close_surge_window(),
                      #{rate_id   => RateId,
                        window_id => WindowId,
                        at        => simulate_clock:now_iso8601()})
    end),
    ok.

%% --- gen_server -----------------------------------------------------

init([]) ->
    Seed = parksim_simulator_config:seed() + 999,
    Rng  = rand:seed_s(exsss, {Seed, Seed, Seed}),
    schedule_tick(),
    {ok, #state{rng = Rng}}.

handle_call(_Msg, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)         -> {noreply, State}.

handle_info(tick, State) ->
    NewState = tick(State),
    schedule_tick(),
    {noreply, NewState};
handle_info(_, State) -> {noreply, State}.

terminate(_, _) -> ok.

%% --- ticker logic ---------------------------------------------------

schedule_tick() ->
    %% Tick every simulated 30 minutes.
    erlang:send_after(round(30 * 60 * 1000 / simulate_clock:scale()),
                      self(), tick).

tick(State) ->
    {U, R1} = rand:uniform_s(State#state.rng),
    %% Cheap renewal ~once per tick (rough match to §6: 5/day in city).
    case U < 0.1 of
        true  -> fire_renewal();
        false -> ok
    end,
    State#state{rng = R1}.

%% --- permit roster --------------------------------------------------

seed_permit_roster(#parksim_preset{} = Preset) ->
    Now = simulate_clock:now_iso8601(),
    Future = add_seconds(Now, 365 * 24 * 3600),
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    LotIds = [L#parksim_lot.id || L <- Preset#parksim_preset.lots],
    Rng0 = rand:seed_s(exsss, {parksim_simulator_config:seed() + 2026, 0, 0}),
    {_, _Rng1} = lists:foldl(
        fun(_I, {N, RngAcc}) ->
            PermitId = uuid_v4(),
            CustomerId = uuid_v4(),
            Plate = synth_plate(N),
            {Scope, RngAcc1} = choose_scope(RngAcc, LotIds),
            _ = Mesh:call(Caps:request_permit(),
                          #{permit_id      => PermitId,
                            customer_id    => CustomerId,
                            vehicle_plate  => Plate,
                            lot_scope      => Scope,
                            requested_from => Now,
                            requested_to   => Future,
                            at             => Now}),
            _ = Mesh:call(Caps:approve_permit(),
                          #{permit_id => PermitId,
                            approver  => <<"demo-operator">>,
                            at        => Now}),
            _ = Mesh:call(Caps:issue_permit(),
                          #{permit_id  => PermitId,
                            valid_from => Now,
                            valid_to   => Future,
                            scope      => Scope,
                            at         => Now}),
            _ = Mesh:call(Caps:activate_permit(),
                          #{permit_id => PermitId, at => Now}),
            {N + 1, RngAcc1}
        end, {1, Rng0}, lists:seq(1, Preset#parksim_preset.permit_roster_size)),
    ok.

choose_scope(Rng, LotIds) ->
    {U, R1} = rand:uniform_s(Rng),
    case {U, LotIds} of
        {_, []}              -> {<<"city-wide">>, R1};
        {V, [Id | _]} when V < 0.80 ->
            {<<"single-lot:", Id/binary>>, R1};
        {V, [A, B | _]} when V < 0.95 ->
            {iolist_to_binary(["multi-lot:", A, ",", B]), R1};
        _ ->
            {<<"city-wide">>, R1}
    end.

synth_plate(N) ->
    Lead = ((N - 1) rem 9) + 1,
    L1 = $A + (((N - 1) div 9) rem 26),
    L2 = $A + (((N - 1) div 234) rem 26),
    L3 = $A + (((N - 1) div 6084) rem 26),
    Tail = ((N - 1) rem 900) + 100,
    iolist_to_binary(io_lib:format("~B-~c~c~c-~B",
                                   [Lead, L1, L2, L3, Tail])).

fire_renewal() ->
    %% Pick a synthetic permit id and renew. In a real impl we'd track
    %% the roster ids in state — fine for cadence-flavour traffic.
    Now = simulate_clock:now_iso8601(),
    Future = add_seconds(Now, 365 * 24 * 3600),
    _ = parksim_simulator_mesh:call(
        parksim_simulator_capabilities:renew_permit(),
        #{permit_id    => uuid_v4(),
          new_valid_to => Future,
          at           => Now}),
    ok.

%%--------------------------------------------------------------------
%% Helpers

default_tier_table() ->
    <<"[",
      "{\"from_minute\":0,\"to_minute\":30,\"cents_rate\":50},",
      "{\"from_minute\":30,\"to_minute\":120,\"cents_rate\":200},",
      "{\"from_minute\":120,\"to_minute\":720,\"cents_rate\":250},",
      "{\"from_minute\":720,\"to_minute\":-1,\"cents_rate\":120}",
      "]">>.

add_seconds(Iso8601Bin, AddSec) when is_binary(Iso8601Bin) ->
    %% Crude: assumes UTC RFC3339. The simulator's "at" is always UTC.
    Now = simulate_clock:now_iso8601(),
    case Iso8601Bin of
        Now -> shift_now(AddSec);
        _   -> shift_now(AddSec)   %% always anchored to now for demo
    end.

shift_now(AddSec) ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(
        erlang:system_time(second) + AddSec, second),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
        [Y, Mo, D, H, Mi, S])).

uuid_v4() ->
    <<A:32, B:16, C:16, D:16, E:48>> = crypto:strong_rand_bytes(16),
    C1 = (C band 16#0FFF) bor 16#4000,
    D1 = (D band 16#3FFF) bor 16#8000,
    iolist_to_binary(io_lib:format(
        "~8.16.0B-~4.16.0B-~4.16.0B-~4.16.0B-~12.16.0B",
        [A, B, C1, D1, E])).
