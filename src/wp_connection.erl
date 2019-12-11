%%%-------------------------------------------------------------------
%% @doc Wolfpack Connection
%%
%%
%%
%% @end
%%%-------------------------------------------------------------------

-module(wp_connection).
-behaviour(gen_server).
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/4]).

%% Behaviour
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3]).

%%-----------------------------------------------------------------------------
%% API
%%------------------------------------------------------------------------------

start_link(_Ref, Socket, Transport, Opts) ->
    gen_server:start_link(?MODULE, [Socket, Transport, Opts], []).

%%-----------------------------------------------------------------------------
%% Behaviour callbacks
%%------------------------------------------------------------------------------

-record(state, {socket,
		transport,
		data = <<>>
	       }).

%% @hidden
init([Socket, Transport, _Opts = []]) ->
    Transport:setopts(Socket, [{active, true}]),
    {ok, #state{socket=Socket, transport=Transport}}.

%% @hidden
handle_call(What, _From, State) ->
    lager:warning("unhandle call ~p", [What]),
    {reply, {error, What}, State}.

%% @hidden
handle_cast(What, State) ->
    lager:warning("unhandle cast ~p", [What]),
    {noreply, State}.

%% @hidden
handle_info({tcp_closed, _Port}, State) ->
    lager:debug("connection closed"),
    {stop, normal, State};

handle_info({tcp, _Port, DataNew}, State0=#state{data=DataOld}) ->
    Data = <<DataOld/binary, DataNew/binary>>,
    case complete(Data) of
	{true, Size, Package} ->
	    lager:warning("~p ~p", [Size, Package]),
	    {noreply, State0#state{data=Data}};
	{false, Data} ->
	    {noreply, State0#state{data=Data}}
    end;

handle_info({handshake, wolfpack, _, _, _}, State) ->
    {noreply, State};

handle_info(What, State) ->
    lager:warning("unhandle info ~p", [What]),
    {noreply, State}.

%% @hidden
terminate(_Reason, _State) ->
    ok.

%% @hidden
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%------------------------------------------------------------------------------
%% Private
%%------------------------------------------------------------------------------

complete(<<1, 0:16, 0:16, Size:32, Rest/binary>>) ->
    {Size >= byte_size(Rest), Size, Rest};
complete(Data) ->
    {false, Data}.

%%------------------------------------------------------------------------------
%% Test
%%------------------------------------------------------------------------------
