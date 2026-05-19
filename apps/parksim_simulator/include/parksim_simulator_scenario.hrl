%%% @doc Scenario records — lot variants + presets.

-record(parksim_lot, {
    id              :: binary(),
    display_name    :: binary(),
    profile         :: city_centre | station | residential,
    capacity        :: non_neg_integer(),
    dwell_median_s  :: number(),
    dwell_mu        :: float(),
    dwell_sigma     :: float(),
    permit_share    :: float()
}).

-record(parksim_preset, {
    name                 :: binary(),
    lots = []            :: [#parksim_lot{}],
    avg_sessions_per_day :: non_neg_integer(),
    peak_lambda_per_min  :: float(),
    permit_roster_size   :: non_neg_integer(),
    plate_pool_size      :: non_neg_integer()
}).
