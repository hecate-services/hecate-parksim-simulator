%%% @doc Command `dock_vehicle_v1`. The vehicle parked in a bay.
-module(dock_vehicle_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([stream_id/1]).
-export([get_session_id/1, get_bay_id/1, get_docked_at/1]).

-record(dock_vehicle_v1, {
    session_id :: binary() | undefined,
    bay_id     :: binary() | undefined,
    docked_at  :: binary() | undefined
}).

-opaque t() :: #dock_vehicle_v1{}.
-export_type([t/0]).

command_type() -> dock_vehicle_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{session_id := Id} = Params) ->
    {ok, #dock_vehicle_v1{
        session_id = Id,
        bay_id     = maps:get(bay_id,    Params, undefined),
        docked_at  = maps:get(docked_at, Params, undefined)
    }};
new(_) ->
    {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"session_id">> := Id} = Map) ->
    {ok, #dock_vehicle_v1{
        session_id = Id,
        bay_id     = maps:get(<<"bay_id">>,    Map, undefined),
        docked_at  = maps:get(<<"docked_at">>, Map, undefined)
    }};
from_map(#{session_id := Id} = Map) ->
    {ok, #dock_vehicle_v1{
        session_id = Id,
        bay_id     = maps:get(bay_id,    Map, undefined),
        docked_at  = maps:get(docked_at, Map, undefined)
    }};
from_map(_) ->
    {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#dock_vehicle_v1{session_id = undefined}) -> {error, missing_aggregate_id};
validate(#dock_vehicle_v1{bay_id     = undefined}) -> {error, missing_bay_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#dock_vehicle_v1{} = Cmd) ->
    #{
        command_type => <<"dock_vehicle">>,
        session_id   => Cmd#dock_vehicle_v1.session_id,
        bay_id       => Cmd#dock_vehicle_v1.bay_id,
        docked_at    => Cmd#dock_vehicle_v1.docked_at
    }.

-spec stream_id(t()) -> binary().
stream_id(#dock_vehicle_v1{session_id = Id}) ->
    <<"parking-session-", Id/binary>>.

get_session_id(#dock_vehicle_v1{session_id = V}) -> V.
get_bay_id(#dock_vehicle_v1{bay_id = V})         -> V.
get_docked_at(#dock_vehicle_v1{docked_at = V})   -> V.
