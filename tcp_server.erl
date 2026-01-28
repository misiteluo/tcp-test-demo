-module(tcp_server).
-export([start/0]).

%% 对外启动入口
start() ->
    Port = 9000,
    {ok, ListenSocket} = gen_tcp:listen(
        Port,
        [binary,                 % 收发二进制
         {packet, 0},            % 不使用内置分包，自己处理粘包
         {reuseaddr, true},
         {active, false}]        % 被动模式，自己调用 recv
    ),
    io:format("Server listening on port ~p~n", [Port]),
    accept_loop(ListenSocket).

%% 接受连接循环
accept_loop(ListenSocket) ->
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    io:format("Client connected~n", []),
    %% 为每个客户端启动一个进程处理
    spawn(fun() -> handle_client(Socket) end),
    accept_loop(ListenSocket).

%% 单个客户端处理
handle_client(Socket) ->
    %% 初始 buffer 为空二进制
    recv_loop(Socket, <<>>).

%% 接收循环 + 粘包拆包
recv_loop(Socket, Buffer) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            %% 将新数据拼到旧 buffer 后面
            NewBuffer = <<Buffer/binary, Data/binary>>,
            handle_buffer(Socket, NewBuffer);
        {error, closed} ->
            io:format("Client closed~n", []);
        {error, Reason} ->
            io:format("Recv error: ~p~n", [Reason])
    end.

%% 处理 buffer 中可能包含的 0~多条完整消息
handle_buffer(Socket, Buffer) when byte_size(Buffer) < 4 ->
    %% 不够 4 字节长度头，继续收
    recv_loop(Socket, Buffer);
handle_buffer(Socket, Buffer) ->
    %% 先读出长度头
    case Buffer of
        <<Len:32/big, Rest/binary>> ->
            case byte_size(Rest) >= Len of
                true ->
                    %% Rest 至少包含一条完整消息
                    <<MsgBin:Len/binary, Left/binary>> = Rest,
                    io:format("Server got msg: ~p~n", [MsgBin]),
                    %% 简单 echo: 原样回发
                    ok = gen_tcp:send(Socket, <<Len:32/big, MsgBin/binary>>),
                    %% 继续解析剩余的 Left（可能还有粘在后面的多条消息）
                    handle_buffer(Socket, Left);
                false ->
                    %% 半包：还没收够 Len 字节的内容，继续收
                    recv_loop(Socket, Buffer)
            end
    end.