import asyncio
import logging
from websockets import serve
from websockets.exceptions import ConnectionClosed

# 配置日志，方便看连接和消息
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

async def handler(websocket):
    # 客户端成功握手后，才会进入这里
    client_addr = websocket.remote_address
    logging.info(f"客户端 {client_addr} 完成 WebSocket 握手，已连接")
    try:
        async for message in websocket:
            logging.info(f"收到 {client_addr} 的消息: {message}")
            # 原样回复消息
            await websocket.send(f"服务器已收到: {message}")
    except ConnectionClosed:
        logging.info(f"客户端 {client_addr} 断开连接")

async def main():
    # 监听所有网卡的 9000 端口
    async with serve(handler, "192.168.232.140", 9000):
        logging.info("WebSocket 服务器启动成功，监听端口 9000")
        await asyncio.Future()  # 永久运行，不会退出

if __name__ == "__main__":
    asyncio.run(main())