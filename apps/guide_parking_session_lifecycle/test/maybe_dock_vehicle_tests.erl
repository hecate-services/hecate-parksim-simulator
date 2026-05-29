%%% @doc Tests for the dock_vehicle handler.
-module(maybe_dock_vehicle_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_parking_session_lifecycle/include/parking_session_state.hrl").

mk_cmd(Overrides) ->
    Base = #{<<"session_id">> => <<"sess-1">>,
             <<"bay_id">>     => <<"lot-x-bay-7">>,
             <<"docked_at">>  => <<"2026-05-29T10:00:00Z">>},
    {ok, Cmd} = dock_vehicle_v1:from_map(maps:merge(Base, Overrides)),
    Cmd.

empty()     -> parking_session_state:new(<<"sess-1">>).
initiated() ->
    parking_session_state:apply_event(empty(), #{
        event_type => <<"parking_session_initiated">>,
        session_id => <<"sess-1">>, lot_id => <<"l">>, entered_at => <<"t">>}).
docked()    ->
    parking_session_state:apply_event(initiated(), #{
        event_type => <<"vehicle_docked">>,
        session_id => <<"sess-1">>, bay_id => <<"lot-x-bay-7">>, docked_at => <<"t">>}).

happy_path_test() ->
    {ok, [Ev]} = maybe_dock_vehicle:handle(mk_cmd(#{}), initiated()),
    ?assertEqual(<<"sess-1">>,      vehicle_docked_v1:get_session_id(Ev)),
    ?assertEqual(<<"lot-x-bay-7">>, vehicle_docked_v1:get_bay_id(Ev)),
    ?assertEqual(<<"2026-05-29T10:00:00Z">>, vehicle_docked_v1:get_docked_at(Ev)).

rejects_when_not_initiated_test() ->
    ?assertEqual({error, session_not_initiated},
                 maybe_dock_vehicle:handle(mk_cmd(#{}), empty())).

rejects_when_already_docked_test() ->
    ?assertEqual({error, vehicle_already_docked},
                 maybe_dock_vehicle:handle(mk_cmd(#{}), docked())).

rejects_missing_bay_id_test() ->
    Cmd = mk_cmd(#{<<"bay_id">> => undefined}),
    ?assertEqual({error, missing_bay_id},
                 maybe_dock_vehicle:handle(Cmd, initiated())).

defaults_docked_at_when_absent_test() ->
    Cmd = mk_cmd(#{<<"docked_at">> => undefined}),
    {ok, [Ev]} = maybe_dock_vehicle:handle(Cmd, initiated()),
    Ts = vehicle_docked_v1:get_docked_at(Ev),
    ?assert(is_binary(Ts)),
    ?assert(byte_size(Ts) >= 20).

state_folds_docked_flag_and_bay_test() ->
    S = docked(),
    ?assert(parking_session_state:is_docked(S)),
    ?assertEqual(<<"lot-x-bay-7">>, parking_session_state:bay_id(S)).
