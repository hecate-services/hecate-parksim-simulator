%%% @doc Command `archive_parking_session_v1`. Books closed; vehicle
%%% has exited. Echoes `fee_cents` from state at archive time.
-module(archive_parking_session_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([stream_id/1]).
-export([get_session_id/1, get_reason/1, get_archived_at/1]).

-record(archive_parking_session_v1, {
    session_id  :: binary() | undefined,
    reason      :: binary() | undefined,
    archived_at :: binary() | undefined
}).

-opaque t() :: #archive_parking_session_v1{}.
-export_type([t/0]).

command_type() -> archive_parking_session_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{session_id := Id} = Params) ->
    {ok, #archive_parking_session_v1{
        session_id  = Id,
        reason      = maps:get(reason,      Params, undefined),
        archived_at = maps:get(archived_at, Params, undefined)
    }};
new(_) ->
    {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"session_id">> := Id} = Map) ->
    {ok, #archive_parking_session_v1{
        session_id  = Id,
        reason      = maps:get(<<"reason">>,      Map, undefined),
        archived_at = maps:get(<<"archived_at">>, Map, undefined)
    }};
from_map(#{session_id := Id} = Map) ->
    {ok, #archive_parking_session_v1{
        session_id  = Id,
        reason      = maps:get(reason,      Map, undefined),
        archived_at = maps:get(archived_at, Map, undefined)
    }};
from_map(_) ->
    {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#archive_parking_session_v1{session_id = undefined}) -> {error, missing_aggregate_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#archive_parking_session_v1{} = Cmd) ->
    #{
        command_type => <<"archive_parking_session">>,
        session_id   => Cmd#archive_parking_session_v1.session_id,
        reason       => Cmd#archive_parking_session_v1.reason,
        archived_at  => Cmd#archive_parking_session_v1.archived_at
    }.

-spec stream_id(t()) -> binary().
stream_id(#archive_parking_session_v1{session_id = Id}) ->
    <<"parking-session-", Id/binary>>.

get_session_id(#archive_parking_session_v1{session_id = V})   -> V.
get_reason(#archive_parking_session_v1{reason = V})           -> V.
get_archived_at(#archive_parking_session_v1{archived_at = V}) -> V.
