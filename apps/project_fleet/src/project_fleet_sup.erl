%%% @doc Starts the fleet read-model store, the projection worker, and the
%%% two mesh publishers (summary + telemetry) for the robotaxi PRJ
%%% department. The emitters no-op while the service is dark (no mesh
%%% client), so they're always safe to run.
-module(project_fleet_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Store = #{id => project_fleet_store,
              start => {project_fleet_store, start_link, []}},
    %% The projection is started + kept alive by a keeper rather than wired
    %% as a direct child: at boot evoq_projection:start_link races the store's
    %% cluster registration and ends up a permanent-but-dead `undefined' child
    %% the supervisor never retries. The keeper retries until it sticks and
    %% relaunches it on death. See project_fleet_projection_starter.
    Projection = #{id => project_fleet_projection_starter,
                   start => {project_fleet_projection_starter, start_link, []}},
    %% Mesh publishers: per-operator summary (5s) + live telemetry (2s).
    Summary = #{id => emit_fleet_summary,
                start => {emit_fleet_summary, start_link, []}},
    Telemetry = #{id => emit_fleet_telemetry,
                  start => {emit_fleet_telemetry, start_link, []}},
    {ok, {SupFlags, [Store, Projection, Summary, Telemetry]}}.
