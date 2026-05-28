import logging


import account_manager
import user_connection_manager
import user_info_manager
from settings import settings
from utils import init_project_logger

init_project_logger()
logger = logging.getLogger(__name__)

class UserManager:
    __instance = None

    def __init__(self):
        logger.error("禁止创建 userManager 对象，请使用 .instance")

    def _init(self):
        # logger.debug("UserManager 被初始化")
        # 引入三大用户模块
        self.account = account_manager.AccountManager()                     # 用户账号
        self.info = user_info_manager.UserInfoManager()                     # 用户信息
        self.connection = user_connection_manager.UserConnectionManager()   # 用户连接

    @classmethod
    def instance(cls):
        if cls.__instance is None:
            cls.__instance = object.__new__(cls)
            cls.__instance._init()
            # logger.debug(f"instance 调用 id = {id(cls.__instance)}")
        return cls.__instance


            
    # 用户注册
    def register(self, user_name: str, password: str) -> dict:
        ret = self.account.register(password=password)

        acc, uid = ret["account"], ret["uid"]

        # 注册用户信息
        self.info.set_user_info(uid, acc, user_name)

        # logger.debug(f"register 调用 id = {id(self.account)}")
        
        logger.info(f"注册成功：账号 =  {acc}, 用户名 = {user_name}, uid = {uid}")
        return {
            "account": acc,
            "uid": uid,
            "user_name": user_name
        }

    # 用户登录
    def login(self, account: str, password: str) -> str | None:
        # 账号验证
        # logger.debug(f"login 调用 id = {id(self.account)}")

        state =  self.account.login(account, password)
        if state != 0:
            logger.info(f"登录态返回 {state}")
            return str(state)
        
        # 获取账号uid
        uid = self.account.get_uid(account)

        return uid
    
    # 检查账号和uid的匹配情况
    def is_account_to_uid(self, account: str, uid: str) -> bool:
        return self.account.get_uid(account) == uid
    
    # 连接套接字修该
    def user_online(self, uid: str, ws):
        self.connection.user_online(uid, ws)

    # 用户离线
    def user_offline(self, uid: str):
        self.connection.user_offline(uid)
        logger.info(f"用户uid {uid} 离线")

    # 判断用户是否在线
    def is_online(self, uid: str):
        return self.connection.is_online(uid)

    # 根据 user_id 获取用户名
    def get_user_name(self, uid: str) -> str:
        return self.info.get_user_name(uid)

    # 获取用户的 websocket（用于发消息）
    def get_user_ws(self, uid: str):
        return self.connection.get_user_ws(uid)

# 全局用户管理者
usermanager = UserManager.instance()