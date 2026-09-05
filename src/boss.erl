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
    
    boss_loop(K, Prefix, StartIndex, ?DEFAULT_BATCH_SIZE, 0, sets:new()).

%% @doc Boss actor event loop.
boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound, KnownNodes) ->
    receive
        {get_work, WorkerPid} ->
            WorkerNode = node(WorkerPid),
            NewKnownNodes = case sets:is_element(WorkerNode, KnownNodes) of
                false ->
                    case WorkerNode of
                        Local when Local =:= node() ->
                            ok;
                        RemoteNode ->
                            io:format("~n>>> [REMOTE WORKER JOINED] ~p connected and participating in mining! <<<~n~n", [RemoteNode])
                    end,
                    sets:add_element(WorkerNode, KnownNodes);
                true ->
                    KnownNodes
            end,
            WorkerPrefix = case WorkerNode of
                LocalNode when LocalNode =:= node() ->
                    <<Prefix/binary, "server;">>;
                Remote ->
                    RemoteBin = list_to_binary(atom_to_list(Remote)),
                    <<Prefix/binary, RemoteBin/binary, ";">>
            end,
            WorkerPid ! {work, WorkerPrefix, CurrentIndex, BatchSize, K},
            boss_loop(K, Prefix, CurrentIndex + BatchSize, BatchSize, CoinsFound, NewKnownNodes);

        {coin_found, InputStr, HexHash} ->
            % Output format strictly matching assignment specification:
            % <input string>\t<sha256 hash>
            io:format("~s\t~s~n", [InputStr, HexHash]),
            boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound + 1, KnownNodes);

        {status, From} ->
            From ! {status, #{
                k => K,
                current_index => CurrentIndex,
                coins_found => CoinsFound,
                nodes => sets:to_list(KnownNodes)
            }},
            boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound, KnownNodes);

        stop ->
            ok;

        _Other ->
            boss_loop(K, Prefix, CurrentIndex, BatchSize, CoinsFound, KnownNodes)
    end.
