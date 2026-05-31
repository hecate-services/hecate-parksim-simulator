%%% @doc Keeps the `vehicle_event_to_read_model' projection alive.
%%%
%%% Why this exists: starting the projection as a DIRECT supervisor child
%%% raced the per-tenant reckon-db store's cluster boot (leader election +
%%% store-registry propagation). At that moment `evoq_projection:start_link/3'
%%% returns `ignore' (or the freshly-started process exits before it can
%%% subscribe), which a plain supervisor records as a permanent `undefined'
%%% child it never retries — so the projection silently never ran, events
%%% piled up in reckon-db, and the SQLite read model stayed empty (trips /
%%% revenue / facility occupancy all 0). No crash was logged.
%%%
%%% This keeper retries until the projection sticks, and relaunches it if it
%%% ever dies. It traps exits and uses `start_link/3' (the only API evoq
%%% exposes), so a projection crash arrives as a trapped `EXIT' and triggers
%%% a relaunch rather than taking this process down. Mirrors the
%%% connect-and-retry idiom used by `hecate_om_identity' / `MaculaRealm.Mesh'.
%%%
%%% The projection itself is idempotent on replay (it folds the durable
%%% reckon-db event log from the start each time it subscribes), so a late
%%% or repeated launch catches the read model up correctly.
-module(project_fleet_projection_starter).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(PROJECTION, vehicle_event_to_read_model).
-define(RETRY_MS, 2000).

-record(state, {proj :: pid() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    process_flag(trap_exit, true),
    self() ! start,
    {ok, #state{proj = undefined}}.

handle_info(start, #state{proj = undefined} = S) ->
    Store = hecate_parksim_service:store_id(),
    case start_projection(Store) of
        {ok, Pid} ->
            {noreply, S#state{proj = Pid}};
        retry ->
            erlang:send_after(?RETRY_MS, self(), start),
            {noreply, S}
    end;
handle_info(start, S) ->
    %% Already running.
    {noreply, S};
handle_info({'EXIT', Pid, _Reason}, #state{proj = Pid} = S) ->
    %% The projection went down — relaunch after a short pause.
    erlang:send_after(?RETRY_MS, self(), start),
    {noreply, S#state{proj = undefined}};
handle_info(_Msg, S) ->
    {noreply, S}.

handle_call(_Req, _From, S) -> {reply, ok, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
terminate(_Reason, _S)      -> ok.

%%--------------------------------------------------------------------

%% start_link the projection; normalise every outcome to {ok, Pid} | retry.
start_projection(Store) ->
    try evoq_projection:start_link(?PROJECTION, #{}, #{store_id => Store}) of
        {ok, Pid}                      -> {ok, Pid};
        {error, {already_started, P}}  -> {ok, P};
        ignore                         -> retry;
        {error, _Why}                  -> retry
    catch
        _:_ -> retry
    end.
