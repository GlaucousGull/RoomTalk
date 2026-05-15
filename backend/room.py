# room.py

ROOM_TYPE_PUBLIC = 0      # 公域：直接进入
ROOM_TYPE_PRIVATE = 1     # 私域：密码进入

class Room:
    """
        房间属性：
            房间名称
            房间号
            房间中的成员列表
    """
    def __init__(
            self,
            room_id,
            room_name,
            room_type = ROOM_TYPE_PUBLIC,
            password = None
            ):
        self.room_id = room_id              # 房间号
        self.room_name = room_name          # 房间名
        self.room_type = room_type          # 房间类型
        self.password = password            # 私域房间密码
        self.user_list = []                 # 用户列表
        self.message_list = []              # 房间历史消息列表

    # 获取房间号
    def get_room_id(self) -> str:
        return str(self.room_id)
    # 修改房间名
    def set_room_name(self, room_name: str):
        self.room_name = room_name

    def get_room_name(self) -> str:
        return self.room_name

    # 添加用户
    def add_user(self, user_id):
        if user_id not in self.user_list:
            self.user_list.append(user_id)

    # 删除用户
    def remove_user(self, user):
        if user in self.user_list:
            self.user_list.remove(user)

    # 获取房间内的所有用户
    def get_user_list(self) -> list:
        return self.user_list

    # 获取房间用户数
    def get_user_count(self) -> int:
        return len(self.user_list)
    
    # 修改房间类型
    def set_room_type(self, room_type):
        self.room_type = room_type

    # 获取房间类型
    def get_room_type(self) -> int:
        return self.room_type

    # 添加/修改房间加入密码
    def set_password(self, password):
        self.password = password
    
    # 添加历史消息
    def add_message(self, user_id: str, message: str):
        self.message_list.append((user_id, message))

    # 获取房间历史消息
    def get_historical_message(self) -> list[tuple[str, str]]:
        return self.message_list

    # 对比房间密码是否一致
    def compare_password(self, password) -> bool:
        return self.password == password