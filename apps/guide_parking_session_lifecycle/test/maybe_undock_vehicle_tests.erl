%%% @doc Tests for the undock_vehicle handler.
-module(maybe_undock_vehicle_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_parking_session_lifecycle/include/parking_session_state.hrl").

mk_cmd(Overrides) ->
    Base = #{<<"session_id">>  => <<"sess-1">>,
             <<"undocked_at">> => <<"2026-05-29T11:30:00Z">>},
    {ok, Cmd} = undock_vehicle_v1:from_map(maps:merge(Base, Overrides)),
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
undocked()  ->
    parking_session_state:apply_event(docked(), #{
        event_type => <<"vehicle_undocked">>,
        session_id => <<"sess-1">>, undocked_at => <<"t">>}).

happy_path_test() ->
    {ok, [Ev]} = maybe_undock_vehicle:handle(mk_cmd(#{}), docked()),
    ?assertEqual(<<"sess-1">>, vehicle_undocked_v1:get_session_id(Ev)),
    ?assertEqual(<<"2026-05-29T11:30:00Z">>, vehicle_undocked_v1:get_undocked_at(Ev)).

rejects_when_not_docked_test() ->
    ?assertEqual({error, vehicle_not_docked},
                 maybe_undock_vehicle:handle(mk_cmd(#{}), initiated())).

rejects_when_already_undocked_test() ->
    ?assertEqual({error, vehicle_already_undocked},
                 maybe_undock_vehicle:handle(mk_cmd(#{}), undocked())).

defaults_undocked_at_when_absent_test() ->
    Cmd = mk_cmd(#{<<"undocked_at">> => undefined}),
    {ok, [Ev]} = maybe_undock_vehicle:handle(Cmd, docked()),
    Ts = vehicle_undocked_v1:get_undocked_at(Ev),
    ?assert(is_binary(Ts)),
    ?assert(byte_size(Ts) >= 20).

state_folds_undocked_flag_test() ->
    S = undocked(),
    ?assert(parking_session_state:is_docked(S)),
    ?assert(parking_session_state:is_undocked(S)).
