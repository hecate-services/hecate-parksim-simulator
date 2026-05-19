%%% @doc Root supervisor for hecate-parksim-simulator.
-module(hecate_parksim_simulator_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        %% Cowboy listener — small HTTP admin surface (/health + /api/run + /api/event + /api/evacuate).
        cowboy_child(),
        %% The actual simulation runs in `simulate_arrivals_sup` (one
        %% gen_server per lot) and `simulate_pricing_sup` (one rates +
        %% one permits cadence gen_server). Sessions are short-lived
        %% processes spawned by the arrivals gen_server.
        #{id => simulate_arrivals_sup,
          start => {simulate_arrivals_sup, start_link, []},
          restart => permanent, shutdown => 5000,
          type => supervisor, modules => [simulate_arrivals_sup]},
        #{id => simulate_lots_sup,
          start => {simulate_lots_sup, start_link, []},
          restart => permanent, shutdown => 5000,
          type => supervisor, modules => [simulate_lots_sup]},
        #{id => simulate_pricing_sup,
          start => {simulate_pricing_sup, start_link, []},
          restart => permanent, shutdown => 5000,
          type => supervisor, modules => [simulate_pricing_sup]}
    ],
    {ok, {SupFlags, Children}}.

cowboy_child() ->
    Port = application:get_env(hecate_parksim_simulator, http_port, 8473),
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/health", hecate_om_health_handler, []},
            {"/api/run",      hecate_parksim_simulator_admin_api, [run]},
            {"/api/event",    hecate_parksim_simulator_admin_api, [event]},
            {"/api/evacuate", hecate_parksim_simulator_admin_api, [evacuate]}
        ]}
    ]),
    #{id => cowboy_listener,
      start => {cowboy, start_clear, [
          hecate_parksim_simulator_http_listener,
          [{port, Port}],
          #{env => #{dispatch => Dispatch}}
      ]},
      restart => permanent, shutdown => 5000,
      type => worker, modules => [cowboy]}.
