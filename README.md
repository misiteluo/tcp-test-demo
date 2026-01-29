# TCP Socket 通信 Demo

这是一个基于 TCP Socket 的跨语言通信示例项目，使用 **Erlang** 实现服务端，**Python** 实现客户端，演示了自定义协议和粘包拆包处理。

## 项目简介

本项目展示了如何：
- 使用 Erlang 构建 TCP 服务端
- 使用 Python 构建 TCP 客户端
- 实现自定义二进制协议（长度头 + 消息体）
- 正确处理 TCP 粘包和拆包问题

## 协议设计

### 消息格式

每条消息由两部分组成：
```
[4字节长度头(大端序)] + [消息内容(UTF-8编码)]
```

- **长度头**：4 字节无符号整数（大端序），表示消息内容的字节数
- **消息内容**：UTF-8 编码的文本数据

### 示例

发送消息 "hello"：
```
长度头: 0x00000005 (5字节)
消息体: "hello"
完整包: [0x00, 0x00, 0x00, 0x05, 'h', 'e', 'l', 'l', 'o']
```

## 文件结构

```
.
├── tcp_server.erl    # Erlang 服务端
├── client.py         # Python 客户端
└── README.md         # 项目说明文档
```

## 环境要求

### Erlang 服务端
- Erlang/OTP 20.0 或更高版本

### Python 客户端
- Python 3.6 或更高版本
- 无需额外依赖（仅使用标准库）

## 使用方法

### 1. 启动 Erlang 服务端

在终端中进入项目目录，启动 Erlang 交互式 shell：

```bash
erl
```

然后编译并启动服务端：

```erlang
c(tcp_server).
tcp_server:start().
```

看到输出 `Server listening on port 9000` 表示服务端已成功启动。

### 2. 启动 Python 客户端

在另一个终端中运行：

```bash
python client.py
```

客户端会自动连接到服务端（`127.0.0.1:9000`），并发送三条测试消息。

### 3. 交互使用

客户端启动后，你可以：
- 在 Python 终端中输入消息，按回车发送
- 服务端会回显（echo）收到的消息
- 使用 `Ctrl+C` 退出客户端

## 粘包拆包处理原理

### 问题说明

TCP 是流式协议，发送的数据可能会：
- **粘包**：多条消息被合并成一个 TCP 包
- **拆包**：一条消息被拆分成多个 TCP 包
- **半包**：一条消息的一部分到达，另一部分还在传输中

### 解决方案

#### Erlang 服务端

1. 使用 `{packet, 0}` 和 `{active, false}` 模式，手动控制数据接收
2. 维护一个缓冲区（Buffer），累积接收到的数据
3. 循环处理缓冲区：
   - 检查是否有至少 4 字节（长度头）
   - 解析长度头，获取消息体长度
   - 检查缓冲区是否有完整的消息体
   - 如果有完整消息，提取并处理，继续处理剩余数据
   - 如果数据不足，继续接收

#### Python 客户端

客户端也实现了类似的粘包拆包处理：
- 接收线程维护缓冲区
- 循环解析完整消息
- 确保即使数据分批到达也能正确重组

## 代码示例

### Erlang 服务端关键代码

```erlang
handle_buffer(Socket, Buffer) when byte_size(Buffer) < 4 ->
    recv_loop(Socket, Buffer);
handle_buffer(Socket, Buffer) ->
    case Buffer of
        <<Len:32/big, Rest/binary>> ->
            case byte_size(Rest) >= Len of
                true ->
                    <<MsgBin:Len/binary, Left/binary>> = Rest,
                    %% 处理完整消息
                    handle_buffer(Socket, Left);
                false ->
                    %% 半包，继续接收
                    recv_loop(Socket, Buffer)
            end
    end.
```

### Python 客户端关键代码

```python
def decode_stream(sock: socket.socket):
    buffer = b""
    while True:
        data = sock.recv(1024)
        buffer += data
        
        while len(buffer) >= 4:
            length = struct.unpack("!I", buffer[:4])[0]
            if len(buffer) < 4 + length:
                break  # 半包，等待更多数据
            body = buffer[4:4 + length]
            buffer = buffer[4 + length:]
            # 处理完整消息
```

## 测试建议

1. **正常通信测试**：启动服务端和客户端，观察消息正常收发
2. **粘包测试**：快速连续发送多条消息，验证服务端能正确拆分
3. **半包测试**：可以修改客户端代码，将一个消息分多次发送，验证服务端能正确重组
4. **多客户端测试**：启动多个客户端，验证服务端能并发处理

## 扩展建议

- 添加 JSON 格式的消息体，支持结构化数据
- 实现命令路由机制（如 `{"cmd": "echo", "data": "xxx"}`）
- 添加超时处理和错误重连机制
- 实现心跳机制保持连接
- 添加日志记录功能

## 注意事项

- 服务端默认监听端口 `9000`，确保端口未被占用
- Erlang 服务端使用进程模型，每个客户端连接由独立进程处理
- 本示例为教学演示，生产环境需要考虑更多错误处理和性能优化

## 许可证

本项目仅供学习和参考使用。
