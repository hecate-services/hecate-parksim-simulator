%%% @doc Status bit-flag macros for the parking_session aggregate.
%%%
%%% Powers of two. Combined into a non_neg_integer kept in
%%% `#parking_session_state.status_flags` and folded with
%%% `evoq_bit_flags`. State machine: INITIATED -> PAID -> ARCHIVED.

-define(SESSION_INITIATED, 1).   %% 2^0 — birth slip filed (vehicle entered)
-define(SESSION_PAID,      2).   %% 2^1 — payment captured
-define(SESSION_ARCHIVED,  4).   %% 2^2 — books closed (vehicle exited + settled)
