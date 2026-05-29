%%% @doc Tests for the retention sweep's pure helpers.
-module(retain_parking_sessions_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("reckon_gater/include/reckon_gater_types.hrl").

%% Build a stored #event{} the way reckon-db hands them back: type in
%% the envelope, business fields in `data` (without the type key).
ev(Type, Version, Data) ->
    #event{event_type = Type, version = Version, data = Data}.

ticket_lifecycle() ->
    [ ev(<<"parking_session_initiated">>, 0, #{lot_id => <<"lot-x">>, plate => <<"1-AAA-1">>}),
      ev(<<"vehicle_docked">>,            1, #{bay_id => <<"lot-x-bay-3">>}),
      ev(<<"payment_captured">>,          2, #{amount_cents => 500}),
      ev(<<"vehicle_undocked">>,          3, #{}),
      ev(<<"parking_session_archived">>,  4, #{reason => undefined}) ].

is_session_stream_test() ->
    ?assert(retain_parking_sessions:is_session_stream(<<"sess-019e7255abcd">>)),
    ?assertNot(retain_parking_sessions:is_session_stream(<<"evoq_all_parksim_leuven_store">>)),
    ?assertNot(retain_parking_sessions:is_session_stream(<<"$all">>)).

fold_detects_archived_test() ->
    S = retain_parking_sessions:fold_state(<<"sess-1">>, ticket_lifecycle()),
    ?assert(parking_session_state:is_archived(S)),
    ?assert(parking_session_state:is_paid(S)),
    ?assert(parking_session_state:is_docked(S)),
    ?assert(parking_session_state:is_undocked(S)),
    ?assertEqual(<<"lot-x-bay-3">>, parking_session_state:bay_id(S)).

fold_in_progress_not_archived_test() ->
    InProgress = lists:sublist(ticket_lifecycle(), 2),  %% initiated + docked only
    S = retain_parking_sessions:fold_state(<<"sess-2">>, InProgress),
    ?assert(parking_session_state:is_docked(S)),
    ?assertNot(parking_session_state:is_archived(S)).

%% A permit session settles at entry (permit_ref on the birth slip) and
%% archives without a payment event — must still fold to archived.
fold_permit_archived_test() ->
    Permit = [ ev(<<"parking_session_initiated">>, 0, #{lot_id => <<"lot-x">>, permit_ref => <<"permit-9">>}),
               ev(<<"vehicle_docked">>,            1, #{bay_id => <<"lot-x-bay-1">>}),
               ev(<<"vehicle_undocked">>,          2, #{}),
               ev(<<"parking_session_archived">>,  3, #{reason => <<"permit">>}) ],
    S = retain_parking_sessions:fold_state(<<"sess-3">>, Permit),
    ?assert(parking_session_state:is_archived(S)),
    ?assertNot(parking_session_state:is_paid(S)),
    ?assert(parking_session_state:is_permit_covered(S)).
