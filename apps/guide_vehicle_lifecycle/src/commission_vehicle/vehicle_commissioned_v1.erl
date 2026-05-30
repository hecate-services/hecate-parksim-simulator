%%% @doc Event `vehicle_commissioned_v1`. A robotaxi joined the fleet;
%%% vehicle dossier born.
-module(vehicle_commissioned_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_vehicle_id/1, get_company_id/1, get_battery_pct/1,
         get_lat/1, get_lng/1, get_commissioned_at/1]).

-record(vehicle_commissioned_v1, {
    vehicle_id      :: binary() | undefined,
    company_id      :: binary() | undefined,
    battery_pct     :: number() | undefined,
    lat             :: number() | undefined,
    lng             :: number() | undefined,
    commissioned_at :: binary() | undefined
}).

-opaque t() :: #vehicle_commissioned_v1{}.
-export_type([t/0]).

event_type() -> vehicle_commissioned_v1.

-spec new(map()) -> {ok, t()}.
new(#{vehicle_id := Id} = P) ->
    {ok, #vehicle_commissioned_v1{
        vehicle_id      = Id,
        company_id      = maps:get(company_id, P, undefined),
        battery_pct     = maps:get(battery_pct, P, 100),
        lat             = maps:get(lat, P, undefined),
        lng             = maps:get(lng, P, undefined),
        commissioned_at = maps:get(commissioned_at, P, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"vehicle_id">> := Id} = M) ->
    {ok, #vehicle_commissioned_v1{
        vehicle_id      = Id,
        company_id      = maps:get(<<"company_id">>, M, undefined),
        battery_pct     = maps:get(<<"battery_pct">>, M, 100),
        lat             = maps:get(<<"lat">>, M, undefined),
        lng             = maps:get(<<"lng">>, M, undefined),
        commissioned_at = maps:get(<<"commissioned_at">>, M, undefined)
    }};
from_map(#{vehicle_id := Id} = M) ->
    {ok, #vehicle_commissioned_v1{
        vehicle_id      = Id,
        company_id      = maps:get(company_id, M, undefined),
        battery_pct     = maps:get(battery_pct, M, 100),
        lat             = maps:get(lat, M, undefined),
        lng             = maps:get(lng, M, undefined),
        commissioned_at = maps:get(commissioned_at, M, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#vehicle_commissioned_v1{} = E) ->
    #{event_type      => <<"vehicle_commissioned">>,
      vehicle_id      => E#vehicle_commissioned_v1.vehicle_id,
      company_id      => E#vehicle_commissioned_v1.company_id,
      battery_pct     => E#vehicle_commissioned_v1.battery_pct,
      lat             => E#vehicle_commissioned_v1.lat,
      lng             => E#vehicle_commissioned_v1.lng,
      commissioned_at => E#vehicle_commissioned_v1.commissioned_at}.

get_vehicle_id(#vehicle_commissioned_v1{vehicle_id = V})           -> V.
get_company_id(#vehicle_commissioned_v1{company_id = V})           -> V.
get_battery_pct(#vehicle_commissioned_v1{battery_pct = V})         -> V.
get_lat(#vehicle_commissioned_v1{lat = V})                         -> V.
get_lng(#vehicle_commissioned_v1{lng = V})                         -> V.
get_commissioned_at(#vehicle_commissioned_v1{commissioned_at = V}) -> V.
