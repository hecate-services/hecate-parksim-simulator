%%% @doc Exit-island stimulus emitter. The vehicle reaches the exit
%%% lane: the loop trips (detect_vehicle), then the driver feeds the
%%% paid card (ticket visit) or re-taps the permit transponder (permit
%%% visit). The island's egress saga decides whether to open + capture
%%% or reject.
-module(simulate_exit_island).

-export([egress/1]).

-define(MESH, parksim_simulator_mesh).
-define(CAPS, parksim_simulator_capabilities).

-spec egress(map()) -> ok.
egress(#{exit_island := Island, credential := Credential} = Ctx) ->
    DetectionId = detection_id(),
    detect(Island, DetectionId),
    present(Credential, Island, DetectionId, Ctx).

detect(Island, DetectionId) ->
    _ = ?MESH:call(?CAPS:exit_island_detect_vehicle(),
                   #{island_id    => Island,
                     detection_id => DetectionId,
                     at           => simulate_clock:now_iso8601()}),
    ok.

%% Ticket visit: feed the card. Permit visit: re-tap the same permit
%% credential the vehicle entered on.
present(ticket, Island, DetectionId, #{card_id := CardId}) ->
    _ = ?MESH:call(?CAPS:exit_island_read_card(),
                   #{island_id    => Island,
                     detection_id => DetectionId,
                     card_id      => CardId,
                     at           => simulate_clock:now_iso8601()}),
    ok;
present({permit, PermitRef}, Island, DetectionId, #{plate := Plate}) ->
    _ = ?MESH:call(?CAPS:exit_island_present_permit(),
                   #{island_id          => Island,
                     detection_id       => DetectionId,
                     claimed_permit_ref => PermitRef,
                     plate              => Plate,
                     at                 => simulate_clock:now_iso8601()}),
    ok.

detection_id() -> <<"det-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>.
