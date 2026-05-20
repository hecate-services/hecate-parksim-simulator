%%% @doc Dry-run smoke tests for the physical-visit device emitters.
%%% In dry_run the mesh call logs and returns {ok, dry_run}, so we only
%%% assert each emitter builds a well-formed call and returns ok for
%%% both the ticket and permit credential paths.
-module(simulate_visit_tests).

-include_lib("eunit/include/eunit.hrl").

setup() ->
    application:set_env(hecate_parksim_simulator, dry_run, true),
    ok.

ctx(Credential) ->
    #{lot_id       => <<"lot-grote-markt">>,
      entry_island => <<"lot-grote-markt:entry:1">>,
      exit_island  => <<"lot-grote-markt:exit:1">>,
      terminal     => <<"lot-grote-markt:pay:1">>,
      plate        => <<"1-ABC-234">>,
      credential   => Credential,
      card_id      => <<"card-deadbeef">>}.

entry_ticket_test()  -> setup(), ?assertEqual(ok, simulate_entry_island:admit(ctx(ticket))).
entry_permit_test()  -> setup(), ?assertEqual(ok, simulate_entry_island:admit(ctx({permit, <<"permit-1-ABC-234">>}))).
payment_test()       -> setup(), ?assertEqual(ok, simulate_payment_terminal:pay(ctx(ticket))).
exit_ticket_test()   -> setup(), ?assertEqual(ok, simulate_exit_island:egress(ctx(ticket))).
exit_permit_test()   -> setup(), ?assertEqual(ok, simulate_exit_island:egress(ctx({permit, <<"permit-1-ABC-234">>}))).
