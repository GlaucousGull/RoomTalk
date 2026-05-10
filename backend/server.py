import json
import logging
import asyncio
import websockets
from websockets.exceptions import ConnectionClosed
from http.server import HTTPServer, SimpleHTTPRequestHandler
from threading import Thread

from utils import init_root_logger
from room_manager import roommanager

init_root_logger()

logger = logging.getLogger(__name__)

# 静态文件服务（给客户端发 index.html）
def run_http_server():
    # 切换工作目录到 frontend 文件夹
    import os
    os.chdir("../frontend")
    server_address = ("0.0.0.0", 9000)
    httpd = HTTPServer(server_address, SimpleHTTPRequestHandler)
    logger.info("HTTP 服务已启动，访问 http://localhost:9000 即可打开网页")
    httpd.serve_forever()

# 创建房间请求回调
async def handler_create_room(websockets, data):
    user_id = data.get("user_id")
    room_name = data.get("room_name")

    room_id = roommanager.create_room(user_id)


    if not room_id:
        await websockets.send(json.dumps({
        "type": "create_room_fail",
        "data": {
            
            }
        }))

    else:
        roommanager.get_room_object(room_id).set_room_name(room_name)
        await websockets.send(json.dumps({
            "type": "create_room_success",
            "data": {
                "room_id": room_id,
                "room_name": room_name
            }
        }))

# 给客户端同步现有房间列表
async def handler_sync_room_list(websocket, data):
    room_dict = roommanager.get_room_list()

    # 构造给客户端的json数据
    room_list_for_front = []
    for room_id, room_obj in room_dict.items():
        room_list_for_front.append({
            "room_id": room_id,
            "room_name": room_obj.room_name
        })

    # 给前端发送数据
    await websocket.send(json.dumps({
        "type": "room_list",
        "data": {
            "rooms": room_list_for_front
        }
    }))

    logger.info("用户列表同步成功")
        

async def handler(websocket):
    # 客户端成功握手后，才会进入这里
    client_addr = websocket.remote_address
    logger.info(f"客户端 {client_addr} 完成 WebSocket 握手，已连接")

    try:
        async for message in websocket:
            # 解析前端发来的请求
            data = json.loads(message)
            msg_type = data.get("type")
            msg_data = data.get("data")

            match msg_type:
                case "create_room":
                    await handler_create_room(websocket, msg_data)
                case "synchro_room_list":
                    await handler_sync_room_list(websocket, msg_data)
                case _:
                    await logger.error("请求错误类型")


    except ConnectionClosed:
        logger.info(f"客户端 {client_addr} 断开连接")

async def main():
    # 在后台线程启动 HTTP 服务
    http_thread = Thread(target=run_http_server, daemon=True)
    http_thread.start()
    # 监听 192.168.232.140 网卡的 9000 端口
    async with websockets.serve(handler, "0.0.0.0", 10000):
        logger.info("WebSocket 服务器启动成功，监听端口 10000")
        await asyncio.Future()  # 永久运行，不会退出

if __name__ == "__main__":
    asyncio.run(main())