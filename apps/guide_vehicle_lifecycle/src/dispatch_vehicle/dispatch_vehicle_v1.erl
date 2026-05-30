%%% @doc Command `dispatch_vehicle_v1`. Assign an available vehicle a fare
%%% (pickup -> dropoff). The vehicle heads to the pickup point.
-module(dispatch_vehicle_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([stream_id/1]).
-export([get_vehicle_id/1, get_trip_id/1, get_pickup_lat/1, get_pickup_lng/1,
         get_dropoff_lat/1, get_dropoff_lng/1, get_dispatched_at/1]).

-record(dispatch_vehicle_v1, {
    vehicle_id    :: binary() | undefined,
    trip_id       :: binary() | undefined,
    pickup_lat    :: number() | undefined,
    pickup_lng    :: number() | undefined,
    dropoff_lat   :: number() | undefined,
    dropoff_lng   :: number() | undefined,
    dispatched_at :: binary() | undefined
}).

-opaque t() :: #dispatch_vehicle_v1{}.
-export_type([t/0]).

command_type() -> dispatch_vehicle_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #dispatch_vehicle_v1{
        vehicle_id    = Id,
        trip_id       = maps:get(trip_id, P, undefined),
        pickup_lat    = maps:get(pickup_lat, P, undefined),
        pickup_lng    = maps:get(pickup_lng, P, undefined),
        dropoff_lat   = maps:get(dropoff_lat, P, undefined),
        dropoff_lng   = maps:get(dropoff_lng, P, undefined),
        dispatched_at = maps:get(dispatched_at, P, undefined)
    }};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #dispatch_vehicle_v1{
        vehicle_id    = Id,
        trip_id       = maps:get(<<"trip_id">>, M, undefined),
        pickup_lat    = maps:get(<<"pickup_lat">>, M, undefined),
        pickup_lng    = maps:get(<<"pickup_lng">>, M, undefined),
        dropoff_lat   = maps:get(<<"dropoff_lat">>, M, undefined),
        dropoff_lng   = maps:get(<<"dropoff_lng">>, M, undefined),
        dispatched_at = maps:get(<<"dispatched_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #dispatch_vehicle_v1{
        vehicle_id    = Id,
        trip_id       = maps:get(trip_id, M, undefined),
        pickup_lat    = maps:get(pickup_lat, M, undefined),
        pickup_lng    = maps:get(pickup_lng, M, undefined),
        dropoff_lat   = maps:get(dropoff_lat, M, undefined),
        dropoff_lng   = maps:get(dropoff_lng, M, undefined),
        dispatched_at = maps:get(dispatched_at, M, undefined)
    }};
from_map(_) -> {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#dispatch_vehicle_v1{vehicle_id = undefined})  -> {error, missing_aggregate_id};
validate(#dispatch_vehicle_v1{trip_id = undefined})     -> {error, missing_trip_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#dispatch_vehicle_v1{} = C) ->
    #{command_type  => <<"dispatch_vehicle">>,
      vehicle_id    => C#dispatch_vehicle_v1.vehicle_id,
      trip_id       => C#dispatch_vehicle_v1.trip_id,
      pickup_lat    => C#dispatch_vehicle_v1.pickup_lat,
      pickup_lng    => C#dispatch_vehicle_v1.pickup_lng,
      dropoff_lat   => C#dispatch_vehicle_v1.dropoff_lat,
      dropoff_lng   => C#dispatch_vehicle_v1.dropoff_lng,
      dispatched_at => C#dispatch_vehicle_v1.dispatched_at}.

-spec stream_id(t()) -> binary().
stream_id(#dispatch_vehicle_v1{vehicle_id = Id}) -> <<"vehicle-", Id/binary>>.

get_vehicle_id(#dispatch_vehicle_v1{vehicle_id = V})       -> V.
get_trip_id(#dispatch_vehicle_v1{trip_id = V})             -> V.
get_pickup_lat(#dispatch_vehicle_v1{pickup_lat = V})       -> V.
get_pickup_lng(#dispatch_vehicle_v1{pickup_lng = V})       -> V.
get_dropoff_lat(#dispatch_vehicle_v1{dropoff_lat = V})     -> V.
get_dropoff_lng(#dispatch_vehicle_v1{dropoff_lng = V})     -> V.
get_dispatched_at(#dispatch_vehicle_v1{dispatched_at = V}) -> V.
