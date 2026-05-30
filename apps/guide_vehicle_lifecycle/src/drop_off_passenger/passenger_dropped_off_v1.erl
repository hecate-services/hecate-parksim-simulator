%%% @doc Event `passenger_dropped_off_v1`. Trip complete; the vehicle
%%% returns to the cruising pool.
-module(passenger_dropped_off_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_vehicle_id/1, get_lat/1, get_lng/1, get_dropped_off_at/1]).

-record(passenger_dropped_off_v1, {
    vehicle_id     :: binary() | undefined,
    lat            :: number() | undefined,
    lng            :: number() | undefined,
    dropped_off_at :: binary() | undefined
}).

-opaque t() :: #passenger_dropped_off_v1{}.
-export_type([t/0]).

event_type() -> passenger_dropped_off_v1.

-spec new(map()) -> {ok, t()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #passenger_dropped_off_v1{
        vehicle_id     = Id,
        lat            = maps:get(lat, P, undefined),
        lng            = maps:get(lng, P, undefined),
        dropped_off_at = maps:get(dropped_off_at, P, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #passenger_dropped_off_v1{
        vehicle_id     = Id,
        lat            = maps:get(<<"lat">>, M, undefined),
        lng            = maps:get(<<"lng">>, M, undefined),
        dropped_off_at = maps:get(<<"dropped_off_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #passenger_dropped_off_v1{
        vehicle_id     = Id,
        lat            = maps:get(lat, M, undefined),
        lng            = maps:get(lng, M, undefined),
        dropped_off_at = maps:get(dropped_off_at, M, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#passenger_dropped_off_v1{} = E) ->
    #{event_type     => <<"passenger_dropped_off">>,
      vehicle_id     => E#passenger_dropped_off_v1.vehicle_id,
      lat            => E#passenger_dropped_off_v1.lat,
      lng            => E#passenger_dropped_off_v1.lng,
      dropped_off_at => E#passenger_dropped_off_v1.dropped_off_at}.

get_vehicle_id(#passenger_dropped_off_v1{vehicle_id = V})         -> V.
get_lat(#passenger_dropped_off_v1{lat = V})                       -> V.
get_lng(#passenger_dropped_off_v1{lng = V})                       -> V.
get_dropped_off_at(#passenger_dropped_off_v1{dropped_off_at = V}) -> V.
