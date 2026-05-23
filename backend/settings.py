import json
import os

# 获取当前文件所在目录
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 拼接 config.json 完整路径
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")

class AppConfig:
    _instance = None
    _last_mtime = 0 # 记录配置文件最后修改的时间
    _config_path = CONFIG_PATH
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance.load_config()
        return cls._instance

    # 加载配置文件
    def load_config(self):
        # 获取文件修改时间
        mtime = os.path.getmtime(self._config_path)
        if mtime <= self._last_mtime:
            return # 没有变化，不需要重新加载

        # 文件修改时间变化，重新加载
        with open(self._config_path, "r", encoding="utf-8") as fd:
            self.data = json.load(fd)
        self._last_mtime = mtime

    # 支持获取配置端口
    def get(self, key: str, default = None):
        self.load_config()  # 每次获取数据时检测是否有更新
        keys = key.split(".")
        data = self.data
        for k in keys:
            if k in data:
                data = data[k]
            else:
                return default
        return data

settings = AppConfig()