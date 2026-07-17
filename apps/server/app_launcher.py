#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Wonelog 管理后台启动器
双击运行，自动启动服务并打开浏览器（无窗口后台运行）
支持单实例运行，如果已有实例则询问是否重启
"""

import sys
import os
import threading
import webbrowser
import time
import socket

# 日志输出到文件
LOG_FILE = None

def log(msg):
    if LOG_FILE:
        timestamp = time.strftime('%H:%M:%S')
        try:
            with open(LOG_FILE, 'a', encoding='utf-8') as f:
                f.write(f"[{timestamp}] {msg}\n")
        except:
            pass

# PyInstaller 打包时，资源文件在临时目录中
def get_base_dir():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    else:
        return os.path.dirname(os.path.abspath(__file__))

BASE_DIR = get_base_dir()
LOG_FILE = os.path.join(BASE_DIR, 'wonelog.log')

def get_resource_dir():
    if getattr(sys, 'frozen', False):
        return sys._MEIPASS
    else:
        return os.path.dirname(os.path.abspath(__file__))

RESOURCE_DIR = get_resource_dir()

PORT = 5000
LOCK_PORT = 5001  # 用于单实例检测的端口

def check_instance_running():
    """检测是否已有实例在运行"""
    try:
        # 尝试绑定锁端口
        lock_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        lock_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        lock_sock.bind(('127.0.0.1', LOCK_PORT))
        lock_sock.listen(1)
        return None, lock_sock  # 返回锁 socket，稍后关闭
    except OSError:
        # 端口被占用，说明已有实例在运行
        return True, None

def ask_restart():
    """通过 HTTP 请求检查并询问是否重启"""
    try:
        import urllib.request
        import json
        
        # 向已有实例发送健康检查请求
        req = urllib.request.Request(
            f'http://127.0.0.1:{PORT}/api/health',
            method='GET'
        )
        with urllib.request.urlopen(req, timeout=2) as response:
            data = json.loads(response.read().decode())
            if data.get('status') == 'running':
                return True
    except:
        pass
    return False

def kill_existing_instance():
    """关闭已有的实例"""
    try:
        import urllib.request
        import json
        
        # 发送关闭请求
        req = urllib.request.Request(
            f'http://127.0.0.1:{PORT}/api/shutdown',
            method='POST',
            data=json.dumps({}).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req, timeout=5)
        log("已发送关闭请求到旧实例")
        time.sleep(1)  # 等待旧实例关闭
        return True
    except Exception as e:
        log(f"关闭旧实例失败: {e}")
        return False

def open_browser():
    """等服务启动后打开浏览器"""
    time.sleep(1.5)
    webbrowser.open(f'http://localhost:{PORT}')

def main():
    log("=" * 40)
    log("Wonelog 管理后台启动中...")
    log(f"数据目录: {BASE_DIR}")
    
    # 检查是否已有实例在运行
    is_running, lock_sock = check_instance_running()
    
    if is_running:
        log("检测到已有实例正在运行...")
        
        # 询问用户是否要重启
        response = input("已有实例正在运行，是否重启？(y/n): ").strip().lower()
        
        if response in ['y', 'yes', '是', '1']:
            log("用户选择重启旧实例...")
            kill_existing_instance()
            time.sleep(2)  # 等待端口释放
            
            # 重新检测
            _, lock_sock = check_instance_running()
        else:
            log("用户取消启动，打开已运行的实例...")
            webbrowser.open(f'http://localhost:{PORT}')
            log("已在浏览器中打开管理后台")
            sys.exit(0)
    
    # 获取锁
    if lock_sock:
        # 设置短超时以便稍后可以检测到新启动的实例
        lock_sock.settimeout(None)
    
    log(f"访问地址: http://localhost:{PORT}")
    
    # 修改 web_app 的路径
    import web_app as app_module
    
    # 覆盖路径配置（exe 模式下使用 exe 旁边的目录存数据）
    app_module.BASE_DIR = BASE_DIR
    app_module.CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')
    app_module.CITIES_FILE = os.path.join(BASE_DIR, 'cities.json')
    app_module.LINKS_FILE = os.path.join(BASE_DIR, 'links.json')
    app_module.ABOUT_CONTENT_FILE = os.path.join(BASE_DIR, 'about_content.json')
    app_module.PROJECTS_FILE = os.path.join(BASE_DIR, 'projects.json')
    app_module.POSTS_DIR = os.path.join(BASE_DIR, 'posts')
    app_module.IMAGES_DIR = os.path.join(BASE_DIR, 'images')
    app_module.VERSIONS_DIR = os.path.join(BASE_DIR, 'versions')
    
    # 覆盖模板目录（模板打包在 exe 内部）
    app_module.app.template_folder = os.path.join(RESOURCE_DIR, 'templates')
    
    # 确保数据目录存在
    os.makedirs(app_module.POSTS_DIR, exist_ok=True)
    os.makedirs(app_module.IMAGES_DIR, exist_ok=True)
    os.makedirs(app_module.VERSIONS_DIR, exist_ok=True)
    
    log("启动 Flask 服务...")

    # 启动浏览器
    browser_thread = threading.Thread(target=open_browser, daemon=True)
    browser_thread.start()
    
    log("服务已启动，请在浏览器中访问 http://localhost:5000")
    log("关闭方法：在网页右上角点击「关闭 Wonelog 管理后台」")
    
    # 启动 Flask（生产模式，不用 debug）
    app_module.app.run(
        host='127.0.0.1',
        port=PORT,
        debug=False,
        use_reloader=False
    )

if __name__ == '__main__':
    main()


