%%% @doc One simulated parking visit. Dispatches the three session
%%% events directly via evoq_dispatcher to the tenant store.
%%%
%%% Lifecycle: initiate_parking_session -> capture_payment -> archive_parking_session.
%%% Dwell is log-normal in seconds, clipped to [60, 24h]. ~0.7% of
%%% visits abandon (never pay, never archive — leaves an orphan
%%% INITIATED session in the store, which is realistic.)
-module(simulate_visit).

-export([start_visit/1]).

-include_lib("parksim_simulator/include/parksim_simulator_scenario.hrl").

%% @doc Spawn one visit process. Params: #{lot, plate, credential}.
-spec start_visit(map()) -> {ok, pid()}.
start_visit(Params) ->
    {ok, proc_lib:spawn(fun() -> run(Params) end)}.

run(#{lot := Lot, plate := Plate, credential := Credential}) ->
    Rng = rand:seed_s(exsss, {erlang:phash2(self()),
                              erlang:phash2(make_ref()),
                              erlang:system_time(microsecond)}),
    LotId     = Lot#parksim_lot.id,
    SessionId = uuid_v4(),
    CardId    = card_id(Credential),
    enter(SessionId, LotId, Plate, CardId),
    {DwellSec, Rng1} = sample_dwell(Rng, Lot),
    simulate_clock:sleep_simulated(DwellSec * 1000),
    case roll_abandon(Rng1) of
        {true,  _Rng2} -> ok;
        {false, Rng2}  -> pay_then_archive(SessionId, DwellSec, Credential, Rng2)
    end.

%%--------------------------------------------------------------------
%% Lifecycle dispatch

enter(SessionId, LotId, Plate, CardId) ->
    _ = maybe_initiate_parking_session:dispatch(#{
        session_id => SessionId,
        lot_id     => LotId,
        plate      => Plate,
        card_id    => CardId,
        entered_at => simulate_clock:now_iso8601()
    }),
    ok.

%% Ticket visits pay on foot before leaving; permit visits skip payment.
pay_then_archive(SessionId, DwellSec, ticket, Rng) ->
    {Pause, _} = uniform_int_s(Rng, 2, 90),
    simulate_clock:sleep_simulated(Pause * 1000),
    Amount = compute_fee_cents(DwellSec),
    _ = maybe_capture_payment:dispatch(#{
        session_id   => SessionId,
        amount_cents => Amount,
        paid_at      => simulate_clock:now_iso8601()
    }),
    archive(SessionId, undefined);
pay_then_archive(SessionId, _DwellSec, {permit, _Ref}, _Rng) ->
    %% Permit holders have a pre-paid relationship; archive without
    %% a payment event. fee_cents winds up undefined on the archive.
    archive(SessionId, <<"permit">>).

archive(SessionId, Reason) ->
    _ = maybe_archive_parking_session:dispatch(#{
        session_id  => SessionId,
        reason      => Reason,
        archived_at => simulate_clock:now_iso8601()
    }),
    ok.

%%--------------------------------------------------------------------
%% Fee model — flat EUR 2.50 / started hour, min EUR 0.50. Crude but
%% gives the events realistic amount_cents values for the demo.

compute_fee_cents(DwellSec) ->
    HoursStarted = max(1, (DwellSec + 3599) div 3600),
    max(50, HoursStarted * 250).

%%--------------------------------------------------------------------
%% Identity / payload helpers

card_id(ticket)      -> <<"card-", (hex(crypto:strong_rand_bytes(8)))/binary>>;
card_id({permit, _}) -> undefined.

%% Generate a session id that satisfies reckon_db's user_re:
%%   ^[A-Za-z]+-[A-Fa-f0-9]+$    (single hyphen, hex-only suffix).
%% UUID-v4 with internal hyphens + uppercase doesn't pass — use
%% `sess-<32-lowercase-hex>` instead.
uuid_v4() ->
    <<"sess-", (hex(crypto:strong_rand_bytes(16)))/binary>>.

%%--------------------------------------------------------------------
%% Distributions

%% LogNormal(mu, sigma) clipped to [60, 24h] seconds.
sample_dwell(Rng, #parksim_lot{dwell_mu = Mu, dwell_sigma = Sigma}) ->
    {Z, Rng1} = rand:normal_s(Rng),
    X = math:exp(Mu + Sigma * Z),
    {max(60, min(round(X), 24 * 3600)), Rng1}.

roll_abandon(Rng) ->
    {U, Rng1} = rand:uniform_s(Rng),
    {U =< 0.007, Rng1}.

uniform_int_s(Rng, Lo, Hi) when Hi >= Lo ->
    {U, Rng1} = rand:uniform_s(Hi - Lo + 1, Rng),
    {Lo + U - 1, Rng1}.

hex(Bin) -> << <<(nibble(N))>> || <<N:4>> <= Bin >>.
nibble(N) when N < 10 -> $0 + N;
nibble(N)             -> $a + (N - 10).
