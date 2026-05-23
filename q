[33mcommit ce4810a3b2bae324deec825a91c66387f94037ee[m[33m ([m[1;36mHEAD[m[33m -> [m[1;32mmain[m[33m, [m[1;31morigin/main[m[33m)[m
Author: shijunhao <296858768@qq.com>
Date:   Sat May 16 00:32:36 2026 +0800

    完成聊天室核心功能，修复布局、消息发送、心跳、广播等全部BUG，功能正常可用

[1mdiff --git a/backend/__pycache__/room.cpython-310.pyc b/backend/__pycache__/room.cpython-310.pyc[m
[1mindex 12b2281..986fc9c 100644[m
Binary files a/backend/__pycache__/room.cpython-310.pyc and b/backend/__pycache__/room.cpython-310.pyc differ
[1mdiff --git a/backend/__pycache__/room_manager.cpython-310.pyc b/backend/__pycache__/room_manager.cpython-310.pyc[m
[1mindex 0262786..4dd147e 100644[m
Binary files a/backend/__pycache__/room_manager.cpython-310.pyc and b/backend/__pycache__/room_manager.cpython-310.pyc differ
[1mdiff --git a/backend/__pycache__/user_manager.cpython-310.pyc b/backend/__pycache__/user_manager.cpython-310.pyc[m
[1mindex 94d6335..0ae9109 100644[m
Binary files a/backend/__pycache__/user_manager.cpython-310.pyc and b/backend/__pycache__/user_manager.cpython-310.pyc differ
[1mdiff --git a/backend/config.json b/backend/config.json[m
[1mindex 373f2cc..42c82a2 100644[m
[1m--- a/backend/config.json[m
[1m+++ b/backend/config.json[m
[36m@@ -10,7 +10,7 @@[m
     },[m
 [m
     "log": {[m
[31m-        "level": "INFO",[m
[32m+[m[32m        "level": "DEBUG",[m[41m[m
         "format": "%(asctime)s [%(levelname)s] [%(name)s] %(message)s",[m
         "datefmt": "%Y-%m-%d %H:%M:%S"[m
     }[m
[1mdiff --git a/backend/room.py b/backend/room.py[m
[1mindex d524522..4450d50 100644[m
[1m--- a/backend/room.py[m
[1m+++ b/backend/room.py[m
[36m@@ -24,11 +24,14 @@[m [mclass Room:[m
         self.user_list = []                 # 用户列表[m
         self.message_list = []              # 房间历史消息列表[m
 [m
[32m+[m[32m    # 获取房间号[m[41m[m
[32m+[m[32m    def get_room_id(self) -> str:[m[41m[m
[32m+[m[32m        return str(self.room_id)[m[41m[m
     # 修改房间名[m
     def set_room_name(self, room_name: str):[m
         self.room_name = room_name[m
 [m
[31m-    def get_room_name(self):[m
[32m+[m[32m    def get_room_name(self) -> str:[m[41m[m
         return self.room_name[m
 [m
     # 添加用户[m
[36m@@ -54,7 +57,7 @@[m [mclass Room:[m
         self.room_type = room_type[m
 [m
     # 获取房间类型[m
[31m-    def get_room_type(self):[m
[32m+[m[32m    def get_room_type(self) -> int:[m[41m[m
         return self.room_type[m
 [m
     # 添加/修改房间加入密码[m
[1mdiff --git a/backend/room_manager.py b/backend/room_manager.py[m
[1mindex f442290..c557d8f 100644[m
[1m--- a/backend/room_manager.py[m
[1m+++ b/backend/room_manager.py[m
[36m@@ -77,11 +77,11 @@[m [mclass RoomManager:[m
     # 创建房间[m
     def create_room(self, user_id = "", room_type = 0, password = None) -> int:[m
         # 获取随机房间号[m
[31m-        room_number = self.get_room_number()[m
[32m+[m[32m        room_number = str(self.get_room_number())[m[41m[m
         if not room_number:[m
             logger.error("房间创建失败")[m
             return None[m
[31m-        self.room_list[room_number] = Room(room_number,  str(room_number), room_type, password)[m
[32m+[m[32m        self.room_list[room_number] = Room(str(room_number),  str(room_number), int(room_type), password)[m[41m[m
 [m
         # 向房间成员列表添加房间创建者[m
         self.room_list[room_number].add_user(user_id)[m
[36m@@ -90,7 +90,7 @@[m [mclass RoomManager:[m
         return room_number[m
     [m
     # 根据房间号查找并返回房间对象[m
[31m-    def get_room_object(self, room_id) -> Room:[m
[32m+[m[32m    def get_room_object(self, room_id: str) -> Room:[m[41m[m
         if room_id not in self.room_list:[m
             return None[m
         return self.room_list[room_id][m
[1mdiff --git a/backend/server.py b/backend/server.py[m
[1mindex b2bbfa5..840fb9d 100644[m
[1m--- a/backend/server.py[m
[1m+++ b/backend/server.py[m
[36m@@ -44,39 +44,39 @@[m [masync def user_online(ws):[m
 [m
 # 创建房间请求回调[m
 async def handler_create_room(websocket, data):[m
[31m-    # 1. 统一获取参数[m
[32m+[m[32m    # 统一获取参数[m[41m[m
     user_id    = data.get("user_id", "")[m
     room_name  = data.get("room_name", "").strip()  # 直接清理空白[m
     room_type  = data.get("room_type", "")[m
     password   = data.get("password", "")[m
 [m
[31m-    # 2. 基础校验[m
[32m+[m[32m    # 基础校验[m[41m[m
     if not user_id:[m
         await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))[m
         return[m
 [m
[31m-    # 3. 创建房间[m
[32m+[m[32m    # 创建房间[m[41m[m
     room_id = roommanager.create_room(user_id, room_type, password)[m
     if not room_id:[m
         await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))[m
         return[m
 [m
[31m-    # 4. 获取房间对象[m
[32m+[m[32m    # 获取房间对象[m[41m[m
     room = roommanager.get_room_object(room_id)[m
     if not room:[m
         await websocket.send(json.dumps({"type": "create_room_fail", "data": {}}))[m
         return[m
 [m
[31m-    # 5. 设置房间名称（空则使用房间号）[m
[32m+[m[32m    # 设置房间名称（空则使用房间号）[m[41m[m
     final_room_name = room_name if room_name else str(room_id)[m
     room.set_room_name(final_room_name)[m
 [m
[31m-    # 6. 设置房间类型 + 密码（私域）[m
[32m+[m[32m    # 设置房间类型 + 密码（私域）[m[41m[m
     room.set_room_type(room_type)[m
     if room_type == "1":[m
         room.set_password(password)[m
 [m
[31m-    # 7. 日志输出[m
[32m+[m[32m    # 日志输出[m[41m[m
     if room_type == "1":[m
         logger.info("私域房间创建成功")[m
     elif room_type == "0":[m
[36m@@ -84,7 +84,7 @@[m [masync def handler_create_room(websocket, data):[m
     else:[m
         logger.warning("未知房间类型")[m
 [m
[31m-    # 8. 返回成功消息[m
[32m+[m[32m    # 返回成功消息[m[41m[m
     await websocket.send(json.dumps({[m
         "type": "create_room_success",[m
         "data": {[m
[36m@@ -96,14 +96,16 @@[m [masync def handler_create_room(websocket, data):[m
 [m
 # 给客户端同步现有房间列表[m
 async def handler_sync_room_list(websocket, data):[m
[31m-    room_dict = roommanager.get_room_list()[m
[32m+[m[32m    room_id_list = roommanager.get_room_list()[m[41m[m
 [m
     # 构造给客户端的json数据[m
     room_list_for_front = [][m
[31m-    for room_id, room_obj in room_dict.items():[m
[32m+[m[32m    for room_id in room_id_list:[m[41m[m
[32m+[m[32m        room = roommanager.get_room_object(room_id)[m[41m[m
         room_list_for_front.append({[m
[31m-            "room_id": room_id,[m
[31m-            "room_name": room_obj.room_name[m
[32m+[m[32m            "room_id": room.get_room_id(),[m[41m[m
[32m+[m[32m            "room_name": room.get_room_name(),[m[41m[m
[32m+[m[32m            "room_type": room.get_room_type()[m[41m[m
         })[m
 [m
     # 给前端发送数据[m
[36m@@ -125,10 +127,18 @@[m [masync def handler_join_room(websocket, data):[m
     """[m
     room_id = data.get("room_id")[m
     user_id = data.get("user_id")[m
[31m-    room_type_data = data.get("room_type_data")[m
     # 查找对应的房间[m
     room = roommanager.get_room_object(room_id)[m
 [m
[32m+[m[32m    if not room:[m[41m[m
[32m+[m[32m        logger.debug(f"房间号：{room_id}, 房间号类型:{type(room_id).__name__}")[m[41m[m
[32m+[m[32m        # print(f"房间号：{room_id}, 房间号类型:{type(room_id).__name__}")[m[41m[m
[32m+[m[32m        await websocket.send(json.dumps({[m[41m[m
[32m+[m[32m            "type": "join_room_fail",[m[41m[m
[32m+[m[32m            "data": {"msg": "房间不存在"}[m[41m[m
[32m+[m[32m        }))[m[41m[m
[32m+[m[32m        return[m[41m[m
[32m+[m[41m[m
     room_type =  room.get_room_type()[m
 [m
     is_join = True[m
[36m@@ -137,12 +147,24 @@[m [masync def handler_join_room(websocket, data):[m
         case '0': # 公域房间[m
             room.add_user(user_id) # 向房间成员列表添加新成员[m
         case '1': # 私域房间[m
[31m-            if not room.compare_password(room_type_data.get("password")):[m
[32m+[m[32m            if not room.compare_password(data.get("password")):[m[41m[m
                 is_join = False[m
             room.add_user(user_id)[m
         case _:[m
             logger.warning("警告！未知的房间类型")[m
[32m+[m[32m            is_join = False[m[41m[m
     [m
[32m+[m[32m    if not is_join:[m[41m[m
[32m+[m[32m        await websocket.send(json.dumps({[m[41m[m
[32m+[m[32m            "type": "join_room_fail",[m[41m[m
[32m+[m[32m            "data": {[m[41m[m
[32m+[m[32m                "msg": "私域房间密码错误"[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m        }))[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    # 将用户添加到房间列表中[m[41m[m
[32m+[m[32m    room.add_user(user_id)[m[41m[m
[32m+[m[41m[m
     # 获取历史消息[m
     historical_message = room.get_historical_message()[m
 [m
[36m@@ -152,51 +174,115 @@[m [masync def handler_join_room(websocket, data):[m
         msg_user_id, msg = msg_tuple[m
         # 查找用户名称[m
         user_name = usermanager.get_user_name(msg_user_id)[m
[31m-        msg_body.append({"user_id": msg_user_id, "user_name": user_name, "msg": msg})[m
[32m+[m[32m        msg_body.append({[m[41m[m
[32m+[m[32m            "user_id": msg_user_id,[m[41m[m
[32m+[m[32m            "user_name": user_name,[m[41m[m
[32m+[m[32m            "body": msg,[m[41m[m
[32m+[m[32m            })[m[41m[m
 [m
     # 获取房间人数[m
     online_users = room.get_user_count()[m
 [m
     # 向前端发送消息[m
     if is_join:[m
[32m+[m[32m        await websocket.send(json.dumps({[m[41m[m
[32m+[m[32m            "type": "join_room_success",[m[41m[m
[32m+[m[32m            "data": {[m[41m[m
[32m+[m[32m                "room_name": room.get_room_name(),[m[41m[m
[32m+[m[32m                "his_msg": msg_body,[m[41m[m
[32m+[m[32m                "online_users": online_users[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m        }))[m[41m[m
         # await websocket.send(json.dumps({[m
         #     "type": "join_room_success",[m
         #     "data": {[m
[31m-        #         "his_msg": msg_body,[m
[32m+[m[32m        #         "room_name": room.get_room_name(),[m[41m[m
[32m+[m[32m        #         "his_msg": [[m[41m[m
[32m+[m[32m        #             {[m[41m[m
[32m+[m[32m        #                 "user_id": "0001",[m[41m[m
[32m+[m[32m        #                 "user_name": "张三",[m[41m[m
[32m+[m[32m        #                 "body": "大家好，我是张三～"[m[41m[m
[32m+[m[32m        #             },[m[41m[m
[32m+[m[32m        #             {[m[41m[m
[32m+[m[32m        #                 "user_id": "0002",[m[41m[m
[32m+[m[32m        #                 "user_name": "李四",[m[41m[m
[32m+[m[32m        #                 "body": "哈喽哈喽！"[m[41m[m
[32m+[m[32m        #             },[m[41m[m
[32m+[m[32m        #             {[m[41m[m
[32m+[m[32m        #                 "user_id": user_id,[m[41m[m
[32m+[m[32m        #                 "user_name": "我自己",[m[41m[m
[32m+[m[32m        #                 "body": "我进来啦！"[m[41m[m
[32m+[m[32m        #             }[m[41m[m
[32m+[m[32m        #         ],[m[41m[m
         #         "online_users": online_users[m
         #     }[m
         # }))[m
[32m+[m[32m    else:[m[41m[m
         await websocket.send(json.dumps({[m
[31m-            "type": "join_room_success",[m
[32m+[m[32m            "type": "join_room_fail",[m[41m[m
             "data": {[m
[31m-                "room_name": room.get_room_name(),[m
[31m-                "his_msg": [[m
[31m-                    {[m
[31m-                        "user_id": "0001",[m
[31m-                        "user_name": "张三",[m
[31m-                        "body": "大家好，我是张三～"[m
[31m-                    },[m
[31m-                    {[m
[31m-                        "user_id": "0002",[m
[31m-                        "user_name": "李四",[m
[31m-                        "body": "哈喽哈喽！"[m
[31m-                    },[m
[31m-                    {[m
[31m-                        "user_id": user_id,[m
[31m-                        "user_name": "我自己",[m
[31m-                        "body": "我进来啦！"[m
[31m-                    }[m
[31m-                ],[m
[31m-                "online_users": online_users[m
             }[m
         }))[m
[31m-    else:[m
[32m+[m[41m[m
[32m+[m[32m# 房间追加并广播给所有在线用户[m[41m[m
[32m+[m[32masync def handler_send_message(websocket, data):[m[41m[m
[32m+[m[32m    # 获取参数[m[41m[m
[32m+[m[32m    user_id = data.get("user_id")[m[41m[m
[32m+[m[32m    room_id = data.get("room_id")[m[41m[m
[32m+[m[32m    msg = data.get("msg").strip()[m[41m[m
[32m+[m[32m    msg_id = data.get("msg_id")[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    logger.info(f"用户：{user_id} 在 {room_id} 发送 {msg}")[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    # 基础校验[m[41m[m
[32m+[m[32m    if not user_id or not room_id or not msg:[m[41m[m
         await websocket.send(json.dumps({[m
[31m-            "type": "join_room_fail",[m
[32m+[m[32m            "type": "send_message_fail",[m[41m[m
             "data": {[m
[32m+[m[32m                "msg": "信息错误，请重试"[m[41m[m
             }[m
         }))[m
[32m+[m[32m        return[m[41m[m
[32m+[m[41m    [m
[32m+[m[32m    # 查找房间实体[m[41m[m
[32m+[m[32m    room = roommanager.get_room_object(room_id)[m[41m[m
[32m+[m[32m    if not room:[m[41m[m
[32m+[m[32m        await websocket.send(json.dumps({[m[41m[m
[32m+[m[32m            "type": "send_message_fail",[m[41m[m
[32m+[m[32m            "data": {[m[41m[m
[32m+[m[32m                "msg": "房间错误，或已被删除"[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m        }))[m[41m[m
[32m+[m[32m        return[m[41m[m
[32m+[m[41m    [m
[32m+[m[32m    # 往房间历史消息区追加消息[m[41m[m
[32m+[m[32m    room.add_message(user_id, msg)[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    # 获取用户名[m[41m[m
[32m+[m[32m    user_name = usermanager.get_user_name(user_id)[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    # 构造要广播的消息体[m[41m[m
[32m+[m[32m    broadcast_msg = {[m[41m[m
[32m+[m[32m        "type": "new_message",[m[41m[m
[32m+[m[32m        "data": {[m[41m[m
[32m+[m[32m            "user_id": user_id,[m[41m[m
[32m+[m[32m            "user_name": user_name,[m[41m[m
[32m+[m[32m            "body": msg,[m[41m[m
[32m+[m[32m            "msg_id": msg_id[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[32m    }[m[41m[m
 [m
[32m+[m[32m    # 广播给所有在线用户[m[41m[m
[32m+[m[32m    for uid in room.get_user_list():[m[41m[m
[32m+[m[32m        ws = usermanager.get_user_ws(uid)[m[41m[m
[32m+[m[32m        if ws:[m[41m[m
[32m+[m[32m            logger.debug(f"发送消息给用户 {uid}")[m[41m[m
[32m+[m[32m            await ws.send(json.dumps(broadcast_msg))[m[41m[m
[32m+[m[41m[m
[32m+[m[32masync def handler_heartbeat(ws, data):[m[41m[m
[32m+[m[32m    await ws.send(json.dumps({[m[41m[m
[32m+[m[32m        "type": "heartbeat_ack"[m[41m[m
[32m+[m[32m    }))[m[41m[m
 [m
 async def handler(websocket):[m
     # 客户端成功握手后，才会进入这里[m
[36m@@ -220,6 +306,10 @@[m [masync def handler(websocket):[m
                     await handler_sync_room_list(websocket, msg_data)[m
                 case "join_room":[m
                     await handler_join_room(websocket, msg_data)[m
[32m+[m[32m                case "send_message":[m[41m[m
[32m+[m[32m                    await handler_send_message(websocket, msg_data)[m[41m[m
[32m+[m[32m                case "heartbeat":[m[41m[m
[32m+[m[32m                    await handler_heartbeat(websocket, msg_data)[m[41m[m
                 case _:[m
                     await logger.error("请求错误类型")[m
 [m
[1mdiff --git a/backend/user_manager.py b/backend/user_manager.py[m
[1mindex 853c60a..e5ca195 100644[m
[1m--- a/backend/user_manager.py[m
[1m+++ b/backend/user_manager.py[m
[36m@@ -30,11 +30,11 @@[m [mclass UserManager:[m
         return cls.__instance[m
 [m
     # 生成用户唯一id[m
[31m-    def generate_id(self):[m
[32m+[m[32m    def generate_id(self) -> str:[m[41m[m
         return str(uuid.uuid4())[m
 [m
     # 用户上线（如果用户不存在就创建，存在就更新状态）[m
[31m-    def user_online(self, user_id, user_name, ws):[m
[32m+[m[32m    def user_online(self, user_id: str, user_name: str, ws):[m[41m[m
         self.users[user_id] = {[m
             "user_name": user_name,[m
             "ws": ws,[m
[36m@@ -43,25 +43,25 @@[m [mclass UserManager:[m
         logger.info(f"用户上线 {user_id}: {user_name}")[m
 [m
     # 用户离线（只修改状态，不删除！）[m
[31m-    def user_offline(self, user_id):[m
[32m+[m[32m    def user_offline(self, user_id: str):[m[41m[m
         if user_id in self.users:[m
             self.users[user_id]["ws"] = None  # 清空连接[m
             self.users[user_id]["online"] = False  # 只改在线状态[m
             logger.info(f"用户离线：{user_id} | {self.users[user_id]['user_name']}")[m
 [m
     # 判断用户是否在线[m
[31m-    def is_online(self, user_id):[m
[32m+[m[32m    def is_online(self, user_id: str):[m[41m[m
         return self.users.get(user_id, {}).get("online", False)[m
 [m
     # 根据 user_id 获取用户名[m
[31m-    def get_user_name(self, user_id):[m
[32m+[m[32m    def get_user_name(self, user_id: str) -> str:[m[41m[m
         user = self.users.get(user_id)[m
         if user:[m
             return user["user_name"][m
         return "未知用户"[m
 [m
     # 获取用户的 websocket（用于发消息）[m
[31m-    def get_user_ws(self, user_id):[m
[32m+[m[32m    def get_user_ws(self, user_id: str):[m[41m[m
         user = self.users.get(user_id)[m
         if user and user["online"]:[m
             return user["ws"][m
[1mdiff --git a/frontend/index.html b/frontend/index.html[m
[1mindex 3dc87a7..5e65911 100644[m
[1m--- a/frontend/index.html[m
[1m+++ b/frontend/index.html[m
[36m@@ -4,31 +4,146 @@[m
     <meta charset="UTF-8">[m
     <title>RoomTalk 聊天室主页</title>[m
     <style>[m
[31m-        /* 基础样式 */[m
[32m+[m[32m        /* 全局布局：左右分栏 + 可拖动 */[m[41m[m
[32m+[m[32m        * {[m[41m[m
[32m+[m[32m            margin: 0;[m[41m[m
[32m+[m[32m            padding: 0;[m[41m[m
[32m+[m[32m            box-sizing: border-box;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
         body {[m
             font-family: Arial, sans-serif;[m
             background: #f5f5f5;[m
             margin: 0;[m
[31m-            padding: 20px;[m
[32m+[m[32m            padding: 0;[m[41m[m
[32m+[m[32m            height: 100vh;[m[41m[m
[32m+[m[32m            overflow: hidden;[m[41m[m
         }[m
 [m
[31m-        /* 创建房间按钮 */[m
[31m-        #createRoomBtn {[m
[31m-            padding: 10px 20px;[m
[31m-            font-size: 16px;[m
[32m+[m[32m        /* 最外层容器：左右布局 */[m[41m[m
[32m+[m[32m        .app-container {[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            width: 100vw;[m[41m[m
[32m+[m[32m            height: 100vh;[m[41m[m
[32m+[m[32m            overflow: hidden;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 左侧：房间列表栏 */[m[41m[m
[32m+[m[32m        .left-sidebar {[m[41m[m
[32m+[m[32m            width: 320px;[m[41m[m
[32m+[m[32m            min-width: 220px;[m[41m[m
[32m+[m[32m            max-width: 450px;[m[41m[m
[32m+[m[32m            height: 100%;[m[41m[m
[32m+[m[32m            background: #fff;[m[41m[m
[32m+[m[32m            border-right: 1px solid #eee;[m[41m[m
[32m+[m[32m            padding: 15px;[m[41m[m
[32m+[m[32m            overflow-y: auto;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 拖动条 */[m[41m[m
[32m+[m[32m        .drag-divider {[m[41m[m
[32m+[m[32m            width: 6px;[m[41m[m
[32m+[m[32m            background: #eaeaea;[m[41m[m
[32m+[m[32m            cursor: col-resize;[m[41m[m
[32m+[m[32m            height: 100%;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[32m        .drag-divider:hover {[m[41m[m
[32m+[m[32m            background: #ccc;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 右侧：聊天区域 */[m[41m[m
[32m+[m[32m        .right-chat-area {[m[41m[m
[32m+[m[32m            flex: 1;[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            flex-direction: column;[m[41m[m
[32m+[m[32m            padding: 15px;[m[41m[m
[32m+[m[32m            height: 100%;[m[41m[m
[32m+[m[32m            overflow: hidden;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m            /* 初始隐藏聊天区,占据位置即可 */[m[41m[m
[32m+[m[32m            visibility: hidden;[m[41m[m
[32m+[m[32m            opacity: 0;[m[41m[m
[32m+[m[32m            transition: opacity 0.2s ease;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 显示聊天区 */[m[41m[m
[32m+[m[32m        .right-chat-area.show {[m[41m[m
[32m+[m[32m            visibility: visible;[m[41m[m
[32m+[m[32m            opacity: 1;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .chat-container {[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            flex-direction: column;[m[41m[m
[32m+[m[32m            height: 100%;[m[41m[m
[32m+[m[32m            gap: 10px;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 房间标题 */[m[41m[m
[32m+[m[32m        .room-title {[m[41m[m
[32m+[m[32m            padding: 0 5px;[m[41m[m
[32m+[m[32m            font-size: 14px;[m[41m[m
[32m+[m[32m            color: #333;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 输入文本框：固定高度 */[m[41m[m
[32m+[m[32m        .message-input-bar {[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            gap: 8px;[m[41m[m
[32m+[m[32m            padding: 10px;[m[41m[m
[32m+[m[32m            border-top: 1px solid #eee;[m[41m[m
[32m+[m[32m            background: #fff;[m[41m[m
[32m+[m[32m            border-radius: 8px;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 基础样式 */[m[41m[m
[32m+[m[32m        #createRoomBtn, #refreshBtn {[m[41m[m
[32m+[m[32m            padding: 8px 14px;[m[41m[m
[32m+[m[32m            font-size: 14px;[m[41m[m
             background: #409eff;[m
             color: white;[m
             border: none;[m
             border-radius: 6px;[m
             cursor: pointer;[m
[32m+[m[32m            margin-right: 6px;[m[41m[m
[32m+[m[32m            margin-bottom: 10px;[m[41m[m
         }[m
[31m-        #createRoomBtn:hover {[m
[32m+[m[41m[m
[32m+[m[32m        /* 输入框 */[m[41m[m
[32m+[m[32m        .message-input-bar input {[m[41m[m
[32m+[m[32m            flex: 1;[m[41m[m
[32m+[m[32m            padding: 10px 12px;[m[41m[m
[32m+[m[32m            border: 1px solid #ddd;[m[41m[m
[32m+[m[32m            border-radius: 6px;[m[41m[m
[32m+[m[32m            font-size: 14px;[m[41m[m
[32m+[m[32m            outline: none;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .message-input-bar input:focus {[m[41m[m
[32m+[m[32m            border-color: #409eff;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 发送按钮 */[m[41m[m
[32m+[m[32m        .message-input-bar button {[m[41m[m
[32m+[m[32m            padding: 10px 18px;[m[41m[m
[32m+[m[32m            background: #409eff;[m[41m[m
[32m+[m[32m            color: #fff;[m[41m[m
[32m+[m[32m            border: none;[m[41m[m
[32m+[m[32m            border-radius: 6px;[m[41m[m
[32m+[m[32m            cursor: pointer;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .message-input-bar button:hover {[m[41m[m
[32m+[m[32m            background: #337ecc;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        #createRoomBtn:hover, #refreshBtn:hover {[m[41m[m
             background: #337ecc;[m
         }[m
 [m
         /* 弹窗遮罩层 */[m
         .modal {[m
[31m-            display: none; /* 默认隐藏 */[m
[32m+[m[32m            display: none;[m[41m[m
             position: fixed;[m
             left: 0;[m
             top: 0;[m
[36m@@ -37,9 +152,9 @@[m
             background: rgba(0,0,0,0.5);[m
             justify-content: center;[m
             align-items: center;[m
[32m+[m[32m            z-index: 9999;[m[41m[m
         }[m
 [m
[31m-        /* 弹窗内容 */[m
         .modal-content {[m
             background: white;[m
             padding: 30px;[m
[36m@@ -48,7 +163,6 @@[m
             text-align: center;[m
         }[m
 [m
[31m-        /* 输入框 & 按钮 */[m
         input {[m
             width: 80%;[m
             padding: 8px;[m
[36m@@ -72,135 +186,662 @@[m
             cursor: pointer;[m
             margin-left: 10px;[m
         }[m
[32m+[m[41m[m
[32m+[m[32m        .user-info-tag {[m[41m[m
[32m+[m[32m            position: absolute;[m[41m[m
[32m+[m[32m            top: 10px;[m[41m[m
[32m+[m[32m            right: 10px;[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            align-items: center;[m[41m[m
[32m+[m[32m            gap: 8px;[m[41m[m
[32m+[m[32m            background: #f0f0f0;[m[41m[m
[32m+[m[32m            padding: 6px 10px;[m[41m[m
[32m+[m[32m            border-radius: 20px;[m[41m[m
[32m+[m[32m            cursor: pointer;[m[41m[m
[32m+[m[32m            z-index: 100;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .avatar {[m[41m[m
[32m+[m[32m            width: 32px;[m[41m[m
[32m+[m[32m            height: 32px;[m[41m[m
[32m+[m[32m            border-radius: 50%;[m[41m[m
[32m+[m[32m            background: #ddd;[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            align-items: center;[m[41m[m
[32m+[m[32m            justify-content: center;[m[41m[m
[32m+[m[32m            font-size: 16px;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .user-text {[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            flex-direction: column;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .user-name {[m[41m[m
[32m+[m[32m            font-size: 14px;[m[41m[m
[32m+[m[32m            font-weight: bold;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .user-id {[m[41m[m
[32m+[m[32m            font-size: 10px;[m[41m[m
[32m+[m[32m            color: #666;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 房间列表 */[m[41m[m
[32m+[m[32m        .room_list {[m[41m[m
[32m+[m[32m            margin-top: 10px;[m[41m[m
[32m+[m[32m            padding: 15px;[m[41m[m
[32m+[m[32m            border: 1px solid #eee;[m[41m[m
[32m+[m[32m            border-radius: 8px;[m[41m[m
[32m+[m[32m            background: #fafafa;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .room_list ul {[m[41m[m
[32m+[m[32m            list-style: none;[m[41m[m
[32m+[m[32m            padding: 0;[m[41m[m
[32m+[m[32m            margin: 0;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .room_list li {[m[41m[m
[32m+[m[32m            padding: 10px;[m[41m[m
[32m+[m[32m            border-bottom: 1px solid #f0f0f0;[m[41m[m
[32m+[m[32m            cursor: pointer;[m[41m[m
[32m+[m[32m            border-radius: 4px;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .room_list li:hover {[m[41m[m
[32m+[m[32m            background: #f0f7ff;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 聊天消息容器 */[m[41m[m
[32m+[m[32m        .chat-history {[m[41m[m
[32m+[m[32m            flex: 1;[m[41m[m
[32m+[m[32m            border: 1px solid #eee;[m[41m[m
[32m+[m[32m            border-radius: 8px;[m[41m[m
[32m+[m[32m            background: #fff;[m[41m[m
[32m+[m[32m            overflow-y: auto;[m[41m[m
[32m+[m[32m            position: relative;[m[41m[m
[32m+[m[32m            padding: 10px;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 单条消息容器 */[m[41m[m
[32m+[m[32m        .msg-item {[m[41m[m
[32m+[m[32m            display: flex;[m[41m[m
[32m+[m[32m            margin: 10px 0;[m[41m[m
[32m+[m[32m            align-items: flex-start;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .self-msg {[m[41m[m
[32m+[m[32m            flex-direction: row-reverse;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .msg-avatar {[m[41m[m
[32m+[m[32m            width: 40px;[m[41m[m
[32m+[m[32m            height: 40px;[m[41m[m
[32m+[m[32m            border-radius: 50%;[m[41m[m
[32m+[m[32m            background: #409eff;[m[41m[m
[32m+[m[32m            color: #fff;[m[41m[m
[32m+[m[32m            text-align: center;[m[41m[m
[32m+[m[32m            line-height: 40px;[m[41m[m
[32m+[m[32m            font-size: 16px;[m[41m[m
[32m+[m[32m            margin: 0 10px;[m[41m[m
[32m+[m[32m            flex-shrink: 0;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .msg-content {[m[41m[m
[32m+[m[32m            max-width: 65%;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .msg-name {[m[41m[m
[32m+[m[32m            font-size: 12px;[m[41m[m
[32m+[m[32m            color: #999;[m[41m[m
[32m+[m[32m            margin-bottom: 4px;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .msg-bubble {[m[41m[m
[32m+[m[32m            padding: 8px 12px;[m[41m[m
[32m+[m[32m            border-radius: 8px;[m[41m[m
[32m+[m[32m            background: #f4f4f4;[m[41m[m
[32m+[m[32m            word-wrap: break-word;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .self-msg .msg-bubble {[m[41m[m
[32m+[m[32m            background: #409eff;[m[41m[m
[32m+[m[32m            color: #fff;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        /* 密码弹窗 */[m[41m[m
[32m+[m[32m        .room-pwd-modal {[m[41m[m
[32m+[m[32m            position: absolute;[m[41m[m
[32m+[m[32m            top: 0;[m[41m[m
[32m+[m[32m            left: 0;[m[41m[m
[32m+[m[32m            right: 0;[m[41m[m
[32m+[m[32m            bottom: 0;[m[41m[m
[32m+[m[32m            background: rgba(255, 255, 255, 0.85);[m[41m[m
[32m+[m[32m            z-index: 999;[m[41m[m
[32m+[m[32m            display: none;[m[41m[m
[32m+[m[32m            align-items: center;[m[41m[m
[32m+[m[32m            justify-content: center;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        .pwd-box {[m[41m[m
[32m+[m[32m            padding: 20px;[m[41m[m
[32m+[m[32m            background: #fff;[m[41m[m
[32m+[m[32m            border-radius: 8px;[m[41m[m
[32m+[m[32m            box-shadow: 0 0 10px #ccc;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        #roomPasswordInputWrap {[m[41m[m
[32m+[m[32m            display: none;[m[41m[m
[32m+[m[32m            margin: 15px 0;[m[41m[m
[32m+[m[32m        }[m[41m        [m
     </style>[m
 </head>[m
 <body>[m
[31m-    <button id="createRoomBtn">创建房间</button>[m
[31m-[m
[31m-    <!-- 点击创建房间后的事件界面 -->[m
[31m-    <div id="createModal" class="modal">[m
[31m-        <div class="modal-content">[m
[31m-            <p>创建新房间</p>[m
[31m-            <input type="text" id="roomName" placeholder="房间名称（可选）">[m
[31m-            <button class="confirmBtn" onclick="createRoom()">确认创建</button>[m
[31m-            <button class="cancelBtn" onclick="closeModal()">取消创建</button>[m
[32m+[m[41m[m
[32m+[m[32m<!-- 最外层布局容器 -->[m[41m[m
[32m+[m[32m<div class="app-container">[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    <!-- 左侧：房间列表 -->[m[41m[m
[32m+[m[32m    <div class="left-sidebar" id="leftSidebar">[m[41m[m
[32m+[m[32m        <div id="userInfoTag" class="user-info-tag">[m[41m[m
[32m+[m[32m            <div id="userAvater" class="avatar">[m[41m[m
[32m+[m[32m                <span id="defaultAvatarIcon">👤</span>[m[41m[m
[32m+[m[32m            </div>[m[41m[m
[32m+[m[32m            <div class="user-text">[m[41m[m
[32m+[m[32m                <div id="displayUserName" class="user-name">加载中...</div>[m[41m[m
[32m+[m[32m                <div id="displayUserId" class="user-id"></div>[m[41m[m
[32m+[m[32m            </div>[m[41m[m
         </div>[m
[32m+[m[41m[m
[32m+[m[32m        <button id="createRoomBtn">创建房间</button>[m[41m[m
[32m+[m[32m        <button id="refreshBtn">刷新房间</button>[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        <div class="room_list">[m[41m[m
[32m+[m[32m            <h3>房间列表</h3>[m[41m[m
[32m+[m[32m            <ul id="room_list"></ul>[m[41m[m
[32m+[m[32m        </div>[m[41m[m
[32m+[m[32m    </div>[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    <!-- 可拖动分割线 -->[m[41m[m
[32m+[m[32m    <div class="drag-divider" id="dragDivider"></div>[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    <!-- 右侧：聊天区域 -->[m[41m[m
[32m+[m[32m    <div id="rightChatArea" class="right-chat-area">[m[41m[m
[32m+[m[32m        <div id="chatContainer" class="chat-container">[m[41m[m
[32m+[m[32m            <div class="room-title">[m[41m[m
[32m+[m[32m                <h3>房间名: 测试房间</h3>[m[41m[m
[32m+[m[32m            </div>[m[41m[m
[32m+[m[32m            <div id="chatHistory" class="chat-history"></div>[m[41m[m
[32m+[m[32m            <div class="message-input-bar">[m[41m[m
[32m+[m[32m                <input type="text" id="msgInput" placeholder="输入消息...">[m[41m[m
[32m+[m[32m                <button id="sendBtn">发送</button>[m[41m[m
[32m+[m[32m            </div>[m[41m[m
[32m+[m[32m        </div>[m[41m[m
[32m+[m[32m    </div>[m[41m[m
[32m+[m[32m</div>[m[41m[m
[32m+[m[41m[m
[32m+[m[32m<!-- 私域房间密码弹窗 -->[m[41m[m
[32m+[m[32m<div id="pwdModal" class="room-pwd-modal">[m[41m[m
[32m+[m[32m    <div class="pwd-box">[m[41m[m
[32m+[m[32m        <h4>私域房间，请输入密码</h4>[m[41m[m
[32m+[m[32m        <input type="password" placeholder="输入密码" id="roomPwdInput">[m[41m[m
[32m+[m[32m        <button id="confirmPwdBtn">确认加入</button>[m[41m[m
[32m+[m[32m        <button id="cancelPwdBtn">取消</button>[m[41m[m
     </div>[m
[32m+[m[32m</div>[m[41m[m
 [m
[31m-    <button id="refreshBtn">刷新房间列表</button>[m
[32m+[m[32m<!-- 创建房间弹窗 -->[m[41m[m
[32m+[m[32m<div id="createModal" class="modal">[m[41m[m
[32m+[m[32m    <div class="modal-content">[m[41m[m
[32m+[m[32m        <p>创建新房间</p>[m[41m[m
[32m+[m[32m        <input type="text" id="roomName" placeholder="房间名称（可选）">[m[41m[m
[32m+[m[32m        <label>房间类型选择：</label>[m[41m[m
[32m+[m[32m        <select id="roomTypeSelBtn">[m[41m[m
[32m+[m[32m            <option value="0" selected>公域</option>[m[41m[m
[32m+[m[32m            <option value="1">私域</option>[m[41m[m
[32m+[m[32m        </select>[m[41m[m
 [m
[31m-    <div class="room_list">[m
[31m-        <h3>房间列表</h3>[m
[31m-        <ul id="room_list"></ul>[m
[32m+[m[32m        <div id="roomPasswordInputWrap">[m[41m[m
[32m+[m[32m            <label>房间密码</label>[m[41m[m
[32m+[m[32m            <input type="password" id="roomPasswordInput" placeholder="请输入私域房间密码">[m[41m[m
[32m+[m[32m        </div>[m[41m[m
[32m+[m[32m        <button class="confirmBtn" onclick="createRoom()">确认创建</button>[m[41m[m
[32m+[m[32m        <button class="cancelBtn" onclick="closeModal()">取消</button>[m[41m[m
     </div>[m
[32m+[m[32m</div>[m[41m[m
[32m+[m[41m[m
[32m+[m[32m<script>[m[41m[m
[32m+[m[32m    let user_data = null;[m[41m[m
[32m+[m[32m    let current_joining_room = null;[m[41m[m
[32m+[m[32m    let room_list = [];[m[41m[m
[32m+[m[32m    let waitAckMap = {} //消息等待确认池[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    let lastServerResponseTime = Date.now();[m[41m[m
[32m+[m[32m    let heartbeatTimer = null;      // 心跳定时器[m[41m[m
[32m+[m[32m    let reconnectTimeOut = null;    // 重连定时器[m[41m[m
[32m+[m[32m    const HEARTBEAT_INTERVAL = 30000;  // 30秒心跳[m[41m[m
 [m
[31m-    <script>[m
[31m-        // 房间列表[m
[31m-        let room_list = [][m
[32m+[m[32m    // 连接函数[m[41m[m
[32m+[m[32m    function connectWebSocket() {[m[41m[m
[32m+[m[32m        const wsUrl = "ws://" + window.location.hostname + ":10000";[m[41m[m
[32m+[m[32m        ws = new WebSocket(wsUrl);[m[41m[m
 [m
[31m-        // 前端连接 websocket[m
[31m-        const ws = new WebSocket("ws://" + window.location.hostname + ":10000");[m
[31m-        // 连接成功[m
[32m+[m[32m        // 连接建立[m[41m[m
         ws.onopen = function() {[m
             console.log("WebSocket 连接成功");[m
[31m-            ws.send(JSON.stringify({[m
[31m-                "type": "synchro_room_list",[m
[31m-                "data": {[m
 [m
[31m-                }[m
[31m-            }))[m
[32m+[m[32m            // 清空重连定时器[m[41m[m
[32m+[m[32m            if (reconnectTimeOut) clearTimeout(reconnectTimeOut);[m[41m[m
[32m+[m[41m[m
[32m+[m[32m            // 发送房间同步指令[m[41m[m
[32m+[m[32m            ws.send(JSON.stringify({ type: "synchro_room_list" }));[m[41m[m
[32m+[m[41m[m
[32m+[m[32m            stopHeartbeat();[m[41m[m
[32m+[m[41m[m
[32m+[m[32m            //  启动心跳定时器[m[41m[m
[32m+[m[32m            startHeartbeat();[m[41m[m
         };[m
[31m-        // 拿到 弹窗[m
[31m-        const modal = document.getElementById("createModal");[m
[31m-        // 拿到 按钮[m
[31m-        const createBtn = document.getElementById("createRoomBtn");[m
 [m
[31m-        // 接收后端消息[m
[32m+[m[32m        // 监听后端发来的消息[m[41m[m
         ws.onmessage = function(evt) {[m
             const data = JSON.parse(evt.data);[m
             console.log("后端返回：", data);[m
[32m+[m[32m            lastServerResponseTime = Date.now();    // 刷新服务最后一次发送时间[m[41m[m
[32m+[m[41m[m
 [m
             // 处理后端返回的消息[m
             switch(data.type) {[m
[32m+[m[32m                case "init_user":[m[41m[m
[32m+[m[32m                    user_data = {[m[41m[m
[32m+[m[32m                        user_id: data.data.user_id,[m[41m[m
[32m+[m[32m                        user_name: data.data.user_name[m[41m[m
[32m+[m[32m                    };[m[41m[m
[32m+[m[32m                    // 更新用户信息[m[41m[m
[32m+[m[32m                    document.getElementById("displayUserName").innerText = user_data.user_name;[m[41m[m
[32m+[m[32m                    document.getElementById("displayUserId").innerText = `UID: ${user_data.user_id.slice(-6)}`;[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[41m[m
                 case "create_room_success":[m
[31m-                    const newRoom = {[m
[32m+[m[32m                    room_list.push({[m[41m[m
                         room_id: data.data.room_id,[m
[31m-                        room_name: data.data.room_name[m
[31m-                    };[m
[31m-                    room_list.push(newRoom); // 前端自己加！不用等后端[m
[31m-                    renderRoomList();       // 刷新列表[m
[32m+[m[32m                        room_type: data.data.room_type,[m[41m[m
[32m+[m[32m                        room_name: data.data.room_name,[m[41m[m
[32m+[m[32m                    });[m[41m[m
[32m+[m[32m                    renderRoomList();[m[41m[m
                     alert("创建房间成功！");[m
[31m-                break;[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[41m[m
                 case "create_room_fail":[m
[31m-                    alert("创建房间失败")[m
[32m+[m[32m                    alert("创建房间失败");[m[41m[m
                     break;[m
[32m+[m[41m[m
                 case "room_list":[m
[31m-                    // 数据同步[m
                     room_list = data.data.rooms;[m
[31m-                    renderRoomList();   // 渲染列表[m
[32m+[m[32m                    renderRoomList();[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m                case "join_room_success":[m[41m[m
[32m+[m[32m                    document.querySelector(".right-chat-area").classList.add("show")[m[41m[m
[32m+[m[32m                    // 加载历史消息[m[41m[m
[32m+[m[32m                    load_history_messages(data.data.his_msg);[m[41m[m
                     break;[m
[31m-            }[m
 [m
[32m+[m[32m                case "join_room_fail":[m[41m[m
[32m+[m[32m                    alert(`加入失败：${data.data.msg || "未知错误"}`);[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m                case "new_message":[m[41m[m
[32m+[m[32m                    new_message_processing(data.data);[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m                case "heartbeat_ack":[m[41m[m
[32m+[m[32m                    // 清除定时器的任务[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[32m            }[m[41m[m
         };[m
 [m
[31m-        // 点击按钮 → 弹出窗口[m
[31m-        createBtn.onclick = function() {[m
[31m-            modal.style.display = "flex";[m
[32m+[m[41m[m
[32m+[m[32m        // 连接关闭 -> 自动重连[m[41m[m
[32m+[m[32m        ws.onclose = function () {[m[41m[m
[32m+[m[32m            console.log("连接断开，尝试重连中");[m[41m[m
[32m+[m[32m            stopHeartbeat();    //[m[41m[m
[32m+[m[32m            scheduleReconnect(); // 自动重连[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 连接错误[m[41m[m
[32m+[m[32m        ws.onerror = function (err) {[m[41m[m
[32m+[m[32m            console.log("webSocket错误", err);[m[41m[m
         }[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 心跳发送[m[41m[m
[32m+[m[32m    function startHeartbeat() {[m[41m[m
[32m+[m[32m        heartbeatTimer = setInterval(() => {[m[41m[m
[32m+[m[32m            if (ws.readyState === WebSocket.OPEN) {[m[41m[m
[32m+[m[32m                // 发送心跳包[m[41m[m
[32m+[m[32m                ws.send(JSON.stringify({[m[41m[m
[32m+[m[32m                    type: "heartbeat"[m[41m[m
[32m+[m[32m                }));[m[41m[m
[32m+[m[32m                console.log("心跳发送")[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m        }, HEARTBEAT_INTERVAL);[m[41m[m
[32m+[m[32m    }[m[41m[m
 [m
[31m-        // 确认创建[m
[31m-        function createRoom() {[m
[31m-            if (ws.readyState !== WebSocket.OPEN) {[m
[31m-                alert("WebSocket 未连接，请稍后再试");[m
[31m-                return;[m
[32m+[m[32m    // 超时检测[m[41m[m
[32m+[m[32m    function startTimeoutCheck() {[m[41m[m
[32m+[m[32m        timeoutTimer = setTimeout(() => {[m[41m[m
[32m+[m[32m            // 获取当前时间戳[m[41m[m
[32m+[m[32m            const now = Date.now();[m[41m[m
[32m+[m[32m            // 计算超时[m[41m[m
[32m+[m[32m            if (now - lastServerResponseTime > HEARTBEAT_INTERVAL) {[m[41m[m
[32m+[m[32m                console.log("服务器超时无响应，重连中...")[m[41m[m
[32m+[m[32m                // 启动重连定时器[m[41m[m
[32m+[m[32m                scheduleReconnect();[m[41m[m
             }[m
[31m-            let roomName = document.getElementById("roomName").value;   // 获取用户输入的房间名[m
[31m-            closeModal();   // 关闭弹窗[m
[32m+[m[32m        })[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 停止心跳[m[41m[m
[32m+[m[32m    function stopHeartbeat() {[m[41m[m
[32m+[m[32m        if (heartbeatTimer) {[m[41m[m
[32m+[m[32m            clearInterval(heartbeatTimer);[m[41m[m
[32m+[m[32m            heartbeatTimer = null;  // 清空变量，防止旧引用[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 自动重连[m[41m[m
[32m+[m[32m    function scheduleReconnect() {[m[41m[m
[32m+[m[32m        if (reconnectTimeOut) clearTimeout(reconnectTimeOut);   //防止重连叠加[m[41m[m
[32m+[m[32m        ws.close();[m[41m[m
[32m+[m[32m        reconnectTimeOut = setTimeout(() => {[m[41m[m
[32m+[m[32m            connectWebSocket();[m[41m[m
[32m+[m[32m        }, 3000);[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 新消息广播处理[m[41m[m
[32m+[m[32m    function new_message_processing(data) {[m[41m[m
[32m+[m[32m        msg_id = data.msg_id;[m[41m[m
 [m
[31m-            // 发送给后端 → 固定格式[m
[32m+[m[32m        if (user_data.user_id == data.user_id) {[m[41m[m
[32m+[m[32m            // 自己发送的消息，不渲染，并清除消息超时任务[m[41m[m
[32m+[m[32m            if (waitAckMap[msg_id]) {[m[41m[m
[32m+[m[32m                clearTimeout(msg_id);[m[41m[m
[32m+[m[32m                delete waitAckMap[msg_id];[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m            return;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 追加消息[m[41m[m
[32m+[m[32m        append_single_message(data);[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 启动[m[41m[m
[32m+[m[32m    connectWebSocket();[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 房间点击绑定以及渲染列表[m[41m[m
[32m+[m[32m    function renderRoomList() {[m[41m[m
[32m+[m[32m        const ul = document.getElementById("room_list");[m[41m[m
[32m+[m[32m        ul.innerHTML = "";[m[41m[m
[32m+[m[32m        room_list.forEach(room => {[m[41m[m
[32m+[m[32m            const li = document.createElement("li");[m[41m[m
[32m+[m[32m            const icon = room.room_type == 1 ? "🔒" : "💬";[m[41m[m
[32m+[m[32m            li.innerText = `${icon} 房间号：${room.room_id} | ${room.room_name}`;[m[41m[m
[32m+[m[32m            li.onclick = () => handleRoomClick(room);[m[41m[m
[32m+[m[32m            ul.appendChild(li);[m[41m[m
[32m+[m[32m        });[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 处理房间点击事件[m[41m[m
[32m+[m[32m    function handleRoomClick(room) {[m[41m[m
[32m+[m[32m        if (!user_data) { alert("用户信息未加载"); return; }[m[41m[m
[32m+[m[32m        current_joining_room = room;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        if (room.room_type == 1) {[m[41m[m
[32m+[m[32m            document.getElementById("pwdModal").style.display = "flex";[m[41m[m
[32m+[m[32m            // 获取用户输出的密码[m[41m[m
[32m+[m[32m        } else {[m[41m[m
             ws.send(JSON.stringify({[m
[31m-                type: "create_room",        // 类型：创建房间[m
[32m+[m[32m                type: "join_room",[m[41m[m
                 data: {[m
[31m-                    user_id: "张三",[m
[31m-                    room_name: roomName     // 传给后端的数据[m
[32m+[m[32m                    room_id: room.room_id,[m[41m[m
[32m+[m[32m                    user_id: user_data.user_id[m[41m[m
                 }[m
             }));[m
         }[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 关闭密码弹窗[m[41m[m
[32m+[m[32m    function closePwdModal() {[m[41m[m
[32m+[m[32m        document.getElementById("pwdModal").style.display = "none";[m[41m[m
[32m+[m[32m        document.getElementById("roomPwdInput").value = "";[m[41m[m
[32m+[m[32m        current_joining_room = null;[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 私域房间确认密码[m[41m[m
[32m+[m[32m    document.getElementById("confirmPwdBtn").onclick = function() {[m[41m[m
[32m+[m[32m        const pwd = document.getElementById("roomPwdInput").value.trim();[m[41m[m
[32m+[m[32m        if (!pwd) return alert("请输入密码");[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        ws.send(JSON.stringify({[m[41m[m
[32m+[m[32m            type: "join_room",[m[41m[m
[32m+[m[32m            data: {[m[41m[m
[32m+[m[32m                room_id: current_joining_room.room_id,[m[41m[m
[32m+[m[32m                password: pwd,[m[41m[m
[32m+[m[32m                user_id: user_data.user_id[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m        }));[m[41m[m
[32m+[m[32m        closePwdModal();[m[41m[m
[32m+[m[32m    };[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 取消[m[41m[m
[32m+[m[32m    document.getElementById("cancelPwdBtn").onclick = closePwdModal;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 创建房间[m[41m[m
[32m+[m[32m    const modal = document.getElementById("createModal");[m[41m[m
[32m+[m[32m    document.getElementById("createRoomBtn").onclick = () => modal.style.display = "flex";[m[41m[m
[32m+[m[32m    function closeModal() { modal.style.display = "none"; }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 监听选择房间的类型[m[41m[m
[32m+[m[32m    document.getElementById("roomTypeSelBtn").addEventListener("change", function() {[m[41m[m
[32m+[m[32m        const roomType = this.value;[m[41m[m
[32m+[m[32m        document.getElementById("roomPasswordInputWrap").style.display = roomType == "1" ? "block" : "none";[m[41m[m
[32m+[m[32m    })[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 创建房间[m[41m[m
[32m+[m[32m    function createRoom() {[m[41m[m
[32m+[m[32m        if (!user_data) return alert("请等待用户初始化");[m[41m[m
[32m+[m[32m        // 区分用户创建的房间类型[m[41m[m
[32m+[m[32m        room_name_value = document.getElementById("roomName").value.trim(),[m[41m[m
[32m+[m[32m        room_type_value = document.getElementById("roomTypeSelBtn").value[m[41m[m
[32m+[m[32m        switch(room_type_value) {[m[41m[m
[32m+[m[32m            case "0":[m[41m [m
[32m+[m[32m                ws.send(JSON.stringify({[m[41m[m
[32m+[m[32m                    type: "create_room",[m[41m[m
[32m+[m[32m                    data: {[m[41m[m
[32m+[m[32m                        user_id: user_data.user_id,[m[41m[m
[32m+[m[32m                        room_name: room_name_value,[m[41m[m
[32m+[m[32m                        room_type: room_type_value[m[41m[m
[32m+[m[32m                    }}));[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[32m            case "1":[m[41m[m
[32m+[m[32m                // 获取私域房间的密码[m[41m[m
[32m+[m[32m                password = document.getElementById("roomPasswordInput").value.trim();[m[41m[m
[32m+[m[32m                if(!password) {[m[41m[m
[32m+[m[32m                    alert("私域房间必须设置密码");[m[41m[m
[32m+[m[32m                    return;[m[41m[m
[32m+[m[32m                }[m[41m[m
[32m+[m[32m                ws.send(JSON.stringify({[m[41m[m
[32m+[m[32m                    type: "create_room",[m[41m[m
[32m+[m[32m                    data: {[m[41m[m
[32m+[m[32m                        user_id: user_data.user_id,[m[41m[m
[32m+[m[32m                        room_name: room_name_value,[m[41m[m
[32m+[m[32m                        room_type: room_type_value,[m[41m[m
[32m+[m[32m                        password: password[m[41m[m
[32m+[m[32m                    }}));[m[41m[m
[32m+[m[32m                    break;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        closeModal();[m[41m[m
[32m+[m[32m        document.getElementById("roomName").value = "";[m[41m[m
[32m+[m[32m        document.getElementById("roomPasswordInput").value = "";[m[41m[m
[32m+[m[32m        document.getElementById("roomTypeSelBtn").value = "0";[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 刷新[m[41m[m
[32m+[m[32m    document.getElementById("refreshBtn").onclick = () => {[m[41m[m
[32m+[m[32m        ws.send(JSON.stringify({ type: "synchro_room_list" }));[m[41m[m
[32m+[m[32m    };[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 加载房间历史消息[m[41m[m
[32m+[m[32m    function load_history_messages(msgList) {[m[41m[m
[32m+[m[32m        const chatHistory = document.getElementById("chatHistory");[m[41m[m
[32m+[m[32m        // 进来先清空原有消息[m[41m[m
[32m+[m[32m        chatHistory.innerHTML = "";[m[41m[m
[32m+[m[32m        if (!Array.isArray(msgList)) { console.warn("不是数组"); return; }[m[41m[m
[32m+[m[32m        msgList.forEach(item => append_single_message(item));[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 渲染单条消息[m[41m[m
[32m+[m[32m    function append_single_message(msg) {[m[41m[m
[32m+[m[32m        // 信息是是个三元组 {用户id， 用户名，消息}[m[41m[m
[32m+[m[32m        isSelf = (msg.user_id == user_data.user_id);[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 取用户名最后字符当成用户的头像[m[41m[m
[32m+[m[32m        const avatarText = msg.user_name.charAt(0);[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 获取消息区盒子[m[41m[m
[32m+[m[32m        const charHigstory = document.getElementById("charHigstory");[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 拼接消息[m[41m[m
[32m+[m[32m        const msgHtml = `[m[41m[m
[32m+[m[32m            <div class="msg-item ${isSelf ? 'self-msg' : 'other-msg'}" data-msg-id="${msg.msg_id}">[m[41m[m
[32m+[m[32m                <div class="msg-avatar">${avatarText}</div>[m[41m[m
[32m+[m[32m                <div class="msg-content">[m[41m[m
[32m+[m[32m                    <div class="msg-name">${msg.user_name}</div>[m[41m[m
[32m+[m[32m                    <div class="msg-bubble">${msg.body}</div>[m[41m[m
[32m+[m[32m                </div>[m[41m[m
[32m+[m[32m            </div>[m[41m[m
[32m+[m[32m        `;[m[41m[m
[32m+[m[32m        //  追加到消息区[m[41m[m
[32m+[m[32m        chatHistory.innerHTML += msgHtml;[m[41m[m
[32m+[m[32m        // 滚动到底部[m[41m[m
[32m+[m[32m        chatHistory.scrollTop = chatHistory.scrollHeight;[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 可拖动逻辑（LeetCode效果）[m[41m[m
[32m+[m[32m    const leftSidebar = document.getElementById('leftSidebar');[m[41m[m
[32m+[m[32m    const dragDivider = document.getElementById('dragDivider');[m[41m[m
[32m+[m[32m    let isDragging = false;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    dragDivider.addEventListener('mousedown', (e) => {[m[41m[m
[32m+[m[32m        isDragging = true;[m[41m[m
[32m+[m[32m        document.body.style.cursor = 'col-resize';[m[41m[m
[32m+[m[32m        e.preventDefault();[m[41m[m
[32m+[m[32m    });[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    document.addEventListener('mousemove', (e) => {[m[41m[m
[32m+[m[32m        if (!isDragging) return;[m[41m[m
[32m+[m[32m        let w = e.clientX;[m[41m[m
[32m+[m[32m        if (w < 220) w = 220;[m[41m[m
[32m+[m[32m        if (w > 450) w = 450;[m[41m[m
[32m+[m[32m        leftSidebar.style.width = w + 'px';[m[41m[m
[32m+[m[32m    });[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    document.addEventListener('mouseup', () => {[m[41m[m
[32m+[m[32m        isDragging = false;[m[41m[m
[32m+[m[32m        document.body.style.cursor = 'default';[m[41m[m
[32m+[m[32m    });[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    // 消息发送[m[41m[m
[32m+[m[32m    function sendMessage() {[m[41m[m
[32m+[m[32m        // 获取消息文本框数据[m[41m[m
[32m+[m[32m        const input = document.getElementById("msgInput");[m[41m[m
[32m+[m[32m        const content = input.value;[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 消息判断[m[41m[m
[32m+[m[32m        if (!content.trim()){[m[41m[m
[32m+[m[32m            // 空白内容，直接不处理[m[41m[m
[32m+[m[32m            return;[m[41m[m
[32m+[m[32m        }[m[41m[m
 [m
[31m-        // 关闭弹窗[m
[31m-        function closeModal() {[m
[31m-            modal.style.display = "none";[m
[32m+[m[32m        // 生成消息id[m[41m[m
[32m+[m[32m        msg_id = "msg_" + Date.now() + Math.random();[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        append_single_message({[m[41m[m
[32m+[m[32m            user_id: user_data.user_id,[m[41m[m
[32m+[m[32m            user_name: user_data.user_name,[m[41m[m
[32m+[m[32m            body: content,[m[41m[m
[32m+[m[32m            msg_id: msg_id[m[41m[m
[32m+[m[32m        })[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 发送原始内容[m[41m[m
[32m+[m[32m        ws.send(JSON.stringify({[m[41m[m
[32m+[m[32m            type: "send_message",[m[41m[m
[32m+[m[32m            data: {[m[41m[m
[32m+[m[32m                user_id: user_data.user_id,[m[41m[m
[32m+[m[32m                room_id: current_joining_room.room_id,[m[41m[m
[32m+[m[32m                msg: content,[m[41m[m
[32m+[m[32m                msg_id: msg_id[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m        }));[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        if (!waitAckMap) {[m[41m[m
[32m+[m[32m            waitAckMap = {};[m[41m[m
         }[m
 [m
[31m-        // 房间列表展示[m
[31m-        function renderRoomList() {[m
[31m-            const ul = document.getElementById("room_list");[m
[31m-            ul.innerHTML = "";  // 清空列表数据[m
[32m+[m[32m        // 消息确认池添加消息超时检测方法[m[41m[m
[32m+[m[32m        const timer = setTimeout(() => {[m[41m[m
[32m+[m[32m            if (typeof markMessageFailed == "function") {[m[41m[m
[32m+[m[32m                markMessageFailed(msg_id);[m[41m[m
[32m+[m[32m            }[m[41m[m
[32m+[m[32m            delete waitAckMap[msg_id];[m[41m[m
[32m+[m[32m        }, 5000);[m[41m[m
 [m
[31m-            room_list.forEach(room => {[m
[31m-                // 创建列表项[m
[31m-                const li = document.createElement("li");[m
[32m+[m[32m        // 添加超时处理任务[m[41m[m
[32m+[m[32m        waitAckMap[msg_id] = timer;[m[41m[m
 [m
[31m-                // 将列表项渲染到列表中[m
[31m-                li.innerText = `房间号：${room.room_id}：${room.room_name}`;[m
[31m-                [m
[31m-                // [m
[32m+[m[32m        // 发送后清空输入文本框[m[41m[m
[32m+[m[32m        input.value = "";[m[41m[m
[32m+[m[32m    }[m[41m[m
 [m
[31m-                ul.appendChild(li);[m
[31m-            })[m
[32m+[m[32m    // 消息发送失败[m[41m[m
[32m+[m[32m    function markMessageFailed(msg_id) {[m[41m[m
[32m+[m[32m        // 找到对应消息元素，添加失败样式[m[41m[m
[32m+[m[32m        const msgItem = document.querySelector(`.msg-item[data-msg-id="${msg_id}"]`);[m[41m[m
[32m+[m[32m        if (msgItem) return;[m[41m[m
[32m+[m[32m        if (!msgItem) {[m[41m[m
[32m+[m[32m            console.log("没有找到消息，可能已被删除");[m[41m[m
[32m+[m[32m            return;[m[41m[m
         }[m
[31m-        [m
[31m-        // 点击刷新 → 才拉全量列表[m
[31m-        document.getElementById("refreshBtn").onclick = function() {[m
[31m-            if (ws.readyState === WebSocket.OPEN) {[m
[31m-                ws.send(JSON.stringify({[m
[31m-                    "type": "synchro_room_list",[m
[31m-                    "data": {[m
[31m-                        [m
[31m-                    }[m
[31m-                }));[m
[32m+[m[32m        // 找到气泡[m[41m[m
[32m+[m[32m        const buttle = msgItem.querySelector(".msg-buttle");[m[41m[m
[32m+[m[32m        if (!buttle) {[m[41m[m
[32m+[m[32m            console.log("没有找到消息，可能已被删除");[m[41m[m
[32m+[m[32m            return;[m[41m[m
[32m+[m[32m        }[m[41m[m
[32m+[m[32m        // 标红样式[m[41m[m
[32m+[m[32m        msgItem.style.opacity = "0.8";[m[41m[m
[32m+[m[32m        bubble.style.background = "#ff4444";[m[41m[m
[32m+[m[32m        bubble.style.color = "#fff";[m[41m[m
[32m+[m[41m[m
[32m+[m[32m        // 前面加感叹号 ❗[m[41m[m
[32m+[m[32m        bubble.innerText = "❗" + bubble.innerText;[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m    //等待页面加载完成，再绑定事件[m[41m[m
[32m+[m[32m    window.onload = function() {[m[41m[m
[32m+[m[32m        document.getElementById("sendBtn").onclick = sendMessage;[m[41m[m
[32m+[m[41m    [m
[32m+[m[32m        document.getElementById("msgInput").onkeydown = (e) => {[m[41m[m
[32m+[m[32m            if (e.key == "Enter") {[m[41m[m
[32m+[m[32m                e.preventDefault(); // 防止输入框换行[m[41m[m
[32m+[m[32m                sendMessage();[m[41m[m
             }[m
[31m-        };[m
[31m-    </script>[m
[32m+[m[32m        }[m[41m[m
[32m+[m[32m    }[m[41m[m
[32m+[m[41m[m
[32m+[m[32m</script>[m[41m[m
[32m+[m[41m[m
 </body>[m
 </html>[m
\ No newline at end of file[m
