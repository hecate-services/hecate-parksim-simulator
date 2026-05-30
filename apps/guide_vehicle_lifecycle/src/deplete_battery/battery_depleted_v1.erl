%%% @doc Event `battery_depleted_v1`. The vehicle's battery hit zero; it is
%%% stranded at (lat,lng) awaiting a tow.
-module(battery_depleted_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_vehicle_id/1, get_lat/1, get_lng/1, get_depleted_at/1]).

-record(battery_depleted_v1, {
    vehicle_id  :: binary() | undefined,
    lat         :: number() | undefined,
    lng         :: number() | undefined,
    depleted_at :: binary() | undefined
}).

-opaque t() :: #battery_depleted_v1{}.
-export_type([t/0]).

event_type() -> battery_depleted_v1.

-spec new(map()) -> {ok, t()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #battery_depleted_v1{
        vehicle_id  = Id,
        lat         = maps:get(lat, P, undefined),
        lng         = maps:get(lng, P, undefined),
        depleted_at = maps:get(depleted_at, P, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #battery_depleted_v1{
        vehicle_id  = Id,
        lat         = maps:get(<<"lat">>, M, undefined),
        lng         = maps:get(<<"lng">>, M, undefined),
        depleted_at = maps:get(<<"depleted_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #battery_depleted_v1{
        vehicle_id  = Id,
        lat         = maps:get(lat, M, undefined),
        lng         = maps:get(lng, M, undefined),
        depleted_at = maps:get(depleted_at, M, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#battery_depleted_v1{} = E) ->
    #{event_type   => <<"battery_depleted">>,
      vehicle_id   => E#battery_depleted_v1.vehicle_id,
      lat          => E#battery_depleted_v1.lat,
      lng          => E#battery_depleted_v1.lng,
      depleted_at  => E#battery_depleted_v1.depleted_at}.

get_vehicle_id(#battery_depleted_v1{vehicle_id = V})   -> V.
get_lat(#battery_depleted_v1{lat = V})                 -> V.
get_lng(#battery_depleted_v1{lng = V})                 -> V.
get_depleted_at(#battery_depleted_v1{depleted_at = V}) -> V.
