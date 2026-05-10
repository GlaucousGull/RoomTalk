import random
import logging
from settings import settings

def init_root_logger():
    # 从配置文件读取级别和格式
    log_level = settings["log"]["level"]
    log_format = settings["log"]["format"]
    log_datefmt = settings["log"]["datefmt"]

    # 映射级别字符串 → 官方级别
    level_map = {
        "DEBUG": logging.DEBUG,
        "INFO": logging.INFO,
        "WARNING": logging.WARNING,
        "ERROR": logging.ERROR
    }

    # 配置 【根日志器】（全局默认）
    logging.basicConfig(
        level=level_map.get(log_level, logging.INFO),
        format=log_format,
        datefmt=log_datefmt
    )

init_root_logger()

if __name__ == "__main__":
    logger = logging.getLogger("utils")
    logger.info("info")
    logger.debug("debug")

def get_room_number(room_list):
    """
    生成一个不在 room_list 中的随机房间号
    无限尝试，直到找到可用的
    """

    left = settings["room"]["room_number_min"]
    right = settings["room"]["room_number_max"]

    # 配置检查
    if right < left:
        raise RuntimeError("房间号配置错误：最大值不能小于最小值")

    # 计算最大可创建房间数量
    max_rooms = right - left + 1

    # 如果房间已满，直接抛异常
    if len(room_list) >= max_rooms:
        raise RuntimeError("房间号已占满，无法创建新房间")

    # 标准无限循环
    while True:
        # 生成随机号
        room_num = random.randint(left, right)
        # 如果不在列表里，直接返回
        if room_num not in room_list:
            return room_num
        
if __name__ == "__main__":
    # 空字典，用来存已创建的房间号
    room_dict = {}

    # 第一次获取
    number = get_room_number(room_dict)
    room_dict[number] = "房间12"  # ✅ 这里必须是字典名
    print("获取到的房间号为", number)

    # 第二次
    number = get_room_number(room_dict)
    room_dict[number] = "房间22"
    print("获取到的房间号为", number)

    # 第三次
    number = get_room_number(room_dict)
    room_dict[number] = "房间32"
    print("获取到的房间号为", number)

    print("\n最终所有房间：", room_dict)
