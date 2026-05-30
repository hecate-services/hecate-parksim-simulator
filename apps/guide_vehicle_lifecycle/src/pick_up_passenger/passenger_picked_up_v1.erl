%%% @doc Event `passenger_picked_up_v1`. Passenger aboard; the trip and
%%% fare meter are running.
-module(passenger_picked_up_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_vehicle_id/1, get_lat/1, get_lng/1, get_picked_up_at/1]).

-record(passenger_picked_up_v1, {
    vehicle_id   :: binary() | undefined,
    lat          :: number() | undefined,
    lng          :: number() | undefined,
    picked_up_at :: binary() | undefined
}).

-opaque t() :: #passenger_picked_up_v1{}.
-export_type([t/0]).

event_type() -> passenger_picked_up_v1.

-spec new(map()) -> {ok, t()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #passenger_picked_up_v1{
        vehicle_id   = Id,
        lat          = maps:get(lat, P, undefined),
        lng          = maps:get(lng, P, undefined),
        picked_up_at = maps:get(picked_up_at, P, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #passenger_picked_up_v1{
        vehicle_id   = Id,
        lat          = maps:get(<<"lat">>, M, undefined),
        lng          = maps:get(<<"lng">>, M, undefined),
        picked_up_at = maps:get(<<"picked_up_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #passenger_picked_up_v1{
        vehicle_id   = Id,
        lat          = maps:get(lat, M, undefined),
        lng          = maps:get(lng, M, undefined),
        picked_up_at = maps:get(picked_up_at, M, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#passenger_picked_up_v1{} = E) ->
    #{event_type   => <<"passenger_picked_up">>,
      vehicle_id   => E#passenger_picked_up_v1.vehicle_id,
      lat          => E#passenger_picked_up_v1.lat,
      lng          => E#passenger_picked_up_v1.lng,
      picked_up_at => E#passenger_picked_up_v1.picked_up_at}.

get_vehicle_id(#passenger_picked_up_v1{vehicle_id = V})     -> V.
get_lat(#passenger_picked_up_v1{lat = V})                   -> V.
get_lng(#passenger_picked_up_v1{lng = V})                   -> V.
get_picked_up_at(#passenger_picked_up_v1{picked_up_at = V}) -> V.
