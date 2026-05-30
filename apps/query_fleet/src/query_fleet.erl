%%% @doc Query facade for the robotaxi fleet read models.
%%%
%%% Thin pass-through to the projection store (QRY reads the same SQLite the
%%% PRJ side writes). A separate module gives a stable query API independent
%%% of storage details.
-module(query_fleet).

-export([overview/0, vehicles/0, by_facility/0, recent/1]).

overview()    -> project_fleet_store:overview().
vehicles()    -> project_fleet_store:vehicles().
by_facility() -> project_fleet_store:by_facility().
recent(Limit) -> project_fleet_store:recent(Limit).
