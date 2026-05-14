# room_manager.py
import random
import logging

"""
    房间管理模块（全局单例）
"""
from settings import settings
from room import Room

# 创建专属日志
logger = logging.getLogger(__name__)

class RoomManager:
    # 私有化实例，不允许外部访问
    __instance = None

    # 禁用 构造函数，不允许外部创建对象
    def __init__(self):
        logger.error("禁止创建 RoomManager 对象，请使用 .instance")

    # 单例构造方法
    def _init(self):
        # 房间列表
        self.room_list = {}

    # 获取全局实例的方法
    @classmethod
    def instance(cls):
        if cls.__instance is None:
            # 手动构造实例
            cls.__instance = object.__new__(cls)
            cls.__instance._init()
            return cls.__instance

    def get_room_number(self) -> int:
        """
        生成一个不在 room_list 中的随机房间号
        无限尝试，直到找到可用的
        """

        left = settings["room"]["room_number_min"]
        right = settings["room"]["room_number_max"]

        # 配置检查
        if right < left:
            logger.error("配置错误")
            return None

        # 计算最大可创建房间数量
        max_rooms = right - left + 1

        # 如果房间已满，直接抛异常
        if len(self.room_list) >= max_rooms:
            logger.error("房间号已占满，无法创建新房间")
            return None

        # 标准无限循环
        while True:
            # 生成随机号
            room_num = random.randint(left, right)
            # 如果不在列表里，直接返回
            if room_num not in self.room_list:
                logger.info(f"获取到房间号: {room_num}")
                return room_num

    """
        房间号管理方法：
        1、创建房间（默认房间名就是房间号）
        2、修改房间名
        3、删除房间
        4、查找房间
        5、给房间添加用户
        6、将房间中的指定用户删除
    """

    # 创建房间
    def create_room(self, user_id = "", room_type = 0, password = None) -> int:
        # 获取随机房间号
        room_number = self.get_room_number()
        if not room_number:
            logger.error("房间创建失败")
            return None
        self.room_list[room_number] = Room(room_number,  str(room_number), room_type, password)

        # 向房间成员列表添加房间创建者
        self.room_list[room_number].add_user(user_id)

        logger.info(f"[RoomManager] 房间创建成功: {room_number}")
        return room_number
    
    # 根据房间号查找并返回房间对象
    def get_room_object(self, room_id) -> Room:
        if room_id not in self.room_list:
            return None
        return self.room_list[room_id]
    
    # 删除房间
    def delete_room(self, room_id):
        if room_id in self.room_list:
            del self.room_list[room_id]
            logger.info(f"删除房间成功: {room_id}")

    # 获取房间列表
    def get_room_list(self) -> list[Room]:
        return self.room_list

    # 获取房间数
    def get_room_count(self) -> int:
        return len(self.room_list)

roommanager = RoomManager.instance()

if __name__ == "__main__":
    from backend.utils import init_root_logger
    init_root_logger()  # 必须先初始化日志！

    print("=" * 60)
    print("开始测试房间管理系统...")
    print("=" * 60)

    # 1. 创建两个房间
    room_id1 = roommanager.create_room("张三")
    room_id2 = roommanager.create_room("李四")

    # 2. 测试获取房间对象
    room1 = roommanager.get_room_object(room_id1)
    room2 = roommanager.get_room_object(room_id2)

    # 3. 给房间1添加10个用户
    for i in range(10):
        room1.add_user(f"游客_{i+1}")

    # 4. 修改房间名
    room1.set_room_name("Python交流群")
    room2.set_room_name("游戏开黑房")

    # 5. 删除一个用户
    room1.remove_user("游客_5")

    # 6. 打印房间1信息
    print(f"\n【房间1信息】")
    print(f"房间号: {room1.room_id}")
    print(f"房间名: {room1.room_name}")
    print(f"当前人数: {room1.get_user_conut()}")
    print(f"成员列表: {room1.get_user_list()}")

    # 7. 打印房间2信息
    print(f"\n【房间2信息】")
    print(f"房间号: {room2.room_id}")
    print(f"房间名: {room2.room_name}")
    print(f"当前人数: {room2.get_user_conut()}")
    print(f"成员列表: {room2.get_user_list()}")

    # 8. 删除房间2
    roommanager.delete_room(room_id2)

    # 9. 验证是否删除成功
    check_room = roommanager.get_room_object(room_id2)
    if not check_room:
        print(f"\n✅ 房间 {room_id2} 已成功删除")

    print("\n" + "=" * 60)
    print("所有测试执行完毕！")
    print("=" * 60)