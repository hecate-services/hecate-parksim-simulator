%%% @doc Payment-terminal stimulus emitter (ticket visits only). The
%%% driver inserts the card at the pay-on-foot station and tenders
%%% payment; the terminal's saga quotes the fee, accepts, validates the
%%% card (PAID + grace), and returns it.
-module(simulate_payment_terminal).

-export([pay/1]).

-define(AMOUNT_CENTS, 250).

-spec pay(map()) -> ok.
pay(#{terminal := Terminal, card_id := CardId}) ->
    Caps = parksim_simulator_capabilities,
    Mesh = parksim_simulator_mesh,
    _ = Mesh:call(Caps:terminal_accept_card(),
                  #{terminal_id => Terminal,
                    card_id     => CardId,
                    at          => simulate_clock:now_iso8601()}),
    _ = Mesh:call(Caps:terminal_tender_payment(),
                  #{terminal_id => Terminal,
                    card_id     => CardId,
                    amount      => ?AMOUNT_CENTS,
                    method      => <<"card">>,
                    at          => simulate_clock:now_iso8601()}),
    ok.
