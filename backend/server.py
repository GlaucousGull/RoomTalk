import json
import logging
import asyncio
import websockets
import os
import threading
from websockets.exceptions import ConnectionClosed
# from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from http.server import SimpleHTTPRequestHandler
from threading import Thread

# 换成这个（Python 3.10 兼容）
from http.server import HTTPServer
from socketserver import ForkingMixIn

from utils import init_project_logger
from room_manager import roommanager
from user_manager import usermanager
from settings import settings

init_project_logger()

logger = logging.getLogger(__name__)

# 定义多进程 HTTP 服务器
class ForkingHTTPServer(ForkingMixIn, HTTPServer):
    daemon_threads = True

# 获取项目根目录
def get_project_root():
    # 当前文件所在目录 (backend目录)
    current_file_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(current_file_dir, ".."))

# 获取配置的前端根目录文件
def get_frontend_dir():
    root_dir = settings.get("frontend.root_dir", "../frontend")
    if not os.path.isabs(root_dir):
        root_dir = os.path.join(get_project_root(), root_dir)
    return os.path.abspath(root_dir)

class MyRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        # 静态文件根目录
        frontend_dir = get_frontend_dir()
        super().__init__(*args, directory=frontend_dir, **kwargs)

    # 全局跨域（解决 WebSocket 跨域）
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    # GET 请求处理
    def do_GET(self):
        try:
            # 首页动态渲染
            if self.path == "/" or self.path == "/index.html":
                # 读取配置
                frontend_dir = get_frontend_dir()
                html_path = os.path.join(frontend_dir, "index.html")


                css_path = settings.get("frontend.css_path", "/css//style.scc")
                js_path = settings.get("frontend.js_path", "/js/app.js")

                # 读取模板
                with open(html_path, "r", encoding="utf-8") as fd:
                    content = fd.read()
                
                # 替换占位符
                content = content.replace("{{css_path}}", css_path)
                content = content.replace("{{js_path}}", js_path)

                # 返回给浏览器
                self.send_response(200)
                self.send_header("Content-type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(content.encode("utf-8"))
                return 
            return super().do_GET()
        except Exception as e:
            logger.error(f"请求异常 {e}", exc_info=True)
            self.send_error(500)

class HttpServer:
    @staticmethod
    def run():
        host = settings.get("server.host", "0.0.0.0")
        port = int(settings.get("server.port", 9000))
        
        logger.info(f"http id: {host} 监听端口 {port}")

        try:
            server = ForkingHTTPServer((host, port), MyRequestHandler)
            logger.info(f"HTTP 静态服务启动成功 => http://{host}:{port}")
            logger.info(f"前端目录 => {get_frontend_dir()}")
            server.serve_forever()
        except Exception as e:
            logger.error(f"HTTP 服务启动失败: {e}")

# 静态文件服务（给客户端发 index.html，支持 Nginx转发）
def run_http_server():
    HttpServer.run()

# # 用户注册
# async def handler_user_login(websocket, data):
#     # 统一获取数据
#     user_name = data.get()

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
    # 统一获取参数
    user_id    = data.get("user_id", "")
    room_name  = data.get("room_name", "").strip()  # 直接清理空白
    room_type  = data.get("room_type", "")
    password   = data.get("password", "")

    # 基础校验
    if not user_id:
        await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))
        return

    # 创建房间
    room_id = roommanager.create_room(user_id, room_type, password)
    if not room_id:
        await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))
        return

    # 获取房间对象
    room = roommanager.get_room_object(room_id)
    if not room:
        await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))
        return

    # 设置房间名称（空则使用房间号）
    final_room_name = room_name if room_name else str(room_id)
    room.set_room_name(final_room_name)

    # 设置房间类型 + 密码（私域）
    room.set_room_type(room_type)
    if room_type == "1":
        room.set_password(password)

    # 日志输出
    if room_type == "1":
        logger.info("私域房间创建成功")
    elif room_type == "0":
        logger.info("公域房间创建成功")
    else:
        logger.warning("未知房间类型")

    # 返回成功消息
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
    room_id_list = roommanager.get_room_list()

    # 构造给客户端的json数据
    room_list_for_front = []
    for room_id in room_id_list:
        room = roommanager.get_room_object(room_id)
        room_list_for_front.append({
            "room_id": room.get_room_id(),
            "room_name": room.get_room_name(),
            "room_type": room.get_room_type()
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
    # 查找对应的房间
    room = roommanager.get_room_object(room_id)

    logger.info(f"用户请求加入房间 {room_id}, 房间名：{room.get_room_name()}")

    if not room:
        logger.debug(f"房间号：{room_id}, 房间号类型:{type(room_id).__name__}")
        # print(f"房间号：{room_id}, 房间号类型:{type(room_id).__name__}")
        await websocket.send(json.dumps({
            "type": "join_room_fail",
            "data": {"msg": "房间不存在"}
        }))
        return

    room_type =  room.get_room_type()

    is_join = True

    match room_type:
        case '0': # 公域房间
            room.add_user(user_id) # 向房间成员列表添加新成员
        case '1': # 私域房间
            if not room.compare_password(data.get("password")):
                is_join = False
            room.add_user(user_id)
        case _:
            logger.warning("警告！未知的房间类型")
            is_join = False
    
    if not is_join:
        await websocket.send(json.dumps({
            "type": "join_room_fail",
            "data": {
                "msg": "私域房间密码错误"
            }
        }))

    # 将用户添加到房间列表中
    room.add_user(user_id)

    # 获取历史消息
    historical_message = room.get_historical_message()

    # 组成完整的 {user_id, user_name, message} 三元组
    msg_body = []
    for msg_tuple in historical_message:
        msg_user_id, msg = msg_tuple
        # 查找用户名称
        user_name = usermanager.get_user_name(msg_user_id)
        msg_body.append({
            "user_id": msg_user_id,
            "user_name": user_name,
            "body": msg,
            })

    # 获取房间人数
    online_users = room.get_user_count()

    # 向前端发送消息
    if is_join:
        await websocket.send(json.dumps({
            "type": "join_room_success",
            "data": {
                "room_id": room.get_room_id(),
                "room_name": room.get_room_name(),
                "his_msg": msg_body,
                "online_users": online_users
            }
        }))
    else:
        await websocket.send(json.dumps({
            "type": "join_room_fail",
            "data": {
            }
        }))

# 房间追加并广播给所有在线用户
async def handler_send_message(websocket, data):
    # 获取参数
    user_id = data.get("user_id")
    room_id = data.get("room_id")
    msg = data.get("msg").strip()
    msg_id = data.get("msg_id")

    logger.info(f"用户：{user_id} 在 {room_id} 发送 {msg}")

    # 基础校验
    if not user_id or not room_id or not msg:
        await websocket.send(json.dumps({
            "type": "send_message_fail",
            "data": {
                "msg": "信息错误，请重试"
            }
        }))
        return
    
    # 查找房间实体
    room = roommanager.get_room_object(room_id)
    if not room:
        await websocket.send(json.dumps({
            "type": "send_message_fail",
            "data": {
                "msg": "房间错误，或已被删除"
            }
        }))
        return
    
    # 往房间历史消息区追加消息
    room.add_message(user_id, msg)

    # 获取用户名
    user_name = usermanager.get_user_name(user_id)

    # 构造要广播的消息体
    broadcast_msg = {
        "type": "new_message",
        "data": {
            "user_id": user_id,
            "user_name": user_name,
            "body": msg,
            "msg_id": msg_id
        }
    }

    # 广播给所有在线用户
    for uid in room.get_user_list():
        ws = usermanager.get_user_ws(uid)
        if ws:
            logger.debug(f"发送消息给用户 {uid}")
            await ws.send(json.dumps(broadcast_msg))

async def handler_heartbeat(ws, data):
    await ws.send(json.dumps({
        "type": "heartbeat_ack"
    }))

# 获取房间内的所有用户
async def handler_get_room_users(websocket, data):
    logger.debug("用户请求房间用户列表")
    """ 获取当前房间内的所有用户 """
    user_id = data.get("user_id")
    room_id = data.get("room_id")

    # 获取房间实体
    room = roommanager.get_room_object(room_id)
    if not room:
        return
    
    # 获取用户列表
    all_uid = room.get_user_list()
    user_list = []
    for uid in all_uid:
        uname = usermanager.get_user_name(uid)
        ustate = usermanager.is_online(uid)
        user_list.append({
            "user_id": uid,
            "user_name": uname,
            "user_online": ustate
        })

    await websocket.send(json.dumps({
        "type": "room_users",
        "data": {
            "user_list": user_list
        }
    }))

# 音视频通话邀请
async def handler_invite_avideo_call(websocket, data):
    """ 视频通话邀请，发给定向目标 """
    inviter_uid = data.get("inviter_id")
    logger.debug(f"用户 {inviter_uid} 请求视频通话")
    target_uid = data.get("target_id")
    room_id = data.get("room_id")
    offer = data.get("sdp")
    inviter_name = usermanager.get_user_name(target_uid)
    room_name = roommanager.get_room_object(room_id).get_room_name()

    target_ws = usermanager.get_user_ws(target_uid)
    if not target_ws:
        # 对方处于离线状态，通话邀请失败
        msg = inviter_name + "当前不在线"
        await websocket.send(json.dumps({
            "type": "avideo_call_fail",
            "data": {
                "msg": msg
            }
        }))
        return
    
    logger.debug(f"定向推送给用户 {target_uid} 通话邀请成功")
    # 定向推送通话邀请
    await target_ws.send(json.dumps({
        "type": "avideo_call_invite",
        "data": {
            "room_id": room_id,
            "room_name": room_name,
            "inviter_id": inviter_uid,
            "inviter_name": inviter_name,
            "sdp": offer
        }
    }))
    

# 获取STUN公共服务地址
async def handler_get_ice_url(websocket, data):
    logger.debug("用户获取STUN服务ICE")
    iceServers = settings.get("iceServers")
    await websocket.send(json.dumps({
        "type": "ice_config",
        "data": {
            "ice_servers": iceServers
        }
    }))

# 目标用户拒绝通话
async def handler_reject_avideo_call(websocket, data):
    user_id = data.get("target_id")
    user_name = usermanager.get_user_name(user_id)
    await websocket.send(json.dumps({
        "type": "user_reject_avideo_call",
        "data": {
            "user_id": user_id,
            "user_name": user_name
        }
    }))

# 目标用户同意进行音视频通话
async def handler_agree_avideo_call(websocket, data):
    # 信令传递
    target_id = data.get("target_id")
    answer = data.get("sdp")

    # 获取目标用户名
    target_name = usermanager.get_user_name(target_id)

    # 获取目标用户的ws
    target_ws = usermanager.get_user_ws(target_id)

    if not target_ws:
        msg = "通话失败，用户" + target_name + "连接断开"
        await websocket.send(json.dumps({
            "type": "avideo_call_fail",
            "data": {
                "msg": msg
            }
        }))
        return

    # 传递会给发送者
    logger.debug("用户同意视频通话")

    await target_ws.send(json.dumps({
        "type": "answer",
        "data": {
            "user_id": target_id,
            "user_name": target_name,
            "sdp": answer
        }
    }))

# 交换双方的 ice 候选者
async def handler_ice_candidate_swap(websocket, data):
    # 给目标发送 ice_candidate
    target_id = data.get("target_id")
    ice_candidate = data.get("candidate")

    # 获取目标 ws
    target_ws = usermanager.get_user_ws(target_id)

    if not target_id:
        msg = "通话失败，用户" + target_id + "连接断开"
        await websocket.send(json.dumps({
            "type": "avideo_call_fail",
            "data": {
                "msg": msg
            }
        }))
        return
    
    await target_ws.send(json.dumps({
        "type": "remote_ice_candidate",
        "data": {
            "candidate": ice_candidate
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

            logger.info(f"用户发送指令 {msg_type}")

            match msg_type:
                # case "user_login":
                #     await handler_user_login(websocket, msg_data)
                case "synchro_room_list":
                    await handler_sync_room_list(websocket, msg_data)
                case "create_room":
                    await handler_create_room(websocket, msg_data)
                case "join_room":
                    await handler_join_room(websocket, msg_data)
                case "send_message":
                    await handler_send_message(websocket, msg_data)
                case "heartbeat":
                    await handler_heartbeat(websocket, msg_data)
                case "get_room_online_users":
                    await handler_get_room_users(websocket, msg_data)
                case "offer":
                    await handler_invite_avideo_call(websocket, msg_data)
                case "get_ice_url":
                    await handler_get_ice_url(websocket, msg_data)
                case "reject_video_call":
                    await handler_reject_avideo_call(websocket, msg_data)
                case "answer":
                    await handler_agree_avideo_call(websocket, msg_data)
                case "local_ice_candidate":
                    await handler_ice_candidate_swap(websocket, msg_data)
                case _:
                    logger.error("请求错误类型")


    except ConnectionClosed:
        logger.info(f"客户端 {client_addr} 断开连接")

async def main():
    # 在后台线程启动 HTTP 服务
    threading.Thread(target=run_http_server, daemon=True).start()
    # 获取配置，websocket ip和port
    async with websockets.serve(handler, settings.get("server.host", "0.0.0.0"), int(settings.get("server.ws_port", 10000))):
        logger.info("WebSocket 服务器启动成功，监听端口 10000")
        await asyncio.Future()  # 永久运行，不会退出

if __name__ == "__main__":
    asyncio.run(main())