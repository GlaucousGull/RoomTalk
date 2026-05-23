import logging
import os
from settings import settings
from logging.handlers import RotatingFileHandler

# 初始化日志
def init_project_logger():
    # 从配置文件读取级别和格式
    log_dir = settings.get("log.log_dir", "./logs")
    os.makedirs(log_dir, exist_ok=True)    # 创建日志输出目录
    log_level_str = settings.get("log.level", "DEBUG").upper()
    log_level = getattr(logging, log_level_str, logging.DEBUG)


    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    logger.handlers.clear()

    format = settings.get("log.format", "%(asctime)s [%(levelname)s] [%(name)s] %(message)s")
    datefmt = settings.get("log.datefmt", "%Y-%m-%d %H:%M:%S")
    formater = logging.Formatter(format, datefmt=datefmt)

    # 输出级别对应的文件
    level_file_map = [
        (logging.DEBUG, "debug.log"),
        (logging.INFO, "info.log"),
        (logging.WARNING, "warning.log"),
        (logging.ERROR, "error.log"),
    ]

    # 只输出当前级别
    for level, filename in level_file_map:
        # class LevelFilter(logging.Filter):
        #     def filter(self, record):
        #         return record.levelno >= level
            
        handler = RotatingFileHandler(
            os.path.join(log_dir, filename), # 创建文件
            maxBytes=10 * 1024 * 1024,
            backupCount=5,
            encoding="utf-8"
        )

        handler.setFormatter(formater)
        # handler.addFilter(LevelFilter())
        handler.setLevel(level)
        logger.addHandler(handler)
    
    # 控制台输出
    ch = logging.StreamHandler()
    ch.setFormatter(formater)
    logger.addHandler(ch)

init_project_logger()

if __name__ == "__main__":
    logger = logging.getLogger("utils")
    logger.info("info")
    logger.debug("debug")

