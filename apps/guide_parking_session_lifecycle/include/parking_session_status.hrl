%%% @doc Status bit-flag macros for the parking_session aggregate.
%%%
%%% Powers of two. Combined into a non_neg_integer kept in
%%% `#parking_session_state.status_flags` and folded with
%%% `evoq_bit_flags`. Independent flags — ordering is enforced by each
%%% handler's preconditions, not the bits. Physical path:
%%% INITIATED -> DOCKED -> (PAID at kiosk, or after) UNDOCKED -> ARCHIVED.

-define(SESSION_INITIATED, 1).   %% 2^0 — birth slip filed (vehicle entered the lot)
-define(SESSION_PAID,      2).   %% 2^1 — payment captured
-define(SESSION_ARCHIVED,  4).   %% 2^2 — books closed (vehicle exited + settled)
-define(SESSION_DOCKED,    8).   %% 2^3 — vehicle parked in a bay
-define(SESSION_UNDOCKED, 16).   %% 2^4 — vehicle released the bay
