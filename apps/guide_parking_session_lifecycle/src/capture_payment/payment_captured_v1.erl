%%% @doc Event `payment_captured_v1`. Payment recorded for a session.
-module(payment_captured_v1).
-behaviour(evoq_event).

-export([event_type/0]).
-export([new/1, from_map/1, to_map/1]).
-export([get_session_id/1, get_amount_cents/1, get_paid_at/1]).

-record(payment_captured_v1, {
    session_id   :: binary() | undefined,
    amount_cents :: non_neg_integer() | undefined,
    paid_at      :: binary() | undefined
}).

-opaque t() :: #payment_captured_v1{}.
-export_type([t/0]).

event_type() -> payment_captured_v1.

-spec new(map()) -> {ok, t()}.
new(#{session_id := Id} = Params) ->
    {ok, #payment_captured_v1{
        session_id   = Id,
        amount_cents = maps:get(amount_cents, Params, undefined),
        paid_at      = maps:get(paid_at,      Params, undefined)
    }}.

-spec from_map(map()) -> {ok, t()}.
from_map(#{<<"session_id">> := Id} = Map) ->
    {ok, #payment_captured_v1{
        session_id   = Id,
        amount_cents = maps:get(<<"amount_cents">>, Map, undefined),
        paid_at      = maps:get(<<"paid_at">>,      Map, undefined)
    }};
from_map(#{session_id := Id} = Map) ->
    {ok, #payment_captured_v1{
        session_id   = Id,
        amount_cents = maps:get(amount_cents, Map, undefined),
        paid_at      = maps:get(paid_at,      Map, undefined)
    }}.

-spec to_map(t()) -> map().
to_map(#payment_captured_v1{} = Ev) ->
    #{
        event_type   => <<"payment_captured">>,
        session_id   => Ev#payment_captured_v1.session_id,
        amount_cents => Ev#payment_captured_v1.amount_cents,
        paid_at      => Ev#payment_captured_v1.paid_at
    }.

get_session_id(#payment_captured_v1{session_id = V})     -> V.
get_amount_cents(#payment_captured_v1{amount_cents = V}) -> V.
get_paid_at(#payment_captured_v1{paid_at = V})           -> V.
