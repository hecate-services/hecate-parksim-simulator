%%% @doc Projection: parking_session events → SQLite read model.
%%%
%%% One projection for all five event types; each upserts the columns
%%% it owns into the single `sessions` row (idempotent). The real read
%%% model is the SQLite store (project_parking_sessions_store); the
%%% evoq read model handed back here is only evoq's checkpoint holder.
-module(parking_session_to_read_model).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() ->
    [<<"parking_session_initiated">>,
     <<"vehicle_docked">>,
     <<"vehicle_undocked">>,
     <<"payment_captured">>,
     <<"parking_session_archived">>].

init(_Config) ->
    %% The SQLite store is the durable read model; this ETS read model
    %% just carries evoq's checkpoint bookkeeping.
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{}),
    {ok, #{}, RM}.

%% evoq passes #{event_type := T, data := Data}; business fields live in
%% `data`. Flatten {data + type} into the shape the store reads.
project(#{event_type := EventType, data := Data}, _Metadata, State, RM) ->
    ok = project_parking_sessions_store:apply_event(Data#{event_type => EventType}),
    {ok, State, RM};
project(#{event_type := EventType} = Event, _Metadata, State, RM) ->
    %% Defensive: some paths deliver a flat event (no nested `data`).
    ok = project_parking_sessions_store:apply_event(Event#{event_type => EventType}),
    {ok, State, RM};
project(_Event, _Metadata, State, RM) ->
    {skip, State, RM}.
