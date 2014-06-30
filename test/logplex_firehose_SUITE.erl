%%%-------------------------------------------------------------------
%% @copyright Heroku, 2014
%% @author Alex Arnell <alex@heroku.com>
%% @doc CommonTest test suite for logplex_firehose
%% @end
%%%-------------------------------------------------------------------

-module(logplex_firehose_SUITE).
-include_lib("common_test/include/ct.hrl").
-compile(export_all).

all() ->
    [set_env].

%%%%%%%%%%%%%%%%%%%%%%
%%% Setup/Teardown %%%
%%%%%%%%%%%%%%%%%%%%%%
%% Runs once at the beginning of the suite. The process is different
%% from the one the case will run in.
init_per_suite(Config) ->
    Config.

%% Runs once at the end of the suite. The process is different
%% from the one the case will run in.
end_per_suite(Config) ->
    Config.

%% Runs before the test case. Runs in the same process.
init_per_testcase(_, Config) ->
    Config.

%% Runs after the test case. Runs in the same process.
end_per_testcase(_CaseName, Config) ->
    Config.

%%%%%%%%%%%%%
%%% TESTS %%%
%%%%%%%%%%%%%

set_env(_Config) ->
    FirehoseChannelId = 21894100,
    ChannelId = 21894100,

    logplex_firehose:create_ets_tables(),
    logplex_firehose:read_and_store_master_info(),

    undefined = logplex_firehose:next_shard(ChannelId),
    undefined = logplex_firehose:next_shard(ChannelId),

    application:set_env(logplex, firehose_channel_ids, lists:concat([FirehoseChannelId])),
    logplex_firehose:read_and_store_master_info(),

    FirehoseChannelId = logplex_firehose:next_shard(ChannelId),
    ok.

