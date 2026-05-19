%%% @doc Per-lot cadence: sweeps every 2h, sensor calibration nightly,
%%% weekly maintenance window, optional once-per-run evacuation drill.
%%% Also exposes `boot/0` which opens every lot once at start.
-module(simulate_lots).
-behaviour(gen_server).

-export([start_link/2, evacuate/1, boot/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

-record(state, {
    lot      :: #parksim_lot{},
    rng      :: rand:state(),
    last_swept   = 0 :: non_neg_integer(),  %% sim seconds since epoch
    last_calib   = 0 :: non_neg_integer(),
    last_maint   = 0 :: non_neg_integer(),
    evac_fired = false :: boolean(),
    started_at :: non_neg_integer()
}).

%% --- API ------------------------------------------------------------

start_link(Name, Lot) ->
    gen_server:start_link({local, Name}, ?MODULE, [Lot], []).

evacuate(LotId) ->
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    Mesh:call(Caps:evacuate_lot(),
              #{lot_id => LotId,
                reason => <<"operator-drill">>,
                at     => simulate_clock:now_iso8601()}).

%% Open every lot, set capacity, assign a small zone map. Idempotent.
boot() ->
    Preset = parksim_simulator_config:preset(),
    Now = simulate_clock:now_iso8601(),
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    lists:foreach(
        fun(#parksim_lot{id = LotId, display_name = Name, capacity = Cap}) ->
            _ = Mesh:call(Caps:open_lot(),
                          #{lot_id   => LotId,
                            name     => Name,
                            capacity => Cap,
                            zone_map => <<"{}">>,
                            at       => Now}),
            _ = Mesh:call(Caps:set_capacity(),
                          #{lot_id   => LotId,
                            level    => <<"all">>,
                            capacity => Cap,
                            at       => Now}),
            lists:foreach(
                fun(Purpose) ->
                    _ = Mesh:call(Caps:assign_zone_purpose(),
                                  #{lot_id  => LotId,
                                    zone_id => <<"A-", Purpose/binary>>,
                                    purpose => Purpose,
                                    at      => Now})
                end,
                [<<"visitor">>, <<"ev_charging">>, <<"disabled">>])
        end,
        Preset#parksim_preset.lots).

%% --- gen_server -----------------------------------------------------

init([Lot]) ->
    Seed = parksim_simulator_config:seed() + erlang:phash2(Lot#parksim_lot.id),
    Rng  = rand:seed_s(exsss, {Seed, Seed, Seed}),
    Now  = erlang:system_time(second),
    State = #state{lot = Lot, rng = Rng, started_at = Now},
    schedule_tick(),
    {ok, State}.

handle_call(_Msg, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State)         -> {noreply, State}.

handle_info(tick, State) ->
    NewState = maybe_fire(State),
    schedule_tick(),
    {noreply, NewState};
handle_info(_Other, State) ->
    {noreply, State}.

terminate(_Reason, _State) -> ok.

%% --- internals ------------------------------------------------------

schedule_tick() ->
    %% Wake every 30 simulated seconds (real-time scaled). The maybe_fire
    %% function decides whether any cadence event should fire this tick.
    erlang:send_after(round(30 * 1000 / simulate_clock:scale()), self(), tick).

maybe_fire(State) ->
    State1 = maybe_sweep(State),
    State2 = maybe_calibrate(State1),
    State3 = maybe_maintenance(State2),
    maybe_evacuation(State3).

%% Sweep every 2 simulated hours.
maybe_sweep(#state{last_swept = Last} = State) ->
    Now = erlang:system_time(second),
    case (Now - Last) >= 2 * 3600 div 1 of    %% 2h in seconds
        false -> State;
        true ->
            {Attendant, R1} = pick_attendant(State#state.rng),
            _ = parksim_simulator_mesh:call(
                parksim_simulator_capabilities:record_sweep(),
                #{lot_id    => (State#state.lot)#parksim_lot.id,
                  attendant => Attendant,
                  anomalies => <<"[]">>,
                  at        => simulate_clock:now_iso8601()}),
            State#state{last_swept = Now, rng = R1}
    end.

%% Calibration once per simulated day.
maybe_calibrate(#state{last_calib = Last} = State) ->
    Now = erlang:system_time(second),
    case (Now - Last) >= 24 * 3600 of
        false -> State;
        true ->
            _ = parksim_simulator_mesh:call(
                parksim_simulator_capabilities:record_sensor_calibration(),
                #{lot_id             => (State#state.lot)#parksim_lot.id,
                  sensor_id          => <<"lot-sensor-array">>,
                  calibration_result => <<"ok">>,
                  at                 => simulate_clock:now_iso8601()}),
            State#state{last_calib = Now}
    end.

%% Maintenance window once per simulated week.
maybe_maintenance(#state{last_maint = Last} = State) ->
    Now = erlang:system_time(second),
    case (Now - Last) >= 7 * 24 * 3600 of
        false -> State;
        true ->
            WindowId = uuid_v4(),
            _ = parksim_simulator_mesh:call(
                parksim_simulator_capabilities:start_maintenance_window(),
                #{lot_id    => (State#state.lot)#parksim_lot.id,
                  window_id => WindowId,
                  reason    => <<"weekly-inspection">>,
                  at        => simulate_clock:now_iso8601()}),
            schedule_window_close(WindowId, (State#state.lot)#parksim_lot.id),
            State#state{last_maint = Now}
    end.

schedule_window_close(WindowId, LotId) ->
    spawn(fun() ->
        simulate_clock:sleep_simulated(4 * 3600 * 1000),    %% 4h sim
        _ = parksim_simulator_mesh:call(
            parksim_simulator_capabilities:end_maintenance_window(),
            #{lot_id    => LotId,
              window_id => WindowId,
              at        => simulate_clock:now_iso8601()}),
        ok
    end).

%% Evacuation drill once at sim-hour 4 of the run, if configured.
maybe_evacuation(#state{evac_fired = true} = State) -> State;
maybe_evacuation(#state{started_at = Start} = State) ->
    case parksim_simulator_config:include_evacuation()
         andalso (erlang:system_time(second) - Start) >= 4 * 3600 of
        false -> State;
        true ->
            LotId = (State#state.lot)#parksim_lot.id,
            _ = parksim_simulator_mesh:call(
                parksim_simulator_capabilities:evacuate_lot(),
                #{lot_id => LotId, reason => <<"fire-drill">>,
                  at     => simulate_clock:now_iso8601()}),
            spawn(fun() ->
                simulate_clock:sleep_simulated(20 * 60 * 1000),
                _ = parksim_simulator_mesh:call(
                    parksim_simulator_capabilities:restore_lot(),
                    #{lot_id => LotId, at => simulate_clock:now_iso8601()})
            end),
            State#state{evac_fired = true}
    end.

pick_attendant(Rng) ->
    Pool = [<<"alice">>, <<"bob">>, <<"carla">>, <<"dimitri">>],
    {I, R1} = rand:uniform_s(length(Pool), Rng),
    {lists:nth(I, Pool), R1}.

uuid_v4() ->
    <<A:32, B:16, C:16, D:16, E:48>> = crypto:strong_rand_bytes(16),
    C1 = (C band 16#0FFF) bor 16#4000,
    D1 = (D band 16#3FFF) bor 16#8000,
    iolist_to_binary(io_lib:format(
        "~8.16.0B-~4.16.0B-~4.16.0B-~4.16.0B-~12.16.0B",
        [A, B, C1, D1, E])).
