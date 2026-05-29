%%% @doc Retention sweep for the parking_session dossier.
%%%
%%% Two passes per cycle, server-side (the simulator never touches the
%%% store directly):
%%%
%%%  1. Snapshot-at-archive: any ARCHIVED session stream that lacks a
%%%     snapshot gets one — the folded terminal state recorded at its
%%%     last version. This both preserves "what happened" compactly and
%%%     arms the stream for scavenging (reckon-db refuses to scavenge a
%%%     stream without a snapshot).
%%%  2. Scavenge: event streams older than the retention window are
%%%     scavenged (events deleted, snapshot kept). In-progress sessions
%%%     have no snapshot, so require_snapshot=true skips them safely.
%%%
%%% Net effect: recent sessions keep full event streams (lazyreckon
%%% streams view); older ones collapse to a single terminal snapshot
%%% (lazyreckon snapshots view). Storage stays bounded.
-module(retain_parking_sessions).
-behaviour(gen_server).

-export([start_link/0, sweep_now/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
%% Exposed for unit tests.
-export([fold_state/2, is_session_stream/1]).

-include_lib("reckon_gater/include/reckon_gater_types.hrl").
-include_lib("guide_parking_session_lifecycle/include/parking_session_state.hrl").

-record(st, {interval_ms :: pos_integer(),
             window_us   :: non_neg_integer(),
             batch       :: pos_integer()}).

-define(DEFAULT_INTERVAL_MS, 60000).      %% sweep every 60s real
-define(DEFAULT_WINDOW_MS,   1800000).    %% keep raw events 30 min real
-define(DEFAULT_BATCH,       200).        %% max snapshots recorded per cycle

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Run a sweep immediately (for ops / tests).
-spec sweep_now() -> ok.
sweep_now() -> gen_server:cast(?MODULE, sweep).

init([]) ->
    St = #st{
        interval_ms = cfg(retention_interval_ms, ?DEFAULT_INTERVAL_MS),
        window_us   = cfg(retention_window_ms, ?DEFAULT_WINDOW_MS) * 1000,
        batch       = cfg(retention_snapshot_batch, ?DEFAULT_BATCH)
    },
    schedule(St),
    {ok, St}.

handle_call(_Req, _From, St) -> {reply, {error, unsupported}, St}.

handle_cast(sweep, St) -> do_sweep(St), {noreply, St};
handle_cast(_Msg, St)  -> {noreply, St}.

handle_info(sweep, St) ->
    do_sweep(St),
    schedule(St),
    {noreply, St};
handle_info(_Msg, St) -> {noreply, St}.

%%--------------------------------------------------------------------
%% Sweep

do_sweep(#st{window_us = WindowUs, batch = Batch}) ->
    Store = hecate_parksim_service:store_id(),
    case reckon_gater_api:get_streams(Store) of
        {ok, Streams} ->
            Sessions = [S || S <- Streams, is_session_stream(S)],
            snapshot_pass(Store, Sessions, Batch),
            scavenge_pass(Store, WindowUs);
        {error, Reason} ->
            logger:warning("[retain_parking_sessions] get_streams failed: ~p", [Reason])
    end.

%% Snapshot any archived session that doesn't already have a snapshot,
%% capped at Batch per cycle so a backlog can't stall the sweep.
snapshot_pass(_Store, _Sessions, 0) -> ok;
snapshot_pass(Store, Sessions, Batch) ->
    Pending = [S || S <- Sessions, not has_snapshot(Store, S)],
    lists:foldl(
        fun(_S, 0) -> 0;
           (S, N)  -> maybe_snapshot(Store, S), N - 1
        end,
        Batch, Pending),
    ok.

%% Read the stream, fold to terminal state; snapshot only if archived
%% (terminal). In-progress sessions are left alone.
maybe_snapshot(Store, StreamId) ->
    case reckon_gater_api:stream_forward(Store, StreamId, 0, 10000) of
        {ok, []} -> ok;
        {ok, Events} ->
            State = fold_state(StreamId, Events),
            case parking_session_state:is_archived(State) of
                true ->
                    Version = (lists:last(Events))#event.version,
                    reckon_gater_api:record_snapshot(
                        Store, StreamId, StreamId, Version,
                        parking_session_state:to_map(State));
                false -> ok
            end;
        {error, Reason} ->
            logger:warning("[retain_parking_sessions] read ~s failed: ~p", [StreamId, Reason])
    end.

scavenge_pass(Store, WindowUs) ->
    Cutoff = erlang:system_time(microsecond) - WindowUs,
    case reckon_gater_api:scavenge_matching(
           Store, <<"sess-*">>, #{before => Cutoff, require_snapshot => true}) of
        {ok, _Results} -> ok;
        {error, Reason} ->
            logger:warning("[retain_parking_sessions] scavenge failed: ~p", [Reason])
    end.

%%--------------------------------------------------------------------
%% Pure helpers

%% Fold stored events into parking_session_state. Each #event{} carries
%% the type in the envelope and the business fields in `data`; merging
%% the type back in rebuilds the flat map apply_event/2 expects,
%% regardless of whether `data` already held it.
fold_state(StreamId, Events) ->
    lists:foldl(
        fun(#event{event_type = ET, data = D}, Acc) ->
            Map = ensure_map(D),
            parking_session_state:apply_event(Acc, Map#{event_type => ET})
        end,
        parking_session_state:new(StreamId),
        Events).

ensure_map(D) when is_map(D) -> D;
ensure_map(_)                -> #{}.

has_snapshot(Store, StreamId) ->
    case reckon_gater_api:list_snapshots(Store, StreamId, StreamId) of
        {ok, [_ | _]} -> true;
        _             -> false
    end.

is_session_stream(<<"sess-", _/binary>>) -> true;
is_session_stream(_)                     -> false.

%%--------------------------------------------------------------------
%% Internal

schedule(#st{interval_ms = Ms}) ->
    erlang:send_after(Ms, self(), sweep).

cfg(Key, Default) ->
    case application:get_env(hecate_parksim, Key, Default) of
        N when is_integer(N), N > 0 -> N;
        _                           -> Default
    end.
