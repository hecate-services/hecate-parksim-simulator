%%% @doc Command `undock_vehicle_v1`. The vehicle released its bay.
-module(undock_vehicle_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([stream_id/1]).
-export([get_session_id/1, get_undocked_at/1]).

-record(undock_vehicle_v1, {
    session_id  :: binary() | undefined,
    undocked_at :: binary() | undefined
}).

-opaque t() :: #undock_vehicle_v1{}.
-export_type([t/0]).

command_type() -> undock_vehicle_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{session_id := Id} = Params) ->
    {ok, #undock_vehicle_v1{
        session_id  = Id,
        undocked_at = maps:get(undocked_at, Params, undefined)
    }};
new(_) ->
    {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"session_id">> := Id} = Map) ->
    {ok, #undock_vehicle_v1{
        session_id  = Id,
        undocked_at = maps:get(<<"undocked_at">>, Map, undefined)
    }};
from_map(#{session_id := Id} = Map) ->
    {ok, #undock_vehicle_v1{
        session_id  = Id,
        undocked_at = maps:get(undocked_at, Map, undefined)
    }};
from_map(_) ->
    {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#undock_vehicle_v1{session_id = undefined}) -> {error, missing_aggregate_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#undock_vehicle_v1{} = Cmd) ->
    #{
        command_type => <<"undock_vehicle">>,
        session_id   => Cmd#undock_vehicle_v1.session_id,
        undocked_at  => Cmd#undock_vehicle_v1.undocked_at
    }.

-spec stream_id(t()) -> binary().
stream_id(#undock_vehicle_v1{session_id = Id}) ->
    <<"parking-session-", Id/binary>>.

get_session_id(#undock_vehicle_v1{session_id = V})   -> V.
get_undocked_at(#undock_vehicle_v1{undocked_at = V}) -> V.
