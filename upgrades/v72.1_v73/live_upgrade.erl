f(DowngradeNode).
DowngradeNode = fun () ->
    CurVsn = "firehose-spike",
    NextVsn = "v72",
    case logplex_app:config(git_branch) of
        CurVsn ->
            io:format(whereis(user), "at=upgrade_start cur_vsn=~p~n", [tl(CurVsn)]);
        NextVsn ->
            io:format(whereis(user),
                      "at=upgrade type=retry cur_vsn=~p old_vsn=~p~n", [tl(CurVsn), tl(NextVsn)]);
        Else ->
            io:format(whereis(user),
                      "at=upgrade_start old_vsn=~p abort=wrong_version", [tl(Else)]),
            erlang:error({wrong_version, Else})
    end,

    %% Stateless

    {module, logplex_app} = l(logplex_app),
    {module, logplex_db} = l(logplex_db),
    {module, logplex_message} = l(logplex_message),
    {module, logplex_stats} = l(logplex_stats),
    {module, logplex_worker} = l(logplex_worker),
    {module, nsync_callback} = l(nsync_callback),

    application:unset_env(logplex, firehose_channel_ids),

    ets:delete(firehose_workers),
    ets:delete(firehose_master),

    io:format(whereis(user), "at=upgrade_end cur_vsn=~p~n", [NextVsn]),
    ok = application:set_env(logplex, git_branch, NextVsn),
    ok
end.

f(UpgradeNode).
UpgradeNode = fun () ->
    CurVsn = "v73",
    NextVsn = "firehose-spike",
    case logplex_app:config(git_branch) of
        CurVsn ->
            io:format(whereis(user), "at=upgrade_start cur_vsn=~p~n", [tl(CurVsn)]);
        NextVsn ->
            io:format(whereis(user),
                      "at=upgrade type=retry cur_vsn=~p old_vsn=~p~n", [tl(CurVsn), tl(NextVsn)]);
        Else ->
            io:format(whereis(user),
                      "at=upgrade_start old_vsn=~p abort=wrong_version", [tl(Else)]),
            erlang:error({wrong_version, Else})
    end,

    %% Stateless

    {module, logplex_app} = l(logplex_app),
    {module, logplex_db} = l(logplex_db),
    {module, logplex_firehose} = l(logplex_firehose),
    {module, logplex_message} = l(logplex_message),
    {module, logplex_stats} = l(logplex_stats),
    {module, logplex_worker} = l(logplex_worker),
    {module, nsync_callback} = l(nsync_callback),

    spawn(fun () ->
        ets:new(firehose_master,
                [named_table, public, set,
                 {keypos, 2},
                 {read_concurrency, true},
                 {heir, whereis(logplex_db), undefined}]),
        ets:new(firehose_workers,
                [named_table, public, set,
                 {keypos, 1},
                 {read_concurrency, true},
                 {heir, whereis(logplex_db), undefined}])
    end),

    io:format(whereis(user), "at=upgrade_end cur_vsn=~p~n", [NextVsn]),
    ok = application:set_env(logplex, git_branch, NextVsn),
    ok
end.

f(NodeVersions).
NodeVersions = fun () ->
    lists:keysort(3,
                  [{N,
                    element(2, rpc:call(N, application, get_env, [logplex, git_branch])),
                    rpc:call(N, os, getenv, ["INSTANCE_NAME"])}
                   || N <- [node() | nodes()] ])
end.

f(NodesAt).
NodesAt = fun (Vsn) ->
    [ N || {N, V, _} <- NodeVersions(), V =:= Vsn ]
end.

f(RollingDowngrade).
RollingDowngrade = fun (Nodes) ->
  lists:foldl(fun (N, {good, Downgraded}) ->
    case rpc:call(N, erlang, apply, [ DowngradeNode, [] ]) of
      ok ->
        {good, [N | Downgraded]};
      Else ->
        {{bad, N, Else}, Downgraded}
    end;
    (N, {_, _} = Acc) -> Acc
    end,
    {good, []},
    Nodes)
end.

f(RollingUpgrade).
RollingUpgrade = fun (Nodes) ->
  lists:foldl(fun (N, {good, Upgraded}) ->
    case rpc:call(N, erlang, apply, [ UpgradeNode, [] ]) of
      ok ->
        {good, [N | Upgraded]};
      Else ->
        {{bad, N, Else}, Upgraded}
    end;
    (N, {_, _} = Acc) -> Acc
    end,
    {good, []},
    Nodes)
end.


f(Activate).
Activate = fun () ->
    application:set_env(logplex, firehose_channel_ids, erlang:error("replace with comma separated list of channel IDs")),
    ok = logplex_firehose:read_and_store_master_info(),
    ok
end.
f(RollingActivate).
RollingActivate = fun (Nodes) ->
  lists:foldl(fun (N, {good, Activated}) ->
    case rpc:call(N, erlang, apply, [ Activate, [] ]) of
      ok ->
        {good, [N | Activated]};
      Else ->
        {{bad, N, Else}, Activated}
    end;
    (N, {_, _} = Acc) -> Acc
    end,
    {good, []},
    Nodes)
end.


f(Deactivate).
Deactivate = fun () ->
    application:unset_env(logplex, firehose_channel_ids),
    ok
end.
f(RollingDeactivate).
RollingDeactivate = fun (Nodes) ->
  lists:foldl(fun (N, {good, Deactivated}) ->
    case rpc:call(N, erlang, apply, [ Deactivate, [] ]) of
      ok ->
        {good, [N | Deactivated]};
      Else ->
        {{bad, N, Else}, Deactivated}
    end;
    (N, {_, _} = Acc) -> Acc
    end,
    {good, []},
    Nodes)
end.
