%%% @doc Tests for the initiate_parking_session handler.
-module(maybe_initiate_parking_session_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("guide_parking_session_lifecycle/include/parking_session_state.hrl").

mk_cmd(Overrides) ->
    Base = #{<<"session_id">> => <<"sess-1">>,
             <<"lot_id">>     => <<"lot-1">>,
             <<"plate">>      => <<"1-ABC-123">>,
             <<"card_id">>    => <<"card-xyz">>,
             <<"entered_at">> => <<"2026-05-26T08:00:00Z">>},
    {ok, Cmd} = initiate_parking_session_v1:from_map(maps:merge(Base, Overrides)),
    Cmd.

empty_state()     -> parking_session_state:new(<<"sess-1">>).
initiated_state() ->
    parking_session_state:apply_event(empty_state(), #{
        event_type => <<"parking_session_initiated">>,
        session_id => <<"sess-1">>, lot_id => <<"lot-1">>,
        entered_at => <<"prior">>}).

happy_path_test() ->
    {ok, [Ev]} = maybe_initiate_parking_session:handle(mk_cmd(#{}), empty_state()),
    ?assertEqual(<<"sess-1">>,    parking_session_initiated_v1:get_session_id(Ev)),
    ?assertEqual(<<"lot-1">>,     parking_session_initiated_v1:get_lot_id(Ev)),
    ?assertEqual(<<"1-ABC-123">>, parking_session_initiated_v1:get_plate(Ev)).

handler_passes_through_entered_at_test() ->
    {ok, [Ev]} = maybe_initiate_parking_session:handle(mk_cmd(#{}), empty_state()),
    ?assertEqual(<<"2026-05-26T08:00:00Z">>,
                 parking_session_initiated_v1:get_entered_at(Ev)).

handler_defaults_entered_at_when_absent_test() ->
    Cmd = mk_cmd(#{<<"entered_at">> => undefined}),
    {ok, [Ev]} = maybe_initiate_parking_session:handle(Cmd, empty_state()),
    Ts = parking_session_initiated_v1:get_entered_at(Ev),
    ?assert(is_binary(Ts)),
    ?assert(byte_size(Ts) >= 20).

rejects_when_already_initiated_test() ->
    ?assertEqual({error, session_already_initiated},
                 maybe_initiate_parking_session:handle(mk_cmd(#{}), initiated_state())).

rejects_missing_lot_id_test() ->
    Cmd = mk_cmd(#{<<"lot_id">> => undefined}),
    ?assertEqual({error, missing_lot_id},
                 maybe_initiate_parking_session:handle(Cmd, empty_state())).

state_after_apply_round_trip_test() ->
    {ok, [Ev]} = maybe_initiate_parking_session:handle(mk_cmd(#{}), empty_state()),
    EvMap = parking_session_initiated_v1:to_map(Ev),
    S = parking_session_state:apply_event(empty_state(), EvMap),
    ?assert(parking_session_state:is_initiated(S)),
    ?assertEqual(<<"lot-1">>, parking_session_state:lot_id(S)).
