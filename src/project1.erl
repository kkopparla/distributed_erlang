-module(project1).
-export([
    main/1,
    start_server/1,
    start_server/2,
    start_worker/1
]).

-define(DEFAULT_PREFIX, <<"koppa;">>).

%% @doc Main entry point called by `erl -run project1 main ...`
main([]) ->
    io:format("Usage:~n"),
    io:format("  Server mode: project1 <leading_zeros> [prefix]~n"),
    io:format("  Worker mode: project1 <server_ip_or_node>~n"),
    init:stop(1);

main([Arg | Rest]) ->
    ArgStr = ensure_string(Arg),
    case is_integer_string(ArgStr) of
        true ->
            K = list_to_integer(ArgStr),
            Prefix = case Rest of
                [CustomPrefix | _] ->
                    format_prefix(ensure_string(CustomPrefix));
                [] ->
                    ?DEFAULT_PREFIX
            end,
            start_server(K, Prefix);
        false ->
            start_worker(ArgStr)
    end.

%% @doc Start the server on this node.
start_server(K) ->
    start_server(K, ?DEFAULT_PREFIX).

start_server(K, Prefix) ->
    BossPid = boss:start(K, Prefix),
    Ref = erlang:monitor(process, BossPid),
    receive
        {'DOWN', Ref, process, BossPid, Reason} ->
            io:format("Boss terminated: ~p~n", [Reason])
    end.

%% @doc Start a worker on this node connecting to the given server IP or node name.
start_worker(ServerHostOrNode) ->
    ServerNode = parse_server_node(ServerHostOrNode),
    wait_and_connect(ServerNode, 10),
    NumCores = erlang:system_info(schedulers_online),
    WorkerPids = worker:start_pool({boss, ServerNode}, NumCores),
    % Monitor first worker or wait indefinitely
    [FirstWorker | _] = WorkerPids,
    Ref = erlang:monitor(process, FirstWorker),
    receive
        {'DOWN', Ref, process, FirstWorker, _} ->
            ok
    end.

%% @doc Attempt to ping and connect to the server node with retries.
wait_and_connect(_ServerNode, 0) ->
    % Fail quietly or stop
    init:stop(1);
wait_and_connect(ServerNode, Retries) ->
    case net_adm:ping(ServerNode) of
        pong ->
            ok;
        pang ->
            timer:sleep(1000),
            wait_and_connect(ServerNode, Retries - 1)
    end.

%% @doc Parse IP or node name into an atom.
parse_server_node(Str) ->
    case lists:member($@, Str) of
        true ->
            list_to_atom(Str);
        false ->
            list_to_atom("server@" ++ Str)
    end.

%% @doc Format prefix ensuring it ends with ';' if not already present.
format_prefix(Str) ->
    Trimmed = string:strip(Str),
    case lists:suffix(";", Trimmed) of
        true -> list_to_binary(Trimmed);
        false -> list_to_binary(Trimmed ++ ";")
    end.

%% @doc Helper to check if a string represents a positive integer.
is_integer_string([]) -> false;
is_integer_string(Str) ->
    lists:all(fun(C) -> C >= $0 andalso C =< $9 end, Str).

%% @doc Ensure term is a list/string.
ensure_string(Atom) when is_atom(Atom) -> atom_to_list(Atom);
ensure_string(Bin) when is_binary(Bin) -> binary_to_list(Bin);
ensure_string(List) when is_list(List) -> List.
