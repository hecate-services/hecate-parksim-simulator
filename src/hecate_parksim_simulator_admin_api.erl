%%% @doc Small cowboy admin surface for the simulator. POST endpoints
%%% mirror the original CLI subcommands: run, event, evacuate.
-module(hecate_parksim_simulator_admin_api).

-export([init/2]).

init(Req, [run]) ->
    %% Future: kick off a scoped run with explicit parameters. For now,
    %% the simulator is always-on (started by the supervision tree from
    %% sys.config defaults). This endpoint reports current configuration.
    Body = parksim_simulator_config:as_map(),
    reply_json(200, Body, Req);
init(Req, [event]) ->
    case read_json(Req) of
        {ok, Params, Req1} ->
            handle_event(Params, Req1);
        {error, _Reason, Req1} ->
            reply_json(400, #{error => <<"invalid_json">>}, Req1)
    end;
init(Req, [evacuate]) ->
    case read_json(Req) of
        {ok, #{<<"lot_id">> := LotId}, Req1} ->
            simulate_lots:evacuate(LotId),
            reply_json(202, #{status => accepted, lot_id => LotId}, Req1);
        {ok, _, Req1} ->
            reply_json(400, #{error => <<"missing_lot_id">>}, Req1);
        {error, _Reason, Req1} ->
            reply_json(400, #{error => <<"invalid_json">>}, Req1)
    end.

handle_event(Params, Req) ->
    Kind       = maps:get(<<"kind">>,       Params, <<"festival">>),
    At         = maps:get(<<"at">>,         Params, iso8601_now()),
    Duration   = maps:get(<<"duration">>,   Params, 3600),
    Multiplier = maps:get(<<"multiplier">>, Params, 1.5),
    simulate_pricing:inject_event(#{
        kind       => Kind,
        at         => At,
        duration_s => Duration,
        multiplier => Multiplier
    }),
    reply_json(202, #{status => accepted, kind => Kind}, Req).

read_json(Req0) ->
    case cowboy_req:read_body(Req0) of
        {ok, <<>>, Req1} ->
            {ok, #{}, Req1};
        {ok, Body, Req1} ->
            try {ok, jsx:decode(Body, [return_maps]), Req1}
            catch _:_ -> {error, invalid_json, Req1}
            end
    end.

reply_json(Code, Body, Req) ->
    cowboy_req:reply(Code,
        #{<<"content-type">> => <<"application/json">>},
        jsx:encode(Body), Req).

iso8601_now() ->
    {{Y, Mo, D}, {H, Mi, S}} = calendar:system_time_to_universal_time(
        erlang:system_time(second), second),
    iolist_to_binary(io_lib:format(
        "~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ",
        [Y, Mo, D, H, Mi, S])).
