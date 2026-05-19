%%% @doc Thin wrapper around macula:call/5 for the parksim simulator.
%%%
%%% Looks up the macula pool and realm via hecate_om once at boot and
%%% caches them. Every simulator-side mesh interaction goes through
%%% `call/2`. In dry_run mode the call is logged and skipped — useful
%%% when no station is reachable.
-module(parksim_simulator_mesh).

-export([call/2, dry_run/0, capability/2]).

-define(DEFAULT_TIMEOUT_MS, 5000).

-spec call(binary(), term()) -> {ok, term()} | {error, term()}.
call(Capability, Payload) ->
    case dry_run() of
        true  -> log_dry(Capability, Payload), {ok, dry_run};
        false -> macula_call(Capability, Payload)
    end.

macula_call(Capability, Payload) ->
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            macula:call(Pool, Realm, Capability, Payload, ?DEFAULT_TIMEOUT_MS);
        _ ->
            {error, mesh_unavailable}
    end.

-spec dry_run() -> boolean().
dry_run() ->
    application:get_env(hecate_parksim_simulator, dry_run, false).

%% @doc Build a `service.command` capability binary.
-spec capability(binary(), binary()) -> binary().
capability(Service, Command) ->
    <<Service/binary, ".", Command/binary>>.

log_dry(Capability, Payload) ->
    error_logger:info_msg("[simulator] dry-call ~s ~p~n", [Capability, Payload]),
    ok.
