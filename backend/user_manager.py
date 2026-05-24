import uuid
import logging
import random
from settings import settings

from utils import init_project_logger, BiDict

init_project_logger()

logger = logging.getLogger(__name__)

class UserManager:
    __instance = None

    def __init__(self):
        logger.error("禁止创建 userManager 对象，请使用 .instance")

    def _init(self):
        # 用户列表
        # key: user_id
        # value: {
        #   "user_name": xxx,
        #   "ws": websocket | None,
        #   "online": True/False
        # }
        self.users = {}

        # 用户账号登录体系
        self.account_map = {}

        # 用户账号和uid的双向映射
        self.account_uid_map = BiDict()

    @classmethod
    def instance(cls):
        if cls.__instance is None:
            cls.__instance = object.__new__(cls)
            cls.__instance._init()
        return cls.__instance

    # 生成用户唯一id
    def generate_id(self) -> str:
        return str(uuid.uuid4())
    
    # 生成用户唯一账号
    def generate_account(self) -> str:
        while True:
            account = random.randint(int(settings.get("user_account_min", 100000000)), int(settings.get("user_account_max", 999999999)))
            if account not in self.account_map:
                return str(account)
            
    # 用户注册
    def register(self, user_name: str, password: str) -> dict:
        account = self.generate_account()
        uid = self.generate_id()

        self.account_map[account] = {
            "uid": uid,
            "user_name": user_name,
            "password": password
        }

        self.account_uid_map.set(account, password)

        logger.info(f"注册成功：账号 = {account}, 用户名 = {user_name}, uid = {uid}")
        return {
            "account": account,
            "uid": uid,
            "user_name": user_name
        }

    # 用户登录
    def login(self, account: str, password: str) -> str | None:
        user = self.account_map[account]
        if not user or password != user["password"]:
            return None
        
        return user["uid"]
    
    # 根据账号查找业务id
    def get_uid_by_account(self, uid):
        return self.account_uid_map.get_by_value(uid)

    # 根据业务id查找账号
    def get_account_by_uid(self, account):
        return self.account_uid_map.get_by_key(account)

    # 用户上线（如果用户不存在就创建，存在就更新状态）
    def user_online(self, user_id: str, user_name: str, ws):
        self.users[user_id] = {
            "user_name": user_name,
            "ws": ws,
            "online": True  # 标记在线
        }
        logger.info(f"用户上线 {user_id}: {user_name}")

    # 用户离线（只修改状态，不删除！）
    def user_offline(self, user_id: str):
        if user_id in self.users:
            self.users[user_id]["ws"] = None  # 清空连接
            self.users[user_id]["online"] = False  # 只改在线状态
            logger.info(f"用户离线：{user_id} | {self.users[user_id]['user_name']}")

    # 判断用户是否在线
    def is_online(self, user_id: str):
        return self.users.get(user_id, {}).get("online", False)

    # 根据 user_id 获取用户名
    def get_user_name(self, user_id: str) -> str:
        user = self.users.get(user_id)
        if user:
            return user["user_name"]
        return "未知用户"

    # 获取用户的 websocket（用于发消息）
    def get_user_ws(self, user_id: str):
        user = self.users.get(user_id)
        if user and user["online"]:
            return user["ws"]
        return None

# 全局用户管理者
usermanager = UserManager.instance()