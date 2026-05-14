import uuid
import logging

from utils import init_root_logger
init_root_logger()

logger = logging.getLogger(__name__)

class UserManager:
    __instance = None

    def __init__(self):
        logger.error("禁止创建 userManager 对象，请使用 .instance")

    def _init(self):
        # 用户列表（永久保存，只改在线状态，不删除）
        # key: user_id
        # value: {
        #   "user_name": xxx,
        #   "ws": websocket | None,
        #   "online": True/False
        # }
        self.users = {}

    @classmethod
    def instance(cls):
        if cls.__instance is None:
            cls.__instance = object.__new__(cls)
            cls.__instance._init()
        return cls.__instance

    # 生成用户唯一id
    def generate_id(self):
        return str(uuid.uuid4())

    # 用户上线（如果用户不存在就创建，存在就更新状态）
    def user_online(self, user_id, user_name, ws):
        self.users[user_id] = {
            "user_name": user_name,
            "ws": ws,
            "online": True  # 标记在线
        }
        logger.info(f"用户上线 {user_id}: {user_name}")

    # 用户离线（只修改状态，不删除！）
    def user_offline(self, user_id):
        if user_id in self.users:
            self.users[user_id]["ws"] = None  # 清空连接
            self.users[user_id]["online"] = False  # 只改在线状态
            logger.info(f"用户离线：{user_id} | {self.users[user_id]['user_name']}")

    # 判断用户是否在线
    def is_online(self, user_id):
        return self.users.get(user_id, {}).get("online", False)

    # 根据 user_id 获取用户名
    def get_user_name(self, user_id):
        user = self.users.get(user_id)
        if user:
            return user["user_name"]
        return "未知用户"

    # 获取用户的 websocket（用于发消息）
    def get_user_ws(self, user_id):
        user = self.users.get(user_id)
        if user and user["online"]:
            return user["ws"]
        return None

# 全局用户管理者
usermanager = UserManager.instance()