

class UserConnectionManager:
    """连接域：WebSocket、在线状态、上下线"""
    """
    key: uid
    value: {
        ws: ws
        nonline: bool
    }
    """

    def __init__(self):
        self.users = {}

    def user_online(self, uid: str, ws):
        self.users[uid] = {
            "ws": ws,
            "online": True
        }
    
    def user_offline(self, uid: str):
        if uid in self.users:
            self.users[uid]["ws"] = None
            self.users[uid]["online"] = False

    def is_online(self, uid: str):
        if uid not in self.users:
            return False
        return self.users.get(uid, {}).get("online", False)

    def get_user_ws(self, uid: str):
        if uid not in self.users:
            return False
        return self.users.get(uid, {}).get("ws")