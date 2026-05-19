%%% @doc Smoke tests for the plate pool.
-module(parksim_simulator_plates_tests).

-include_lib("eunit/include/eunit.hrl").

new_pool_size_test() ->
    Rng = rand:seed_s(exsss, {1, 1, 1}),
    {Pool, _} = parksim_simulator_plates:new_pool(Rng, 500),
    ?assertEqual(500, length(Pool)).

plate_format_test() ->
    Rng = rand:seed_s(exsss, {2, 2, 2}),
    {Pool, _} = parksim_simulator_plates:new_pool(Rng, 100),
    lists:foreach(
        fun(#{value := V}) ->
            ?assertMatch({match, _}, re:run(V, "^[1-9]-[A-Z]{3}-[1-9][0-9]{2}$"))
        end, Pool).

regular_share_test() ->
    Rng = rand:seed_s(exsss, {3, 3, 3}),
    {Pool, _} = parksim_simulator_plates:new_pool(Rng, 2000),
    Regulars = length([P || #{regular := true} = P <- Pool]),
    Share = Regulars / length(Pool),
    ?assert(Share >= 0.14 andalso Share =< 0.26).

draw_returns_a_plate_test() ->
    Rng = rand:seed_s(exsss, {4, 4, 4}),
    {Pool, _} = parksim_simulator_plates:new_pool(Rng, 50),
    {Plate, _} = parksim_simulator_plates:draw(Rng, Pool),
    ?assert(is_map(Plate)),
    ?assert(is_binary(maps:get(value, Plate))).
