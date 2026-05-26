%%% @doc Smoke tests for scenario presets.
-module(parksim_simulator_config_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

city_has_three_lots_test() ->
    application:set_env(hecate_parksim, shape, "city"),
    application:set_env(hecate_parksim, time_scale, 1.0),
    application:set_env(hecate_parksim, seed, 0),
    P = parksim_simulator_config:preset(),
    ?assertEqual(3, length(P#parksim_preset.lots)),
    ?assertEqual(<<"city">>, P#parksim_preset.name).

unknown_shape_falls_back_to_city_test() ->
    application:set_env(hecate_parksim, shape, "nope"),
    P = parksim_simulator_config:preset(),
    ?assertEqual(<<"city">>, P#parksim_preset.name).

demo_preset_test() ->
    application:set_env(hecate_parksim, shape, "demo"),
    P = parksim_simulator_config:preset(),
    ?assertEqual(1, length(P#parksim_preset.lots)).

stress_preset_test() ->
    application:set_env(hecate_parksim, shape, "stress"),
    P = parksim_simulator_config:preset(),
    ?assertEqual(6, length(P#parksim_preset.lots)).
