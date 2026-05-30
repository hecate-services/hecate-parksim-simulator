%%% @doc Event `vehicle_dispatched_v1`. The vehicle was assigned a fare and
%%% is heading to the pickup point.
-module(vehicle_dispatched_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_vehicle_id/1, get_trip_id/1, get_pickup_lat/1, get_pickup_lng/1,
         get_dropoff_lat/1, get_dropoff_lng/1, get_dispatched_at/1]).

-record(vehicle_dispatched_v1, {
    vehicle_id    :: binary() | undefined,
    trip_id       :: binary() | undefined,
    pickup_lat    :: number() | undefined,
    pickup_lng    :: number() | undefined,
    dropoff_lat   :: number() | undefined,
    dropoff_lng   :: number() | undefined,
    dispatched_at :: binary() | undefined
}).

-opaque t() :: #vehicle_dispatched_v1{}.
-export_type([t/0]).

event_type() -> vehicle_dispatched_v1.

-spec new(map()) -> {ok, t()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #vehicle_dispatched_v1{
        vehicle_id    = Id,
        trip_id       = maps:get(trip_id, P, undefined),
        pickup_lat    = maps:get(pickup_lat, P, undefined),
        pickup_lng    = maps:get(pickup_lng, P, undefined),
        dropoff_lat   = maps:get(dropoff_lat, P, undefined),
        dropoff_lng   = maps:get(dropoff_lng, P, undefined),
        dispatched_at = maps:get(dispatched_at, P, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #vehicle_dispatched_v1{
        vehicle_id    = Id,
        trip_id       = maps:get(<<"trip_id">>, M, undefined),
        pickup_lat    = maps:get(<<"pickup_lat">>, M, undefined),
        pickup_lng    = maps:get(<<"pickup_lng">>, M, undefined),
        dropoff_lat   = maps:get(<<"dropoff_lat">>, M, undefined),
        dropoff_lng   = maps:get(<<"dropoff_lng">>, M, undefined),
        dispatched_at = maps:get(<<"dispatched_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #vehicle_dispatched_v1{
        vehicle_id    = Id,
        trip_id       = maps:get(trip_id, M, undefined),
        pickup_lat    = maps:get(pickup_lat, M, undefined),
        pickup_lng    = maps:get(pickup_lng, M, undefined),
        dropoff_lat   = maps:get(dropoff_lat, M, undefined),
        dropoff_lng   = maps:get(dropoff_lng, M, undefined),
        dispatched_at = maps:get(dispatched_at, M, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#vehicle_dispatched_v1{} = E) ->
    #{event_type    => <<"vehicle_dispatched">>,
      vehicle_id    => E#vehicle_dispatched_v1.vehicle_id,
      trip_id       => E#vehicle_dispatched_v1.trip_id,
      pickup_lat    => E#vehicle_dispatched_v1.pickup_lat,
      pickup_lng    => E#vehicle_dispatched_v1.pickup_lng,
      dropoff_lat   => E#vehicle_dispatched_v1.dropoff_lat,
      dropoff_lng   => E#vehicle_dispatched_v1.dropoff_lng,
      dispatched_at => E#vehicle_dispatched_v1.dispatched_at}.

get_vehicle_id(#vehicle_dispatched_v1{vehicle_id = V})       -> V.
get_trip_id(#vehicle_dispatched_v1{trip_id = V})             -> V.
get_pickup_lat(#vehicle_dispatched_v1{pickup_lat = V})       -> V.
get_pickup_lng(#vehicle_dispatched_v1{pickup_lng = V})       -> V.
get_dropoff_lat(#vehicle_dispatched_v1{dropoff_lat = V})     -> V.
get_dropoff_lng(#vehicle_dispatched_v1{dropoff_lng = V})     -> V.
get_dispatched_at(#vehicle_dispatched_v1{dispatched_at = V}) -> V.
