%%% @doc Command `drop_off_passenger_v1`. The vehicle reached the dropoff
%%% point; the passenger alights and the fare is settled. Produces two
%%% events: the drop-off (back to cruising) and the fare collection.
-module(drop_off_passenger_v1).
-behaviour(evoq_command).

-export([command_type/0]).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([stream_id/1]).
-export([get_vehicle_id/1, get_lat/1, get_lng/1, get_fare_cents/1,
         get_dropped_off_at/1]).

-record(drop_off_passenger_v1, {
    vehicle_id     :: binary() | undefined,
    lat            :: number() | undefined,
    lng            :: number() | undefined,
    fare_cents     :: non_neg_integer() | undefined,
    dropped_off_at :: binary() | undefined
}).

-opaque t() :: #drop_off_passenger_v1{}.
-export_type([t/0]).

command_type() -> drop_off_passenger_v1.

-spec new(map()) -> {ok, t()} | {error, term()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #drop_off_passenger_v1{
        vehicle_id     = Id,
        lat            = maps:get(lat, P, undefined),
        lng            = maps:get(lng, P, undefined),
        fare_cents     = maps:get(fare_cents, P, 0),
        dropped_off_at = maps:get(dropped_off_at, P, undefined)
    }};
new(_) -> {error, missing_aggregate_id}.

-spec from_map(map()) -> {ok, t()} | {error, term()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #drop_off_passenger_v1{
        vehicle_id     = Id,
        lat            = maps:get(<<"lat">>, M, undefined),
        lng            = maps:get(<<"lng">>, M, undefined),
        fare_cents     = maps:get(<<"fare_cents">>, M, 0),
        dropped_off_at = maps:get(<<"dropped_off_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #drop_off_passenger_v1{
        vehicle_id     = Id,
        lat            = maps:get(lat, M, undefined),
        lng            = maps:get(lng, M, undefined),
        fare_cents     = maps:get(fare_cents, M, 0),
        dropped_off_at = maps:get(dropped_off_at, M, undefined)
    }};
from_map(_) -> {error, missing_aggregate_id}.

-spec validate(t()) -> ok | {error, term()}.
validate(#drop_off_passenger_v1{vehicle_id = undefined}) -> {error, missing_aggregate_id};
validate(_) -> ok.

-spec to_map(t()) -> map().
to_map(#drop_off_passenger_v1{} = C) ->
    #{command_type   => <<"drop_off_passenger">>,
      vehicle_id     => C#drop_off_passenger_v1.vehicle_id,
      lat            => C#drop_off_passenger_v1.lat,
      lng            => C#drop_off_passenger_v1.lng,
      fare_cents     => C#drop_off_passenger_v1.fare_cents,
      dropped_off_at => C#drop_off_passenger_v1.dropped_off_at}.

-spec stream_id(t()) -> binary().
stream_id(#drop_off_passenger_v1{vehicle_id = Id}) -> <<"vehicle-", Id/binary>>.

get_vehicle_id(#drop_off_passenger_v1{vehicle_id = V})         -> V.
get_lat(#drop_off_passenger_v1{lat = V})                       -> V.
get_lng(#drop_off_passenger_v1{lng = V})                       -> V.
get_fare_cents(#drop_off_passenger_v1{fare_cents = V})         -> V.
get_dropped_off_at(#drop_off_passenger_v1{dropped_off_at = V}) -> V.
