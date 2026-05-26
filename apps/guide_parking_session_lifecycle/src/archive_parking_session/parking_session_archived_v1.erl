%%% @doc Event `parking_session_archived_v1`. Vehicle exited, books
%%% closed. `fee_cents` is the amount captured at payment time (echoed
%%% from state — DDD's "event payload is a subset of the dossier").
-module(parking_session_archived_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_session_id/1, get_fee_cents/1, get_archived_at/1, get_reason/1]).

-record(parking_session_archived_v1, {
    session_id  :: binary() | undefined,
    fee_cents   :: non_neg_integer() | undefined,
    archived_at :: binary() | undefined,
    reason      :: binary() | undefined
}).

-opaque t() :: #parking_session_archived_v1{}.
-export_type([t/0]).

event_type() -> parking_session_archived_v1.

-spec new(map()) -> {ok, t()}.
new(#{session_id := Id} = Params) ->
    {ok, #parking_session_archived_v1{
        session_id  = Id,
        fee_cents   = maps:get(fee_cents,   Params, undefined),
        archived_at = maps:get(archived_at, Params, undefined),
        reason      = maps:get(reason,      Params, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"session_id">> := Id} = Map) ->
    {ok, #parking_session_archived_v1{
        session_id  = Id,
        fee_cents   = maps:get(<<"fee_cents">>,   Map, undefined),
        archived_at = maps:get(<<"archived_at">>, Map, undefined),
        reason      = maps:get(<<"reason">>,      Map, undefined)
    }};
from_map(#{session_id := Id} = Map) ->
    {ok, #parking_session_archived_v1{
        session_id  = Id,
        fee_cents   = maps:get(fee_cents,   Map, undefined),
        archived_at = maps:get(archived_at, Map, undefined),
        reason      = maps:get(reason,      Map, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#parking_session_archived_v1{} = Ev) ->
    #{
        event_type  => <<"parking_session_archived">>,
        session_id  => Ev#parking_session_archived_v1.session_id,
        fee_cents   => Ev#parking_session_archived_v1.fee_cents,
        archived_at => Ev#parking_session_archived_v1.archived_at,
        reason      => Ev#parking_session_archived_v1.reason
    }.

get_session_id(#parking_session_archived_v1{session_id = V})   -> V.
get_fee_cents(#parking_session_archived_v1{fee_cents = V})     -> V.
get_archived_at(#parking_session_archived_v1{archived_at = V}) -> V.
get_reason(#parking_session_archived_v1{reason = V})           -> V.
