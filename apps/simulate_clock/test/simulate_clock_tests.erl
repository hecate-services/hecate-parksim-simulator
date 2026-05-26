-module(simulate_clock_tests).

-include_lib("eunit/include/eunit.hrl").

now_iso8601_format_test() ->
    Bin = simulate_clock:now_iso8601(),
    ?assertMatch({match, _},
                 re:run(Bin, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")).

scale_defaults_to_1_test() ->
    application:set_env(hecate_parksim, time_scale, 1.0),
    ?assertEqual(1.0, simulate_clock:scale()).

scaled_sleep_is_fast_test() ->
    %% Simulated 10s with scale 1000 -> real ~10ms.
    application:set_env(hecate_parksim, time_scale, 1000.0),
    T0 = erlang:monotonic_time(millisecond),
    simulate_clock:sleep_simulated(10_000),
    Elapsed = erlang:monotonic_time(millisecond) - T0,
    ?assert(Elapsed < 200, lists:flatten(io_lib:format("scaled sleep took ~p ms", [Elapsed]))).
