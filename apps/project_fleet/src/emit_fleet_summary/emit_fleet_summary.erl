%%% @doc Emits this operator's fleet summary as an integration FACT on the
%%% Macula mesh, on a fixed cadence.
%%%
%%% The fact is an explicit, stable public contract — a per-operator rollup
%%% (phase counts, trips, revenue, per-facility occupancy) derived from the
%%% local read model — NOT a bridge of internal domain events. The realm-side
%%% consumer subscribes to `fleet/+/summary' to assemble the city view.
%%%
%%% Mesh access degrades safely: while the service is dark (no mesh client /
%%% no realm) `hecate_om:macula_client/0' returns `{error, _}', so a tick is
%%% simply skipped and retried. Nothing here can disturb the sim or store.
-module(emit_fleet_summary).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([to_fact/1]).   %% exported for tests

-define(DEFAULT_INTERVAL_MS, 5000).

-record(state, {interval :: pos_integer(),
                company  :: binary(),
                topic    :: binary()}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Interval = application:get_env(hecate_parksim, summary_interval_ms, ?DEFAULT_INTERVAL_MS),
    Company  = list_to_binary(hecate_parksim_service:tenant_id()),
    Topic    = <<"fleet/", Company/binary, "/summary">>,
    erlang:send_after(Interval, self(), tick),
    {ok, #state{interval = Interval, company = Company, topic = Topic}}.

handle_info(tick, #state{interval = Interval} = S) ->
    _ = publish(S),
    erlang:send_after(Interval, self(), tick),
    {noreply, S};
handle_info(_Msg, S) ->
    {noreply, S}.

handle_call(_Req, _From, S) -> {reply, ok, S}.
handle_cast(_Msg, S)        -> {noreply, S}.

%%--------------------------------------------------------------------

publish(#state{company = Company, topic = Topic}) ->
    case {hecate_om:macula_client(), hecate_om_identity:realm()} of
        {{ok, Pool}, {ok, Realm}} ->
            Fact = to_fact(Company),
            %% Pass the map as a term — V2 wire is CBOR; never JSON-encode.
            catch macula:publish(Pool, Realm, Topic, Fact),
            ok;
        _DarkOrNoRealm ->
            ok
    end.

%% The public integration-fact contract: a stable subset of the read model.
%% Reads the store directly (it lives in this app) rather than via the
%% query_fleet facade — that would make project_fleet depend on query_fleet,
%% which already depends on project_fleet (a cycle).
to_fact(Company) ->
    Ov  = safe(fun project_fleet_store:overview/0, #{}),
    Fac = safe(fun project_fleet_store:by_facility/0, []),
    #{type          => fleet_summary,
      company       => Company,
      total         => g(total, Ov),
      cruising      => g(cruising, Ov),
      dispatched    => g(dispatched, Ov),
      on_trip       => g(on_trip, Ov),
      returning     => g(returning, Ov),
      docked        => g(docked, Ov),
      servicing     => g(servicing, Ov),
      charging      => g(charging, Ov),
      depleted      => g(depleted, Ov),
      active        => g(active, Ov),
      trips         => g(trips, Ov),
      revenue_cents => g(revenue_cents, Ov),
      facilities    => Fac,
      observed_at   => erlang:system_time(millisecond)}.

g(K, M) -> maps:get(K, M, 0).

%% Read models may be momentarily unavailable at boot; never let that crash
%% the emitter — fall back to the empty default and try again next tick.
safe(Fun, Default) ->
    try Fun() of R -> R catch _:_ -> Default end.
