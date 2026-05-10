import json
import os

# 获取当前文件所在目录
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 拼接 config.json 完整路径
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")

_config = None

# 加载配置文件
def load_config():
    global _config
    if _config is None:
        with open(CONFIG_PATH, "r", encoding="utf-8") as fd:
            _config = json.load(fd)
    return _config

settings = load_config()