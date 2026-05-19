%%% @doc Spawns and runs per-vehicle session processes. Each session
%%% fires the full command ladder (enter -> dwell -> trigger_exit ->
%%% payment -> record_exit) as scaled-time-sleeps between mesh calls.
%%%
%%% See PLAN_PARKSIM_TRAFFIC_MODEL.md §4.
-module(simulate_sessions).

-export([start_session/1]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

%% --- public ---------------------------------------------------------

%% @doc Spawn one session process. Returns {ok, Pid}.
-spec start_session(map()) -> {ok, pid()}.
start_session(Params) ->
    Pid = proc_lib:spawn(fun() -> run(Params) end),
    {ok, Pid}.

%% --- session ladder -------------------------------------------------

run(#{lot := Lot, plate := PlateMap} = _Params) ->
    Rng = rand:seed_s(exsss, {erlang:phash2(self()),
                              erlang:phash2(make_ref()),
                              erlang:system_time(microsecond)}),
    SessionId = uuid_v4(),
    PlateValue = maps:get(value, PlateMap),
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    EnteredAt = simulate_clock:now_iso8601(),
    _ = Mesh:call(Caps:enter_vehicle(),
                  #{session_id => SessionId,
                    lot_id     => Lot#parksim_lot.id,
                    plate      => PlateValue,
                    entered_at => EnteredAt}),
    Dwell = sample_dwell(Rng, Lot),
    simulate_clock:sleep_simulated(Dwell * 1000),
    {Outcome, Rng1} = sample_outcome(Rng),
    handle_outcome(Outcome, SessionId, Lot, Rng1).

%% Branch on payment outcome.
handle_outcome(abandoned,         _SId, _Lot, _Rng) -> ok;
handle_outcome(force_settled,     _SId, _Lot, _Rng) -> ok;
handle_outcome(terminal_anomaly,  _SId, _Lot, _Rng) -> ok;
handle_outcome(Outcome, SessionId, Lot, Rng) ->
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    _ = Mesh:call(Caps:trigger_exit(),
                  #{session_id   => SessionId,
                    exit_gate_id => <<"gate-", (Lot#parksim_lot.id)/binary>>,
                    triggered_at => simulate_clock:now_iso8601()}),
    {DeltaP, R1} = uniform_int_s(Rng, 2, 90),
    simulate_clock:sleep_simulated(DeltaP * 1000),
    AttemptId = uuid_v4(),
    Amount    = 250,
    _ = Mesh:call(Caps:attempt_payment(),
                  #{session_id => SessionId,
                    attempt_id => AttemptId,
                    amount     => Amount,
                    method     => <<"card">>,
                    at         => simulate_clock:now_iso8601()}),
    {R, R2} = exp_seconds_s(R1, 3.0),
    simulate_clock:sleep_simulated(round(R * 1000)),
    R3 = finalise_payment(Outcome, SessionId, AttemptId, Amount, R2),
    {DeltaR, _R4} = uniform_int_s(R3, 1, 30),
    simulate_clock:sleep_simulated(DeltaR * 1000),
    _ = Mesh:call(Caps:record_exit(),
                  #{session_id => SessionId,
                    exited_at  => simulate_clock:now_iso8601()}),
    ok.

finalise_payment(retried_then_captured, SId, AttemptId, Amount, Rng) ->
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    _ = Mesh:call(Caps:mark_payment_failed(),
                  #{session_id => SId,
                    attempt_id => AttemptId,
                    reason     => <<"transient_decline">>,
                    failed_at  => simulate_clock:now_iso8601()}),
    {Pause, Rng1} = uniform_int_s(Rng, 3, 10),
    simulate_clock:sleep_simulated(Pause * 1000),
    AttemptId2 = uuid_v4(),
    _ = Mesh:call(Caps:attempt_payment(),
                  #{session_id => SId,
                    attempt_id => AttemptId2,
                    amount     => Amount,
                    method     => <<"card">>,
                    at         => simulate_clock:now_iso8601()}),
    _ = Mesh:call(Caps:mark_payment_captured(),
                  #{session_id  => SId,
                    attempt_id  => AttemptId2,
                    amount      => Amount,
                    captured_at => simulate_clock:now_iso8601()}),
    Rng1;
finalise_payment(overstayed, SId, AttemptId, _Amount, Rng) ->
    _ = parksim_simulator_mesh:call(
        parksim_simulator_capabilities:mark_payment_failed(),
        #{session_id => SId,
          attempt_id => AttemptId,
          reason     => <<"driver_gave_up">>,
          failed_at  => simulate_clock:now_iso8601()}),
    Rng;
finalise_payment(_Other, SId, AttemptId, Amount, Rng) ->
    _ = parksim_simulator_mesh:call(
        parksim_simulator_capabilities:mark_payment_captured(),
        #{session_id  => SId,
          attempt_id  => AttemptId,
          amount      => Amount,
          captured_at => simulate_clock:now_iso8601()}),
    Rng.

%%--------------------------------------------------------------------
%% Distributions

%% LogNormal(mu, sigma) clipped to [60, MaxDwell] seconds.
sample_dwell(Rng, #parksim_lot{dwell_mu = Mu, dwell_sigma = Sigma}) ->
    {Z, _Rng1} = rand:normal_s(Rng),
    X = math:exp(Mu + Sigma * Z),
    max(60, min(round(X), 24 * 3600)).

%% Categorical draw matching §4.1.
sample_outcome(Rng) ->
    {U, R1} = rand:uniform_s(Rng),
    Outcome = pick_outcome(U),
    {Outcome, R1}.

pick_outcome(U) when U =< 0.920 -> captured_first_try;
pick_outcome(U) when U =< 0.980 -> retried_then_captured;
pick_outcome(U) when U =< 0.990 -> overstayed;
pick_outcome(U) when U =< 0.993 -> abandoned;
pick_outcome(U) when U =< 0.995 -> force_settled;
pick_outcome(_U)                -> terminal_anomaly.

uniform_int_s(Rng, Lo, Hi) when Hi >= Lo ->
    {U, Rng1} = rand:uniform_s(Hi - Lo + 1, Rng),
    {Lo + U - 1, Rng1}.

exp_seconds_s(Rng, MeanSec) ->
    {U, Rng1} = rand:uniform_s(Rng),
    {-math:log(max(U, 1.0e-12)) * MeanSec, Rng1}.

%%--------------------------------------------------------------------
%% UUID v4 (text form)

uuid_v4() ->
    <<A:32, B:16, C:16, D:16, E:48>> = crypto:strong_rand_bytes(16),
    %% Set the version (4) and variant bits.
    C1 = (C band 16#0FFF) bor 16#4000,
    D1 = (D band 16#3FFF) bor 16#8000,
    iolist_to_binary(io_lib:format(
        "~8.16.0B-~4.16.0B-~4.16.0B-~4.16.0B-~12.16.0B",
        [A, B, C1, D1, E])).
