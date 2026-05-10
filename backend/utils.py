import logging
from settings import settings

def init_root_logger():
    # 从配置文件读取级别和格式
    log_level = settings["log"]["level"]
    log_format = settings["log"]["format"]
    log_datefmt = settings["log"]["datefmt"]

    # 映射级别字符串
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

