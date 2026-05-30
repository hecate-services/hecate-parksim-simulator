%%% @doc HTTP API for the robotaxi fleet read models (cowboy handler, JSON).
%%%
%%% Routes (see query_fleet_app for dispatch):
%%%   GET /api/fleet/overview     — fleet rollup (phase counts, trips, revenue)
%%%   GET /api/fleet/vehicles     — every vehicle's current phase + last-event pos
%%%   GET /api/fleet/facilities   — vehicles docked/servicing per facility
%%%   GET /api/fleet/recent       — recent activity feed
%%%   GET /health                 — liveness
-module(query_fleet_api).

-export([init/2]).

init(Req0, overview = State) ->
    reply_json(Req0, 200, query_fleet:overview(), State);
init(Req0, vehicles = State) ->
    reply_json(Req0, 200, query_fleet:vehicles(), State);
init(Req0, facilities = State) ->
    reply_json(Req0, 200, query_fleet:by_facility(), State);
init(Req0, recent = State) ->
    reply_json(Req0, 200, query_fleet:recent(limit_param(Req0)), State);
init(Req0, health = State) ->
    reply_json(Req0, 200, #{status => <<"ok">>}, State).

%%--------------------------------------------------------------------

reply_json(Req0, Code, Body, State) ->
    Req = cowboy_req:reply(Code,
        #{<<"content-type">> => <<"application/json">>},
        jsx:encode(jsonable(Body)), Req0),
    {ok, Req, State}.

limit_param(Req) ->
    #{limit := L} = cowboy_req:match_qs([{limit, [], <<"50">>}], Req),
    binary_to_integer(L).

jsonable(M) when is_map(M)  -> maps:map(fun(_, V) -> jsonable(V) end, M);
jsonable(L) when is_list(L) -> [jsonable(X) || X <- L];
jsonable(V) -> V.
