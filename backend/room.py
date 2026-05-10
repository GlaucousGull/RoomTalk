

class Room:
    """
        房间属性：
            房间名称
            房间号
            房间中的成员列表
    """
    def __init__(self, room_id):
        self.room_id = room_id          # 房间号
        self.room_name = str(room_id)   # 房间名
        self.user_list = []             # 用户列表

    # 修改房间名
    def set_room_name(self, room_name: str):
        self.room_name = room_name

    # 添加用户
    def add_user(self, user):
        if user not in self.user_list:
            self.user_list.append(user)

    # 删除用户
    def remove_user(self, user):
        if user in self.user_list:
            self.user_list.remove(user)

    # 获取房间内的所有用户
    def get_user_list(self):
        return self.user_list

    # 获取房间用户数
    def get_user_conut(self):
        return len(self.user_list)