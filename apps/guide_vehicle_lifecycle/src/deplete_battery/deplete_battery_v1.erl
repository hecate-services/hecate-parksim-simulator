%%% @doc Command `deplete_battery_v1`. The vehicle ran flat mid-leg and is
%%% stranded where it stopped. The fleet brain then arranges a tow (which
%%% ends in a dock -> service -> release).
-module(deplete_battery_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([stream_id/1]).
-export([get_vehicle_id/1, get_lat/1, get_lng/1, get_depleted_at/1]).

-record(deplete_battery_v1, {
    vehicle_id  :: binary() | undefined,
    lat         :: number() | undefined,
    lng         :: number() | undefined,
    depleted_at :: binary() | undefined
}).

-opaque t() :: #deplete_battery_v1{}.
-export_type([t/0]).

command_type() -> deplete_battery_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #deplete_battery_v1{
        vehicle_id  = Id,
        lat         = maps:get(lat, P, undefined),
        lng         = maps:get(lng, P, undefined),
        depleted_at = maps:get(depleted_at, P, undefined)
    }};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #deplete_battery_v1{
        vehicle_id  = Id,
        lat         = maps:get(<<"lat">>, M, undefined),
        lng         = maps:get(<<"lng">>, M, undefined),
        depleted_at = maps:get(<<"depleted_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #deplete_battery_v1{
        vehicle_id  = Id,
        lat         = maps:get(lat, M, undefined),
        lng         = maps:get(lng, M, undefined),
        depleted_at = maps:get(depleted_at, M, undefined)
    }};
from_map(_) -> {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#deplete_battery_v1{vehicle_id = undefined}) -> {error, missing_aggregate_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#deplete_battery_v1{} = C) ->
    #{command_type => <<"deplete_battery">>,
      vehicle_id   => C#deplete_battery_v1.vehicle_id,
      lat          => C#deplete_battery_v1.lat,
      lng          => C#deplete_battery_v1.lng,
      depleted_at  => C#deplete_battery_v1.depleted_at}.

-spec stream_id(t()) -> binary().
stream_id(#deplete_battery_v1{vehicle_id = Id}) -> <<"vehicle-", Id/binary>>.

get_vehicle_id(#deplete_battery_v1{vehicle_id = V})   -> V.
get_lat(#deplete_battery_v1{lat = V})                 -> V.
get_lng(#deplete_battery_v1{lng = V})                 -> V.
get_depleted_at(#deplete_battery_v1{depleted_at = V}) -> V.
