class UserInfoManager:
    """用户信息域：key = account（你要的正确版本）"""
    """
    key: uid
    value: {
        account: account
        name: naame
    }
    """
    def __init__(self):
        self.info = {}  # key: account

    def set_user_info(self, account, uid, name):
        self.info[uid] = {
            "account": account,
            "name": name
        }

    def set_user_name(self, uid, name):
        if uid not in self.info:
            return False
        self.info[uid]["name"] = name
        return True

    def get_user_name(self, uid):
        return self.info.get(uid, {}).get("name", "未知用户")

    def get_account(self, uid):
        return self.info.get(uid, {}).get("account")