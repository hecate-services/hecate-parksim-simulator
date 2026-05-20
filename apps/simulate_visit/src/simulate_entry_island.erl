%%% @doc Entry-island stimulus emitter. A vehicle arrives at the entry
%%% lane: the loop trips (detect_vehicle), then either the driver taps a
%%% permit (permit visit) or just pulls up and the island's saga
%%% dispenses a card after the window (ticket visit — nothing more to
%%% emit here).
-module(simulate_entry_island).

-export([admit/1]).

-define(MESH, parksim_simulator_mesh).
-define(CAPS, parksim_simulator_capabilities).

-spec admit(map()) -> ok.
admit(#{entry_island := Island, credential := Credential} = Ctx) ->
    DetectionId = detection_id(),
    detect(Island, DetectionId),
    present(Credential, Island, DetectionId, Ctx).

detect(Island, DetectionId) ->
    _ = ?MESH:call(?CAPS:entry_island_detect_vehicle(),
                   #{island_id    => Island,
                     detection_id => DetectionId,
                     at           => simulate_clock:now_iso8601()}),
    ok.

%% Permit visit: tap the transponder inside the dispense window so the
%% saga takes the permit path. Ticket visit: do nothing (the saga's
%% timer dispenses a card).
present({permit, PermitRef}, Island, DetectionId, #{plate := Plate}) ->
    _ = ?MESH:call(?CAPS:entry_island_present_permit(),
                   #{island_id          => Island,
                     detection_id       => DetectionId,
                     claimed_permit_ref => PermitRef,
                     plate              => Plate,
                     at                 => simulate_clock:now_iso8601()}),
    ok;
present(ticket, _Island, _DetectionId, _Ctx) ->
    ok.

detection_id() -> <<"det-", (integer_to_binary(erlang:unique_integer([positive])))/binary>>.
