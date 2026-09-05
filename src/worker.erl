-module(worker).
-export([
    start_pool/2,
    worker_init/2
]).

%% @doc Start a pool of worker actors targeting the given Boss process.
%% BossTarget can be a local pid or {boss, ServerNode}.
-spec start_pool(term(), pos_integer()) -> [pid()].
start_pool(BossTarget, NumWorkers) when NumWorkers > 0 ->
    [spawn(fun() -> worker_init(BossTarget, Id) end) || Id <- lists:seq(1, NumWorkers)].

%% @doc Worker actor entry point.
worker_init(BossTarget, _WorkerId) ->
    worker_loop(BossTarget).

%% @doc Worker actor event loop.
worker_loop(BossTarget) ->
    % Request a batch of work from the Boss
    BossTarget ! {get_work, self()},
    receive
        {work, Prefix, StartIndex, BatchSize, K} ->
            mine_range(BossTarget, Prefix, StartIndex, StartIndex + BatchSize - 1, K),
            worker_loop(BossTarget);
        {stop} ->
            ok;
        _Other ->
            worker_loop(BossTarget)
    end.

%% @doc Mine strings sequentially in the assigned range [Current, End].
mine_range(_BossTarget, _Prefix, Current, End, _K) when Current > End ->
    ok;
mine_range(BossTarget, Prefix, Current, End, K) ->
    InputBin = miner_util:generate_input(Prefix, Current),
    Hash = miner_util:sha256(InputBin),
    case miner_util:has_leading_zeros(Hash, K) of
        true ->
            HexHash = miner_util:to_hex(Hash),
            InputStr = binary_to_list(InputBin),
            BossTarget ! {coin_found, InputStr, HexHash};
        false ->
            ok
    end,
    mine_range(BossTarget, Prefix, Current + 1, End, K).
