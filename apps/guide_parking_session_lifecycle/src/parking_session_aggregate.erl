%%% @doc Parking-session aggregate.
%%%
%%% Stream: `parking-session-<session_id>`.
%%% Store:  derived from TENANT_ID at boot (see hecate_parksim_service).
-module(parking_session_aggregate).
-behaviour(evoq_aggregate).

-include("parking_session_state.hrl").

-export([state_module/0, init/1, execute/2, apply/2]).

-type state() :: #parking_session_state{}.
-export_type([state/0]).

-spec state_module() -> module().
state_module() -> parking_session_state.

-spec init(binary()) -> {ok, state()}.
init(AggregateId) ->
    {ok, parking_session_state:new(AggregateId)}.

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.
execute(State, #{command_type := <<"initiate_parking_session">>} = P) ->
    route(initiate_parking_session_v1, maybe_initiate_parking_session,
          parking_session_initiated_v1, State, P);
execute(State, #{command_type := <<"capture_payment">>} = P) ->
    route(capture_payment_v1, maybe_capture_payment,
          payment_captured_v1, State, P);
execute(State, #{command_type := <<"archive_parking_session">>} = P) ->
    route(archive_parking_session_v1, maybe_archive_parking_session,
          parking_session_archived_v1, State, P);
execute(_State, #{command_type := Other}) ->
    {error, {unhandled_command, Other}};
execute(_State, _Payload) ->
    {error, missing_command_type}.

route(CmdMod, HandlerMod, EventMod, State, Payload) ->
    case CmdMod:from_map(Payload) of
        {ok, Cmd} ->
            case HandlerMod:handle(Cmd, State) of
                {ok, Events} ->
                    {ok, [EventMod:to_map(E) || E <- Events]};
                {error, _} = Err -> Err
            end;
        {error, _} = Err -> Err
    end.

%% Delegate state folding to the state module.
-spec apply(state(), map()) -> state().
apply(State, Event) ->
    parking_session_state:apply_event(State, Event).
