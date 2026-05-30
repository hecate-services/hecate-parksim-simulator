%%% @doc Real-time or scaled clock so the simulator can compress an
%%% N-hour day into one real hour for demos.
%%%
%%% Scale 1.0 = real time. Scale 60 = one simulated minute per real
%%% second. The clock is stateless and reads `parksim_simulator_config`
%%% lazily — caller pays for the env lookup but the simulator is not
%%% latency-sensitive.
-module(simulate_clock).

-export([now_iso8601/0, now_unix/0, sleep_simulated/1, scale/0]).

%% @doc Current wall-clock time as unix seconds. The fleet brain uses this
%% as its tick clock; it is real time (the sim compresses time via the
%% per-tick sim-seconds delta, not by warping this).
-spec now_unix() -> integer().
now_unix() ->
    erlang:system_time(second).

%% @doc Current UTC time as an ISO-8601 binary.
-spec now_iso8601() -> binary().
now_iso8601() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(
        erlang:system_time(second), second),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
        [Y, Mo, D, H, Mi, S])).

%% @doc Sleep for `SimulatedMs` of *simulated* time. Real wall-clock
%% sleep is SimulatedMs / scale, clamped to a minimum of 1 ms.
-spec sleep_simulated(non_neg_integer()) -> ok.
sleep_simulated(0)  -> ok;
sleep_simulated(Ms) when Ms > 0 ->
    Real = max(1, round(Ms / scale())),
    timer:sleep(Real).

-spec scale() -> float().
scale() ->
    case parksim_simulator_config:time_scale() of
        N when is_number(N), N > 0 -> float(N);
        _                          -> 1.0
    end.
