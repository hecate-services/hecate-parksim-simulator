%%% @doc OSRM road-routing client for the fleet simulator.
%%%
%%% `route_leg/2` asks the local OSRM sidecar (osrm-routed, MLD) for the
%%% driving route between two points and returns the road polyline plus its
%%% real distance and duration. If OSRM is unreachable or replies oddly, it
%%% falls back to a straight line (haversine × a detour fudge) so the sim
%%% always gets a usable leg — a router outage only degrades visual realism,
%%% never blocks the fleet.
%%%
%%% Coordinate convention: callers pass `{Lat, Lng}` (the order used
%%% everywhere else in the sim). OSRM speaks `lon,lat`, so we swap at the
%%% wire boundary here and nowhere else. The returned polyline is a list of
%%% `{Lat, Lng}` points, ready to animate a vehicle along.
%%%
%%% Lives in parksim_simulator (shared infra) so both the fleet brain and
%%% any tooling can route.
-module(route_leg).

-export([route/2, osrm_url/0]).
%% Geometry helpers reused by the fleet brain (simulate_fleet_core).
-export([haversine_m/2, interpolate/3]).

-type point() :: {number(), number()}.   %% {Lat, Lng}
-type leg() :: #{distance_m := float(),
                 duration_s := float(),
                 polyline   := [point()],
                 source     := osrm | straight}.
-export_type([point/0, leg/0]).

%% City driving speed assumed for the straight-line fallback (~28 km/h).
-define(FALLBACK_SPEED_MPS, 7.8).
%% Roads are longer than the crow flies; pad the straight-line distance.
-define(DETOUR_FACTOR, 1.3).
%% Keep the HTTP call short — the sim ticks frequently and has a fallback.
-define(HTTP_TIMEOUT_MS, 1500).

%% @doc Route From -> To over real roads via OSRM, or straight-line on
%% failure. Never errors: always returns a usable leg.
-spec route(point(), point()) -> leg().
route(From, To) ->
    case query_osrm(From, To) of
        {ok, Leg}       -> Leg;
        {error, _Reason} -> straight_line(From, To)
    end.

%% @doc The OSRM base URL: OSRM_URL env var, else app env, else localhost.
-spec osrm_url() -> string().
osrm_url() ->
    case os:getenv("OSRM_URL") of
        false -> application:get_env(hecate_parksim, osrm_url, "http://127.0.0.1:5000");
        ""    -> application:get_env(hecate_parksim, osrm_url, "http://127.0.0.1:5000");
        Url   -> Url
    end.

%%--------------------------------------------------------------------
%% OSRM

query_osrm({FromLat, FromLng}, {ToLat, ToLng}) ->
    %% OSRM wants lon,lat;lon,lat. full+geojson gives a road polyline.
    Coords = io_lib:format("~f,~f;~f,~f", [FromLng, FromLat, ToLng, ToLat]),
    Url = lists:flatten([osrm_url(),
                         "/route/v1/driving/", Coords,
                         "?overview=full&geometries=geojson"]),
    try httpc:request(get, {Url, []},
                      [{timeout, ?HTTP_TIMEOUT_MS}, {connect_timeout, ?HTTP_TIMEOUT_MS}],
                      [{body_format, binary}]) of
        {ok, {{_, 200, _}, _Headers, Body}} -> parse_osrm(Body);
        {ok, {{_, Status, _}, _, _}}        -> {error, {http_status, Status}};
        {error, Reason}                     -> {error, Reason}
    catch
        _:Err -> {error, Err}
    end.

parse_osrm(Body) ->
    try jsx:decode(Body, [return_maps]) of
        #{<<"code">> := <<"Ok">>, <<"routes">> := [Route | _]} ->
            #{<<"distance">> := Dist,
              <<"duration">> := Dur,
              <<"geometry">> := #{<<"coordinates">> := Coords}} = Route,
            Polyline = [{Lat, Lng} || [Lng, Lat] <- Coords],   %% lon,lat -> {lat,lng}
            {ok, #{distance_m => to_float(Dist),
                   duration_s => to_float(Dur),
                   polyline   => Polyline,
                   source     => osrm}};
        #{<<"code">> := Code} ->
            {error, {osrm_code, Code}};
        _ ->
            {error, osrm_unexpected_shape}
    catch
        _:Err -> {error, {osrm_parse, Err}}
    end.

%%--------------------------------------------------------------------
%% Straight-line fallback

straight_line(From, To) ->
    Crow = haversine_m(From, To),
    Dist = Crow * ?DETOUR_FACTOR,
    #{distance_m => Dist,
      duration_s => Dist / ?FALLBACK_SPEED_MPS,
      polyline   => [From, To],
      source     => straight}.

%% Great-circle distance in metres between two {Lat, Lng} points.
haversine_m({Lat1, Lng1}, {Lat2, Lng2}) ->
    R = 6371000.0,
    P1 = deg2rad(Lat1),
    P2 = deg2rad(Lat2),
    DP = deg2rad(Lat2 - Lat1),
    DL = deg2rad(Lng2 - Lng1),
    A = math:sin(DP / 2) * math:sin(DP / 2)
        + math:cos(P1) * math:cos(P2) * math:sin(DL / 2) * math:sin(DL / 2),
    C = 2 * math:atan2(math:sqrt(A), math:sqrt(1 - A)),
    R * C.

deg2rad(D) -> D * math:pi() / 180.0.

%% @doc The point a fraction `F' (0..1) of the way from A to B. Linear in
%% lat/lng — accurate enough at city scale for animating a vehicle along a
%% short polyline segment.
-spec interpolate(point(), point(), float()) -> point().
interpolate({Lat1, Lng1}, {Lat2, Lng2}, F) ->
    {Lat1 + (Lat2 - Lat1) * F, Lng1 + (Lng2 - Lng1) * F}.

to_float(N) when is_integer(N) -> float(N);
to_float(N) when is_float(N)   -> N.
