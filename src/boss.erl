-module(boss).
-export([
    start/1,
    start/2,
    boss_init/2
]).

-define(DEFAULT_BATCH_SIZE, 50000).
-define(DEFAULT_PREFIX, <<"koppa;">>).

%% @doc Start the Boss actor with K leading zeros and default prefix.
-spec start(pos_integer()) -> pid().
start(K) ->
    start(K, ?DEFAULT_PREFIX).

%% @doc Start the Boss actor with K leading zeros and custom prefix.
-spec start(pos_integer(), binary() | string()) -> pid().
start(K, Prefix) when is_list(Prefix) ->
    start(K, list_to_binary(Prefix));
start(K, Prefix) when is_binary(Prefix), is_integer(K), K >= 1 ->
    Pid = spawn(fun() -> boss_init(K, Prefix) end),
    Pid.

%% @doc Initialize Boss actor, register name, and spawn local workers.
boss_init(K, Prefix) ->
    case whereis(boss) of
        undefined ->
            register(boss, self());
        ExistingPid when ExistingPid =/= self() ->
            unregister(boss),
            register(boss, self())
    end,
    
    NumCores = erlang:system_info(schedulers_online),
    
    % Random starting index to avoid repeating across restarts
    <<RandInt:32/unsigned>> = crypto:strong_rand_bytes(4),
    StartIndex = RandInt * 1000,
    
    % Spawn local worker actors
    worker:start_pool(self(), NumCores),
    
    boss_loop(K, Prefix, StartIndex, ?DEFAULT_BATCH_SIZE, 0).

%% @doc Boss actor event loop.
boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound) ->
    receive
        {get_work, WorkerPid} ->
            WorkerPid ! {work, Prefix, CurrentIndex, BatchSize, K},
            boss_loop(K, Prefix, CurrentIndex + BatchSize, BatchSize, CoinsFound);

        {coin_found, InputStr, HexHash} ->
            % Output format strictly matching assignment specification:
            % <input string>\t<sha256 hash>
            io:format("~s\t~s~n", [InputStr, HexHash]),
            boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound + 1);

        {status, From} ->
            From ! {status, #{
                k => K,
                current_index => CurrentIndex,
                coins_found => CoinsFound
            }},
            boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound);

        stop ->
            ok;

        _Other ->
            boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound)
    end.
