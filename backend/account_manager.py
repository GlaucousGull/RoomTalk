# user_info_manager.pyimport random

import logging
import random
import uuid
import traceback
from settings import settings
from utils import init_project_logger, BiDict

init_project_logger()

logger = logging.getLogger(__name__)


class AccountManager:
    """账号域：登录、注册、account、password"""
    def __init__(self):
        self.account_map = {}  # key: account
        # logger.debug("AccountManager 被初始化")

    def generate_id(self) -> str:
        return str(uuid.uuid4())

    def generate_account(self) -> str:
        while True:
            account = str(random.randint(
                int(settings.get("user.user_account_min", 100000000)),
                int(settings.get("user.user_account_max", 999999999))
            ))
            if account not in self.account_map:
                return str(account)

    def register(self, password: str):
        account = self.generate_account()
        uid = self.generate_id()

        logger.debug(f"type(account) = {type(account)}")

        self.account_map[account] = {
            "uid": uid,
            "password": password
        }

        return {
            "account": account,
            "uid": uid
        }

    def login(self, account: str, password: str) -> int:
        """
        返回：
        1 = 账号不存在
        2 = 密码错误
        0 = 成功
        """
        account = str(account)
        if account not in self.account_map:
            return 1

        if self.account_map[account]["password"] == password:
            return 0
        return 2

    def get_uid(self, account: str):
        return self.account_map[account]["uid"]