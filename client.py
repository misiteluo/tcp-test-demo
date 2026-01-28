import socket
import struct
import threading


def encode_message(text: str) -> bytes:
    body = text.encode("utf-8")
    length = len(body)
    # 4 字节大端长度 + 内容
    return struct.pack("!I", length) + body


def decode_stream(sock: socket.socket):
    """
    从 socket 中读取数据，演示在客户端侧也做一次“粘包拆包”，
    方便理解（其实只要一端按协议处理就够了）。
    """
    buffer = b""
    while True:
        try:
            data = sock.recv(1024)
        except ConnectionResetError:
            print("连接被服务器重置")
            break

        if not data:
            print("服务器已关闭连接")
            break

        buffer += data

        # 尝试从 buffer 中不停解析完整包
        while True:
            if len(buffer) < 4:
                # 不够一个长度头
                break
            length = struct.unpack("!I", buffer[:4])[0]
            if len(buffer) < 4 + length:
                # 半包，等待更多数据
                break
            body = buffer[4:4 + length]
            buffer = buffer[4 + length:]

            print("从服务器收到消息:", body.decode("utf-8"))


def main():
    host = "127.0.0.1"
    port = 9000

    sock = socket.create_connection((host, port))
    print("已连接到服务器")

    # 开一个线程专门接收数据（也处理粘包拆包）
    t = threading.Thread(target=decode_stream, args=(sock,), daemon=True)
    t.start()

    # 连续发几条消息，模拟可能的粘包场景
    messages = [
        "hello, erlang server!",
        "第二条消息，看看会不会粘在一起",
        "第三条，再试一次",
    ]

    for msg in messages:
        packed = encode_message(msg)
        # 故意快速连续发送，增加粘包概率
        sock.sendall(packed)
        print("已发送:", msg)

    # 进入简单交互模式：你可以手动输入要发的消息
    try:
        while True:
            text = input("输入要发送的内容(回车发送, Ctrl+C 退出): ").strip()
            if not text:
                continue
            sock.sendall(encode_message(text))
    except KeyboardInterrupt:
        print("\n客户端退出")
    finally:
        sock.close()


if __name__ == "__main__":
    main()