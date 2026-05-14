import json
import logging
import asyncio
import websockets
from websockets.exceptions import ConnectionClosed
from http.server import HTTPServer, SimpleHTTPRequestHandler
from threading import Thread

from utils import init_root_logger
from room_manager import roommanager
from user_manager import usermanager

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

# 用户上线
async def user_online(ws):
    # 1. 生成UID（交给UserManager）
    user_id = usermanager.generate_id()
    user_name = f"用户_{user_id[-6:]}"  # uid前四位作为用户名后缀

    # 2. 用户上线
    usermanager.user_online(user_id, user_name, ws)

    # 3. 把UID发给前端
    await ws.send(json.dumps({
        "type": "init_user",
        "data": {
            "user_id": user_id,
            "user_name": user_name
        }
    }))

# 创建房间请求回调
async def handler_create_room(websocket, data):
    # 1. 统一获取参数
    user_id    = data.get("user_id", "")
    room_name  = data.get("room_name", "").strip()  # 直接清理空白
    room_type  = data.get("room_type", "")
    password   = data.get("password", "")

    # 2. 基础校验
    if not user_id:
        await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))
        return

    # 3. 创建房间
    room_id = roommanager.create_room(user_id, room_type, password)
    if not room_id:
        await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))
        return

    # 4. 获取房间对象
    room = roommanager.get_room_object(room_id)
    if not room:
        await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))
        return

    # 5. 设置房间名称（空则使用房间号）
    final_room_name = room_name if room_name else str(room_id)
    room.set_room_name(final_room_name)

    # 6. 设置房间类型 + 密码（私域）
    room.set_room_type(room_type)
    if room_type == "1":
        room.set_password(password)

    # 7. 日志输出
    if room_type == "1":
        logger.info("私域房间创建成功")
    elif room_type == "0":
        logger.info("公域房间创建成功")
    else:
        logger.warning("未知房间类型")

    # 8. 返回成功消息
    await websocket.send(json.dumps({
        "type": "create_room_success",
        "data": {
            "room_id": room_id,
            "room_type": room_type,
            "room_name": final_room_name
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

    logger.info("房间列表同步成功")

async def handler_join_room(websocket, data):       
    """ 
    加入房间应该包含以下信息:
        1、房间号
        2、用户id
        3、房间对应类型的验证信息(可为空)
    """
    room_id = data.get("room_id")
    user_id = data.get("user_id")
    room_type_data = data.get("room_type_data")
    # 查找对应的房间
    room = roommanager.get_room_object(room_id)

    room_type =  room.get_room_type()

    is_join = True

    match room_type:
        case '0': # 公域房间
            room.add_user(user_id) # 向房间成员列表添加新成员
        case '1': # 私域房间
            if not room.compare_password(room_type_data.get("password")):
                is_join = False
            room.add_user(user_id)
        case _:
            logger.warning("警告！未知的房间类型")
    
    # 获取历史消息
    historical_message = room.get_historical_message()

    # 组成完整的 {user_id, user_name, message} 三元组
    msg_body = []
    for msg_tuple in historical_message:
        msg_user_id, msg = msg_tuple
        # 查找用户名称
        user_name = usermanager.get_user_name(msg_user_id)
        msg_body.append({"user_id": msg_user_id, "user_name": user_name, "msg": msg})

    # 获取房间人数
    online_users = room.get_user_count()

    # 向前端发送消息
    if is_join:
        # await websocket.send(json.dumps({
        #     "type": "join_room_success",
        #     "data": {
        #         "his_msg": msg_body,
        #         "online_users": online_users
        #     }
        # }))
        await websocket.send(json.dumps({
            "type": "join_room_success",
            "data": {
                "room_name": room.get_room_name(),
                "his_msg": [
                    {
                        "user_id": "0001",
                        "user_name": "张三",
                        "body": "大家好，我是张三～"
                    },
                    {
                        "user_id": "0002",
                        "user_name": "李四",
                        "body": "哈喽哈喽！"
                    },
                    {
                        "user_id": user_id,
                        "user_name": "我自己",
                        "body": "我进来啦！"
                    }
                ],
                "online_users": online_users
            }
        }))
    else:
        await websocket.send(json.dumps({
            "type": "join_room_fail",
            "data": {
            }
        }))


async def handler(websocket):
    # 客户端成功握手后，才会进入这里
    client_addr = websocket.remote_address
    logger.info(f"客户端 {client_addr} 完成 WebSocket 握手，已连接")

    # websocket连接建立后的处理
    await user_online(websocket)

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
                case "join_room":
                    await handler_join_room(websocket, msg_data)
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