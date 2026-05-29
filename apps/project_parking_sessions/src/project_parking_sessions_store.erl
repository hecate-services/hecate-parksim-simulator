%%% @doc SQLite read model for parking sessions — the durable,
%%% queryable system of record (one row per session). The projection
%%% upserts here as events arrive; QRY reads here. Because this is
%%% durable, the event store can be scavenged freely without losing
%%% "what happened".
%%%
%%% Lazy boot: starts cold, opens the DB on first use. The DB lives
%%% under the tenant's data dir (persistent /bulk volume), so it
%%% survives restarts — it is NEVER rebuilt from the (scavenged) event
%%% store; the projection only moves forward.
-module(project_parking_sessions_store).
-behaviour(gen_server).

-include_lib("guide_parking_session_lifecycle/include/parking_session_status.hrl").

-export([start_link/0, apply_event/1, overview/0, get/1, recent/1]).
-export([due_for_scavenge/2, mark_scavenged/1]).
-export([init/1, handle_call/3, handle_cast/2, terminate/2]).

-record(state, {db :: term() | undefined}).

-define(SELECT_COLS,
    "session_id, status, lot_id, bay_id, plate, card_id, permit_ref, "
    "entered_at, docked_at, undocked_at, paid_at, archived_at, amount_cents").
-define(SELECT_ONE,    "SELECT " ?SELECT_COLS " FROM sessions WHERE session_id = ?1;").
-define(SELECT_RECENT, "SELECT " ?SELECT_COLS " FROM sessions ORDER BY entered_at DESC LIMIT ?1;").

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Upsert the read-model row for one event (called by the projection).
-spec apply_event(map()) -> ok | {error, term()}.
apply_event(Event) -> gen_server:call(?MODULE, {apply_event, Event}).

%% @doc Aggregate overview for the QRY side — counts, revenue, by-status, by-lot.
-spec overview() -> {ok, map()} | {error, term()}.
overview() -> gen_server:call(?MODULE, overview).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(SessionId) -> gen_server:call(?MODULE, {get, SessionId}).

-spec recent(pos_integer()) -> {ok, [map()]} | {error, term()}.
recent(Limit) -> gen_server:call(?MODULE, {recent, Limit}).

%% @doc Session ids archived before CutoffIso whose event streams have
%% not yet been scavenged — drives the retention sweep (O(aged), indexed).
-spec due_for_scavenge(binary() | string(), pos_integer()) -> {ok, [binary()]} | {error, term()}.
due_for_scavenge(CutoffIso, Limit) -> gen_server:call(?MODULE, {due_for_scavenge, CutoffIso, Limit}).

%% @doc Mark a session's events as scavenged so it isn't revisited.
-spec mark_scavenged(binary()) -> ok | {error, term()}.
mark_scavenged(SessionId) -> gen_server:call(?MODULE, {mark_scavenged, SessionId}).

%%--------------------------------------------------------------------

init([]) -> {ok, #state{db = undefined}}.

handle_call(Req, _From, S0) ->
    case ensure_open(S0) of
        {ok, #state{db = Db} = S} -> {reply, do(Req, Db), S};
        {error, _} = E            -> {reply, E, S0}
    end.

handle_cast(_Msg, S) -> {noreply, S}.
terminate(_R, #state{db = Db}) when Db =/= undefined -> catch esqlite3:close(Db), ok;
terminate(_R, _S) -> ok.

%%--------------------------------------------------------------------
%% Request handlers

do({apply_event, Event}, Db) -> upsert(Db, Event);
do(overview, Db)             -> {ok, build_overview(Db)};
do({get, Id}, Db)            -> row_to_session(esqlite3:q(Db, ?SELECT_ONE, [Id]));
do({recent, Limit}, Db)      -> {ok, [as_session(R) || R <- esqlite3:q(Db, ?SELECT_RECENT, [Limit])]};
do({due_for_scavenge, Cutoff, Limit}, Db) ->
    Rows = esqlite3:q(Db,
        "SELECT session_id FROM sessions "
        "WHERE archived_at IS NOT NULL AND archived_at < ?1 AND scavenged = 0 "
        "ORDER BY archived_at LIMIT ?2;", [Cutoff, Limit]),
    {ok, [Id || [Id] <- Rows]};
do({mark_scavenged, Id}, Db) ->
    _ = esqlite3:q(Db, "UPDATE sessions SET scavenged = 1 WHERE session_id = ?1;", [Id]),
    ok.

%%--------------------------------------------------------------------
%% Upsert — one row per session, columns filled in as events arrive.

upsert(Db, #{event_type := <<"parking_session_initiated">>} = E) ->
    ins(Db, sid(E), ?SESSION_INITIATED,
        [{lot_id, g(lot_id, E)}, {plate, g(plate, E)}, {card_id, g(card_id, E)},
         {permit_ref, g(permit_ref, E)}, {entered_at, g(entered_at, E)}]);
upsert(Db, #{event_type := <<"vehicle_docked">>} = E) ->
    ins(Db, sid(E), ?SESSION_DOCKED,
        [{bay_id, g(bay_id, E)}, {docked_at, g(docked_at, E)}]);
upsert(Db, #{event_type := <<"vehicle_undocked">>} = E) ->
    ins(Db, sid(E), ?SESSION_UNDOCKED, [{undocked_at, g(undocked_at, E)}]);
upsert(Db, #{event_type := <<"payment_captured">>} = E) ->
    ins(Db, sid(E), ?SESSION_PAID,
        [{amount_cents, g(amount_cents, E)}, {paid_at, g(paid_at, E)}]);
upsert(Db, #{event_type := <<"parking_session_archived">>} = E) ->
    ins(Db, sid(E), ?SESSION_ARCHIVED, [{archived_at, g(archived_at, E)}]);
upsert(_Db, _Other) -> ok.

%% Ensure the row exists with the flag OR'd in, then set the named columns.
ins(Db, SessionId, Flag, Cols) ->
    _ = esqlite3:q(Db,
        "INSERT INTO sessions (session_id, status) VALUES (?1, ?2) "
        "ON CONFLICT(session_id) DO UPDATE SET status = status | excluded.status;",
        [SessionId, Flag]),
    lists:foreach(
        fun({_C, undefined}) -> ok;
           ({C, V}) ->
               _ = esqlite3:q(Db,
                   ["UPDATE sessions SET ", atom_to_list(C), " = ?1 WHERE session_id = ?2;"],
                   [V, SessionId])
        end, Cols),
    ok.

%%--------------------------------------------------------------------
%% Overview (bitwise flag queries; SQLite supports & and |)

build_overview(Db) ->
    One = fun(Sql) -> scalar(esqlite3:q(Db, Sql)) end,
    #{total         => One("SELECT count(*) FROM sessions;"),
      initiated     => One(["SELECT count(*) FROM sessions WHERE status & ", i(?SESSION_INITIATED), ";"]),
      docked        => One(["SELECT count(*) FROM sessions WHERE status & ", i(?SESSION_DOCKED), ";"]),
      paid          => One(["SELECT count(*) FROM sessions WHERE status & ", i(?SESSION_PAID), ";"]),
      archived      => One(["SELECT count(*) FROM sessions WHERE status & ", i(?SESSION_ARCHIVED), ";"]),
      in_progress   => One(["SELECT count(*) FROM sessions WHERE (status & ", i(?SESSION_ARCHIVED), ") = 0;"]),
      revenue_cents => One("SELECT coalesce(sum(amount_cents),0) FROM sessions;"),
      by_lot        => [#{lot_id => L, sessions => N}
                        || [L, N] <- esqlite3:q(Db,
                             "SELECT coalesce(lot_id,'?'), count(*) FROM sessions GROUP BY lot_id ORDER BY 2 DESC;")]}.

%%--------------------------------------------------------------------
%% DB open + schema

ensure_open(#state{db = Db} = S) when Db =/= undefined -> {ok, S};
ensure_open(#state{} = S) ->
    DbPath = filename:join([hecate_parksim_service:data_dir(), "read_models",
                            "parking_sessions.sqlite"]),
    ok = filelib:ensure_dir(DbPath),
    case esqlite3:open(DbPath) of
        {ok, Db} -> ok = migrate(Db), {ok, S#state{db = Db}};
        {error, _} = E -> E
    end.

migrate(Db) ->
    esqlite3:exec(Db,
        "CREATE TABLE IF NOT EXISTS sessions ("
        "  session_id   TEXT PRIMARY KEY,"
        "  status       INTEGER NOT NULL DEFAULT 0,"
        "  lot_id       TEXT, bay_id TEXT, plate TEXT, card_id TEXT, permit_ref TEXT,"
        "  entered_at   TEXT, docked_at TEXT, undocked_at TEXT, paid_at TEXT, archived_at TEXT,"
        "  amount_cents INTEGER,"
        "  scavenged    INTEGER NOT NULL DEFAULT 0"
        ");").

%%--------------------------------------------------------------------
%% Helpers

sid(E) -> g(session_id, E).

%% Read a value by atom OR binary key (events may arrive either way).
g(Key, Map) ->
    case maps:get(Key, Map, undefined) of
        undefined -> maps:get(atom_to_binary(Key, utf8), Map, undefined);
        V -> V
    end.

i(N) -> integer_to_list(N).

scalar([[N] | _]) -> N;
scalar(_)         -> 0.

row_to_session([]) -> {error, not_found};
row_to_session([R | _]) -> {ok, as_session(R)};
row_to_session({error, _} = E) -> E.

as_session([Sid, St, Lot, Bay, Plate, Card, Permit, Ent, Dock, Undock, Paid, Arch, Amt]) ->
    #{session_id => Sid, status => St, lot_id => Lot, bay_id => Bay, plate => Plate,
      card_id => Card, permit_ref => Permit, entered_at => Ent, docked_at => Dock,
      undocked_at => Undock, paid_at => Paid, archived_at => Arch, amount_cents => Amt}.
