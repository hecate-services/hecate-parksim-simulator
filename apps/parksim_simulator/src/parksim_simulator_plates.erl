%%% @doc Pool of Belgian-format licence plates with regular/casual split.
%%% See PLAN_PARKSIM_TRAFFIC_MODEL.md §8.
-module(parksim_simulator_plates).

-export([new_pool/2, draw/2]).

-export_type([plate/0, pool/0]).

-type plate() :: #{value := binary(), regular := boolean(),
                   customer_id := binary() | undefined}.
-type pool() :: [plate()].

-define(REGULAR_SHARE, 0.20).
-define(REGULAR_WEIGHT, 5).

%% @doc Build N unique plates. ~20% marked as regulars with a customer id.
-spec new_pool(rand:state(), pos_integer()) -> {pool(), rand:state()}.
new_pool(RngState, N) when N > 0 ->
    new_pool(RngState, N, #{}, []).

new_pool(RngState, 0, _Seen, Acc) ->
    {lists:reverse(Acc), RngState};
new_pool(RngState, N, Seen, Acc) ->
    {Value, S1} = random_plate(RngState),
    case maps:is_key(Value, Seen) of
        true ->
            new_pool(S1, N, Seen, Acc);
        false ->
            {U, S2} = rand:uniform_s(S1),
            {Plate, S3} = case U < ?REGULAR_SHARE of
                true ->
                    {Cust, SS} = random_customer_id(S2),
                    {#{value => Value, regular => true, customer_id => Cust}, SS};
                false ->
                    {#{value => Value, regular => false, customer_id => undefined}, S2}
            end,
            new_pool(S3, N - 1, Seen#{Value => ok}, [Plate | Acc])
    end.

%% @doc Draw one plate weighted toward regulars (~5×).
-spec draw(rand:state(), pool()) -> {plate(), rand:state()}.
draw(RngState, []) ->
    {#{value => <<"1-ABC-234">>, regular => false, customer_id => undefined}, RngState};
draw(RngState, Pool) ->
    Total = lists:foldl(
        fun(P, Acc) ->
            case maps:get(regular, P) of
                true  -> Acc + ?REGULAR_WEIGHT;
                false -> Acc + 1
            end
        end, 0, Pool),
    {U, S1} = rand:uniform_s(Total, RngState),
    {pick_weighted(U, Pool, 0), S1}.

pick_weighted(_U, [P], _Cum) -> P;
pick_weighted(U, [P | Rest], Cum) ->
    W = case maps:get(regular, P) of true -> ?REGULAR_WEIGHT; false -> 1 end,
    case U =< Cum + W of
        true  -> P;
        false -> pick_weighted(U, Rest, Cum + W)
    end.

random_plate(RngState) ->
    {Lead, S1} = rand:uniform_s(9, RngState),       %% 1..9
    {L1, S2}   = rand:uniform_s(26, S1),
    {L2, S3}   = rand:uniform_s(26, S2),
    {L3, S4}   = rand:uniform_s(26, S3),
    {Tail, S5} = rand:uniform_s(900, S4),
    Letters = list_to_binary([$A + L1 - 1, $A + L2 - 1, $A + L3 - 1]),
    Value = iolist_to_binary(
        io_lib:format("~B-~s-~B", [Lead, Letters, Tail + 99])),
    {Value, S5}.

random_customer_id(RngState) ->
    %% 16 random bytes hex-encoded — close enough to a UUID for the demo.
    {Bytes, S1} = rand_bytes_s(16, RngState),
    Hex = lists:flatten([io_lib:format("~2.16.0B", [B]) || <<B>> <= Bytes]),
    {iolist_to_binary(Hex), S1}.

rand_bytes_s(N, RngState) ->
    rand_bytes_s(N, RngState, <<>>).
rand_bytes_s(0, RngState, Acc) -> {Acc, RngState};
rand_bytes_s(N, RngState, Acc) ->
    {B, S1} = rand:uniform_s(256, RngState),
    rand_bytes_s(N - 1, S1, <<Acc/binary, (B - 1)>>).
