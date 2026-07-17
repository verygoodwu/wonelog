#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Internal helper."""

import os
import sys
import json
import shutil
import base64
import hashlib
import re
import paramiko
import requests
from datetime import datetime
from flask import Flask, render_template, request, jsonify, send_from_directory

# 处理 PyInstaller 打包后的资源路径
def get_resource_path(relative_path):
    """Internal helper."""
    if hasattr(sys, '_MEIPASS'):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# 路径配置
BASE_DIR = os.path.dirname(os.path.abspath(sys.executable)) if getattr(sys, 'frozen', False) else os.path.dirname(os.path.abspath(__file__))

# 模板路径
if hasattr(sys, '_MEIPASS'):
    TEMPLATE_DIR = os.path.join(sys._MEIPASS, 'templates')
else:
    TEMPLATE_DIR = os.path.join(BASE_DIR, 'templates')

app = Flask(__name__, template_folder=TEMPLATE_DIR)

# 数据文件路径
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')
CITIES_FILE = os.path.join(BASE_DIR, 'cities.json')
LINKS_FILE = os.path.join(BASE_DIR, 'links.json')
ABOUT_CONTENT_FILE = os.path.join(BASE_DIR, 'about_content.json')
PROJECTS_FILE = os.path.join(BASE_DIR, 'projects.json')  # 项目展示数据
POSTS_DIR = os.path.join(BASE_DIR, 'posts')
IMAGES_DIR = os.path.join(BASE_DIR, 'images')

# 版本管理
VERSIONS_DIR = os.path.join(BASE_DIR, 'versions')
MAX_VERSIONS = 10

# 服务器配置
SERVER_HOST = os.environ.get('WONELOG_SERVER_HOST', '')
SERVER_USER = os.environ.get('WONELOG_SERVER_USER', 'deploy')
SERVER_KEY = os.environ.get('WONELOG_SERVER_KEY') or os.path.expanduser('~/.ssh/id_ed25519')
SERVER_SOURCE_DIR = os.environ.get('WONELOG_SERVER_SOURCE_DIR', '/var/www/wonelog-source')
SERVER_SITE_DIR = os.environ.get('WONELOG_SERVER_SITE_DIR', '/var/www/wonelog')
SERVER_BLOG_DIR = os.environ.get('WONELOG_SERVER_BLOG_DIR', f'{SERVER_SOURCE_DIR}/src/content/blog/')
SERVER_CONTENT_DIR = os.environ.get('WONELOG_SERVER_CONTENT_DIR', f'{SERVER_SOURCE_DIR}/src/content/')
SERVER_PUBLIC_IMAGES_DIR = os.environ.get('WONELOG_SERVER_PUBLIC_IMAGES_DIR', f'{SERVER_SOURCE_DIR}/public/images/')

# GitHub 图库配置
GITHUB_TOKEN = os.environ.get('WONELOG_GITHUB_TOKEN', '')
GITHUB_REPO = os.environ.get('WONELOG_GITHUB_REPO', '')
GITHUB_BRANCH = os.environ.get('WONELOG_GITHUB_BRANCH', 'main')

# 确保数据目录存在
os.makedirs(POSTS_DIR, exist_ok=True)
os.makedirs(IMAGES_DIR, exist_ok=True)

# 发布进度状态（供客户端轮询）
publish_status = {'step': 'idle', 'message': '', 'error': False, 'error_step': ''}
import threading
_publish_lock = threading.Lock()
os.makedirs(VERSIONS_DIR, exist_ok=True)

# Chinese city coordinates
CITY_COORDS = {
    '北京': {'lat': 39.9042, 'lon': 116.4074},
    '上海': {'lat': 31.2304, 'lon': 121.4737},
    '广州': {'lat': 23.1291, 'lon': 113.2644},
    '深圳': {'lat': 22.5431, 'lon': 114.0579},
    '成都': {'lat': 30.5728, 'lon': 104.0668},
    '杭州': {'lat': 30.2741, 'lon': 120.1551},
    '武汉': {'lat': 30.5928, 'lon': 114.3055},
    '西安': {'lat': 34.3416, 'lon': 108.9398},
    '重庆': {'lat': 29.4316, 'lon': 106.9123},
    '南京': {'lat': 32.0603, 'lon': 118.7969},
    '天津': {'lat': 39.3434, 'lon': 117.3616},
    '苏州': {'lat': 31.2989, 'lon': 120.5853},
    '长沙': {'lat': 28.2282, 'lon': 112.9388},
    '郑州': {'lat': 34.7466, 'lon': 113.6253},
    '青岛': {'lat': 36.0671, 'lon': 120.3826},
    '济南': {'lat': 36.6512, 'lon': 117.1205},
    '大连': {'lat': 38.9140, 'lon': 121.6147},
    '沈阳': {'lat': 41.8057, 'lon': 123.4328},
    '哈尔滨': {'lat': 45.8038, 'lon': 126.5340},
    '长春': {'lat': 43.8171, 'lon': 125.3235},
    '石家庄': {'lat': 38.0428, 'lon': 114.5149},
    '福州': {'lat': 26.0745, 'lon': 119.2965},
    '厦门': {'lat': 24.4798, 'lon': 118.0894},
    '南昌': {'lat': 28.6820, 'lon': 115.8579},
    '合肥': {'lat': 31.8206, 'lon': 117.2272},
    '昆明': {'lat': 25.0406, 'lon': 102.7129},
    '贵阳': {'lat': 26.6470, 'lon': 106.6302},
    '南宁': {'lat': 22.8170, 'lon': 108.3665},
    '海口': {'lat': 20.0444, 'lon': 110.1999},
    '太原': {'lat': 37.8706, 'lon': 112.5489},
    '兰州': {'lat': 36.0611, 'lon': 103.8343},
    '乌鲁木齐': {'lat': 43.8256, 'lon': 87.6168},
    '呼和浩特': {'lat': 40.8424, 'lon': 111.7492},
    '拉萨': {'lat': 29.6500, 'lon': 91.1000},
    '西宁': {'lat': 36.6232, 'lon': 101.7782},
    '银川': {'lat': 38.4872, 'lon': 106.2309},
    '香港': {'lat': 22.3193, 'lon': 114.1694},
    '澳门': {'lat': 22.1987, 'lon': 113.5439},
    '台北': {'lat': 25.0330, 'lon': 121.5654},
}


def load_json(filepath, default=None):
    try:
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
    except:
        pass
    return default if default is not None else {}


def save_json(filepath, data):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)



def safe_article_filename(filename):
    """Internal helper."""
    filename = (filename or '').strip()
    if not filename or filename in {'.', '..'}:
        return None
    if filename != os.path.basename(filename):
        return None
    if not filename.lower().endswith('.md'):
        return None
    if any(ch in filename for ch in '<>:"/\\|?*'):
        return None
    if any(ord(ch) < 32 for ch in filename):
        return None
    return filename


def get_article_path(filename):
    safe_name = safe_article_filename(filename)
    if not safe_name:
        return None, None
    posts_root = os.path.abspath(POSTS_DIR)
    article_path = os.path.abspath(os.path.join(posts_root, safe_name))
    if os.path.commonpath([posts_root, article_path]) != posts_root:
        return None, None
    return safe_name, article_path


def get_all_content_files():
    """Internal helper."""
    return {
        'config.json': CONFIG_FILE,
        'cities.json': CITIES_FILE,
        'links.json': LINKS_FILE,
        'about_content.json': ABOUT_CONTENT_FILE,
        'projects.json': PROJECTS_FILE,
        'posts': POSTS_DIR,
        'images': IMAGES_DIR
    }


# ========== 版本管理 ==========

# ========== 自动版本管理 ==========

def auto_create_code_version():
    """Internal helper."""
    import subprocess
    now = datetime.now()
    version = "trunk-" + now.strftime("%y_%m_%d")
    today = now.strftime("%Y-%m-%d")

    # Astro 配置目录
    astro_config_dir = os.path.join(os.path.dirname(BASE_DIR), "astro_config")
    if not os.path.exists(astro_config_dir):
        print(f"astro_config not found at {astro_config_dir}")
        return version

    key_files = [
        "about.astro", "BaseHead.astro", "Header.astro",
        "Footer.astro", "BlogPost.astro", "blog_index.astro",
        "index.astro", "consts.ts"
    ]

    for fname in key_files:
        fpath = os.path.join(astro_config_dir, fname)
        if not os.path.exists(fpath):
            continue
        with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
            data = f.read()
        out = []
        done = False
        for line in data.split("\n"):
            out.append(line)
            if line.strip() == "---" and not done:
                out.append("// version: " + version)
                out.append("// last_fixed: " + today)
                done = True
        with open(fpath, "w", encoding="utf-8") as f:
            f.write("\n".join(out))

    # 更新 layouts 目录
    layouts_dir = os.path.join(astro_config_dir, "layouts")
    if os.path.exists(layouts_dir):
        for fname in os.listdir(layouts_dir):
            if fname.endswith(".astro"):
                fpath = os.path.join(layouts_dir, fname)
                with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
                    data = f.read()
                out = []
                done = False
                for line in data.split("\n"):
                    out.append(line)
                    if line.strip() == "---" and not done:
                        out.append("// version: " + version)
                        out.append("// last_fixed: " + today)
                        done = True
                with open(fpath, "w", encoding="utf-8") as f:
                    f.write("\n".join(out))

    # 淇濆瓨 version.json
    version_data = {
        "version": version,
        "created_at": today,
        "description": "auto " + version,
        "files": {f: {"version": version, "hash": "tbd"} for f in key_files}
    }
    with open(os.path.join(astro_config_dir, "version.json"), "w", encoding="utf-8") as f:
        import json as jsonmod
        jsonmod.dump(version_data, f, ensure_ascii=False, indent=2)

    print(f"[auto_version] Created version: {version}")
    return version


def create_version():
    """Internal helper."""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    version_dir = os.path.join(VERSIONS_DIR, timestamp)
    os.makedirs(version_dir, exist_ok=True)
    
    # 淇濆瓨鎵鏈夊唴瀹规枃浠?
    for name, path in get_all_content_files().items():
        if name in ('posts', 'images'):
            version_asset_dir = os.path.join(version_dir, name)
            os.makedirs(version_asset_dir, exist_ok=True)
            if os.path.exists(path):
                for f in os.listdir(path):
                    src_file = os.path.join(path, f)
                    if os.path.isfile(src_file):
                        shutil.copy2(src_file, version_asset_dir)
        else:
            if os.path.exists(path):
                shutil.copy2(path, version_dir)
    
    # 保存版本元数据
    meta = {
        'timestamp': timestamp,
        'created_at': datetime.now().isoformat(),
        'config': load_json(CONFIG_FILE, {}).get('nickname', 'Unknown'),
        'cities_count': len(load_json(CITIES_FILE, {'cities': []}).get('cities', [])),
        'links_count': len(load_json(LINKS_FILE, {'links': []}).get('links', [])),
        'projects_count': len(load_json(PROJECTS_FILE, {'projects': []}).get('projects', [])),
        'articles_count': len([f for f in os.listdir(POSTS_DIR) if f.endswith('.md')]) if os.path.exists(POSTS_DIR) else 0
    }
    with open(os.path.join(version_dir, 'meta.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    
    # 清理旧快照，仅保留最近 MAX_VERSIONS 个
    cleanup_old_versions()
    
    return timestamp


def cleanup_old_versions():
    """Internal helper."""
    if not os.path.exists(VERSIONS_DIR):
        return
    
    versions = sorted(os.listdir(VERSIONS_DIR), reverse=True)
    for v in versions[MAX_VERSIONS:]:
        shutil.rmtree(os.path.join(VERSIONS_DIR, v))


def get_versions():
    """Internal helper."""
    if not os.path.exists(VERSIONS_DIR):
        return []
    
    versions = []
    for v in sorted(os.listdir(VERSIONS_DIR), reverse=True):
        meta_file = os.path.join(VERSIONS_DIR, v, 'meta.json')
        if os.path.exists(meta_file):
            with open(meta_file, 'r', encoding='utf-8') as f:
                versions.append(json.load(f))
    return versions


def restore_version(timestamp):
    """Internal helper."""
    version_dir = os.path.join(VERSIONS_DIR, timestamp)
    if not os.path.exists(version_dir):
        return False
    
    # 鎭㈠鎵鏈夊唴瀹规枃浠?
    for name, path in get_all_content_files().items():
        version_path = os.path.join(version_dir, name)
        if name in ('posts', 'images'):
            if os.path.exists(version_path):
                os.makedirs(path, exist_ok=True)
                for f in os.listdir(version_path):
                    src_file = os.path.join(version_path, f)
                    if os.path.isfile(src_file):
                        shutil.copy2(src_file, path)
        else:
            if os.path.exists(version_path):
                shutil.copy2(version_path, path)
    
    return True


def delete_version(timestamp):
    """Internal helper."""
    version_dir = os.path.join(VERSIONS_DIR, timestamp)
    if os.path.exists(version_dir):
        shutil.rmtree(version_dir)
        return True
    return False


# ========== 页面路由 ==========

@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/config', methods=['GET', 'POST'])
def api_config():
    if request.method == 'POST':
        data = request.json
        save_json(CONFIG_FILE, data)
        return jsonify({'success': True})
    else:
        config = load_json(CONFIG_FILE, {
            'nickname': 'Your Name',
            'bio': ['在这里介绍你自己。', '分享你的技术、项目与生活。'],
            'email': 'hello@example.com',
            'socials': {'github': 'example', 'rss': 'https://example.com/rss.xml'}
        })
        return jsonify(config)


@app.route('/api/cities', methods=['GET', 'POST'])
def api_cities():
    if request.method == 'POST':
        data = request.json
        save_json(CITIES_FILE, {'cities': data})
        return jsonify({'success': True})
    else:
        data = load_json(CITIES_FILE, [])
        cities = data.get('cities', []) if isinstance(data, dict) else data
        return jsonify(cities)


@app.route('/api/city-coords')
def api_city_coords():
    return jsonify(CITY_COORDS)


@app.route('/api/links', methods=['GET', 'POST'])
def api_links():
    if request.method == 'POST':
        data = request.json
        save_json(LINKS_FILE, {'links': data if isinstance(data, list) else data.get('links', [])})
        return jsonify({'success': True})
    else:
        links_data = load_json(LINKS_FILE, {'links': []})
        links = links_data.get('links', []) if isinstance(links_data, dict) else links_data
        return jsonify(links)

@app.route('/api/projects', methods=['GET', 'POST'])
def api_projects():
    if request.method == 'POST':
        data = request.json or []
        projects = data if isinstance(data, list) else data.get('projects', [])
        save_json(PROJECTS_FILE, {'projects': projects})
        return jsonify({'success': True, 'count': len(projects)})

    projects_data = load_json(PROJECTS_FILE, {'projects': []})
    projects = projects_data.get('projects', []) if isinstance(projects_data, dict) else projects_data
    return jsonify(projects)

@app.route('/api/about-content', methods=['GET', 'POST'])
def api_about_content():
    """Internal helper."""
    if request.method == 'POST':
        data = request.json
        save_json(ABOUT_CONTENT_FILE, data)
        return jsonify({'success': True})
    else:
        # 默认模块配置
        default_content = {
            'modules': [
                {'id': 'footprint', 'title': '足迹', 'enabled': True}
            ],
            'footprint': {
                'subtitle': '去过的一些地方'
            }
        }
        content = load_json(ABOUT_CONTENT_FILE, default_content)
        return jsonify(content)


@app.route('/api/links/upload-avatar', methods=['POST'])
def api_links_upload_avatar():
    """Internal helper."""
    if 'file' not in request.files:
        return jsonify({'success': False, 'message': 'No file'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'success': False, 'message': 'No file selected'}), 400

    if not GITHUB_TOKEN:
        try:
            timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
            original_name = os.path.splitext(file.filename)[0]
            ext = os.path.splitext(file.filename)[1] or '.png'
            safe_name = ''.join(c for c in original_name if c.isalnum() or c in '-_').lower() or 'image'
            filename = f"{safe_name}_{timestamp}{ext}"
            local_path = os.path.join(IMAGES_DIR, filename)
            file.save(local_path)
            return jsonify({'success': True, 'url': f'/images/{filename}', 'filename': filename, 'storage': 'local'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    try:
        file_content = file.read()
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        original_name = os.path.splitext(file.filename)[0]
        ext = os.path.splitext(file.filename)[1] or '.png'
        safe_name = ''.join(c for c in original_name if c.isalnum() or c in '-_').lower()
        filename = f"link_{safe_name}_{timestamp}{ext}"

        url = f"https://api.github.com/repos/{GITHUB_REPO}/contents/images/{filename}"
        content_b64 = base64.b64encode(file_content).decode('utf-8')

        headers = {
            'Authorization': f'token {GITHUB_TOKEN}',
            'Accept': 'application/vnd.github.v3+json'
        }

        existing = requests.get(url, headers=headers)
        sha = None
        if existing.status_code == 200:
            sha = existing.json().get('sha')

        payload = {
            'message': f'Upload link avatar: {filename}',
            'content': content_b64,
            'branch': GITHUB_BRANCH
        }
        if sha:
            payload['sha'] = sha

        response = requests.put(url, headers=headers, json=payload)

        if response.status_code in [200, 201]:
            cdn_url = f"https://cdn.jsdelivr.net/gh/{GITHUB_REPO}@latest/images/{filename}"
            return jsonify({'success': True, 'url': cdn_url, 'filename': filename})
        else:
            return jsonify({'success': False, 'message': response.text}), 500

    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500



@app.route('/images/<path:filename>')
def serve_local_image(filename):
    return send_from_directory(IMAGES_DIR, filename)
@app.route('/api/articles')
def api_articles():
    articles = []
    if os.path.exists(POSTS_DIR):
        for filename in sorted(os.listdir(POSTS_DIR), reverse=True):
            if filename.endswith('.md'):
                filepath = os.path.join(POSTS_DIR, filename)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                title = filename.replace('.md', '')
                date = ''
                description = ''
                heroImage = ''
                tags = []
                if content.startswith('---'):
                    lines = content.split('\n')
                    for line in lines[1:]:
                        if line.strip() == '---':
                            break
                        if line.startswith('title:'):
                            title = line.split(':', 1)[1].strip().strip("'\"")
                        if line.startswith('pubDate:'):
                            date = line.split(':', 1)[1].strip().strip("'\"")
                        if line.startswith('description:'):
                            description = line.split(':', 1)[1].strip().strip("'\"")
                        if line.startswith('heroImage:'):
                            heroImage = line.split(':', 1)[1].strip().strip("'\"")
                        if line.startswith('tags:'):
                            tags_str = line.split(':', 1)[1].strip().strip("[]")
                            tags = [t.strip().strip("'\"") for t in tags_str.split(',') if t.strip()]
                
                articles.append({
                    'filename': filename,
                    'title': title,
                    'date': date,
                    'description': description,
                    'heroImage': heroImage,
                    'tags': tags
                })
    return jsonify(articles)


@app.route('/api/articles/<filename>', methods=['GET', 'POST', 'DELETE'])
def api_article(filename):
    safe_name, filepath = get_article_path(filename)
    if not filepath:
        return jsonify({'error': 'Invalid filename'}), 400
    filename = safe_name
    
    if request.method == 'GET':
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                return jsonify({'content': f.read()})
        return jsonify({'error': 'Not found'}), 404
    
    elif request.method == 'POST':
        data = request.json
        content = data.get('content', '')
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return jsonify({'success': True})
    
    elif request.method == 'DELETE':
        if os.path.exists(filepath):
            os.remove(filepath)
        return jsonify({'success': True})


@app.route('/api/articles/import', methods=['POST'])
def api_import_article():
    """Internal helper."""
    if 'file' not in request.files:
        return jsonify({'error': 'No file'}), 400
    
    file = request.files['file']
    if file.filename == '' or not file.filename.endswith('.md'):
        return jsonify({'error': 'Invalid file'}), 400
    
    filename = safe_article_filename(file.filename)
    if not filename:
        return jsonify({'error': 'Invalid filename'}), 400
    filepath = os.path.join(POSTS_DIR, filename)
    file.save(filepath)
    
    return jsonify({'success': True, 'filename': filename})


@app.route('/api/upload-image', methods=['POST'])
def api_upload_image():
    """Internal helper."""
    if 'file' not in request.files:
        return jsonify({'success': False, 'message': 'No file'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'success': False, 'message': 'No file selected'}), 400
    
    if not GITHUB_TOKEN:
        try:
            timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
            original_name = os.path.splitext(file.filename)[0]
            ext = os.path.splitext(file.filename)[1] or '.png'
            safe_name = ''.join(c for c in original_name if c.isalnum() or c in '-_').lower() or 'image'
            filename = f"{safe_name}_{timestamp}{ext}"
            local_path = os.path.join(IMAGES_DIR, filename)
            file.save(local_path)
            return jsonify({'success': True, 'url': f'/images/{filename}', 'filename': filename, 'storage': 'local'})
        except Exception as e:
            return jsonify({'success': False, 'message': str(e)}), 500
    try:
        file_content = file.read()
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        original_name = os.path.splitext(file.filename)[0]
        ext = os.path.splitext(file.filename)[1] or '.png'
        safe_name = ''.join(c for c in original_name if c.isalnum() or c in '-_').lower() or 'image'
        filename = f"{safe_name}_{timestamp}{ext}"
        
        url = f"https://api.github.com/repos/{GITHUB_REPO}/contents/images/{filename}"
        content_b64 = base64.b64encode(file_content).decode('utf-8')
        
        headers = {
            'Authorization': f'token {GITHUB_TOKEN}',
            'Accept': 'application/vnd.github.v3+json'
        }
        
        existing = requests.get(url, headers=headers)
        sha = None
        if existing.status_code == 200:
            sha = existing.json().get('sha')
        
        payload = {
            'message': f'Upload image: {filename}',
            'content': content_b64,
            'branch': GITHUB_BRANCH
        }
        if sha:
            payload['sha'] = sha
        
        response = requests.put(url, headers=headers, json=payload)
        
        if response.status_code in [200, 201]:
            cdn_url = f"https://cdn.jsdelivr.net/gh/{GITHUB_REPO}@latest/images/{filename}"
            return jsonify({'success': True, 'url': cdn_url, 'filename': filename})
        else:
            return jsonify({'success': False, 'message': response.text}), 500
            
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500


# ========== 版本管理 API ==========

@app.route('/api/versions', methods=['GET'])
def api_get_versions():
    """Internal helper."""
    return jsonify(get_versions())


@app.route('/api/versions', methods=['POST'])
def api_create_version():
    """Internal helper."""
    try:
        timestamp = create_version()
        return jsonify({'success': True, 'timestamp': timestamp})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'创建版本失败: {str(e)}'}), 500


@app.route('/api/versions/<timestamp>', methods=['POST'])
def api_restore_version(timestamp):
    """Internal helper."""
    if restore_version(timestamp):
        return jsonify({'success': True, 'message': f'已恢复到版本 {timestamp}'})
    return jsonify({'success': False, 'message': '版本不存在'}), 404


@app.route('/api/versions/<timestamp>', methods=['DELETE'])
def api_delete_version(timestamp):
    """Internal helper."""
    if delete_version(timestamp):
        return jsonify({'success': True})
    return jsonify({'success': False, 'message': '版本不存在'}), 404


# ========== 发布 ==========

# Legacy page-generation helpers were removed; the Astro app reads JSON directly.

@app.route('/api/publish/status', methods=['GET'])
def api_publish_status():
    """Internal helper."""
    return jsonify(publish_status)


@app.route('/api/publish', methods=['POST'])
def api_publish():
    """Internal helper."""
    global publish_status
    if not _publish_lock.acquire(blocking=False):
        return jsonify({'success': False, 'message': '已有发布任务正在进行，请稍后再试', 'error_step': 'busy'}), 409
    import time
    start_time = time.time()
    
    def set_status(step, message, error=False, error_step=''):
        global publish_status
        publish_status = {
            'step': step,
            'message': message,
            'error': error,
            'error_step': error_step
        }
    
    set_status('connecting', '正在连接服务器...')
    
    try:
        if not SERVER_HOST:
            set_status('idle', '尚未配置发布服务器', error=True, error_step='config')
            return jsonify({'success': False, 'message': '请先设置 WONELOG_SERVER_HOST', 'error_step': 'config'}), 400
        if not SERVER_KEY or not os.path.isfile(SERVER_KEY):
            set_status('idle', 'SSH 私钥不可用', error=True, error_step='config')
            return jsonify({'success': False, 'message': '请设置有效的 WONELOG_SERVER_KEY', 'error_step': 'config'}), 400

        # 获取请求中的版本参数
        req_data = request.json or {}
        selected_version = req_data.get('version')
        
        # 如果指定了版本，先恢复该快照
        if selected_version:
            if not restore_version(selected_version):
                set_status('idle', '版本不存在', error=True, error_step='restore')
                return jsonify({'success': False, 'message': f'版本 {selected_version} 不存在', 'error_step': 'restore'}), 404
        
        # 创建发布前快照
        version_ts = create_version()
        
        # 连接服务器
        set_status('connecting', '正在连接服务器...')
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SERVER_HOST, 22, SERVER_USER, key_filename=SERVER_KEY,
                    allow_agent=False, look_for_keys=False)
        sftp = ssh.open_sftp()
        
        # 上传数据文件，不上传应用源码
        set_status('upload', '正在上传数据文件...')
        
        # 同步文章
        local_files = [f for f in os.listdir(POSTS_DIR) if f.endswith('.md')]
        try:
            remote_files = sftp.listdir(SERVER_BLOG_DIR)
            for remote_file in remote_files:
                if remote_file.endswith('.md') and remote_file not in local_files:
                    sftp.remove(SERVER_BLOG_DIR + remote_file)
        except:
            pass
        
        for filename in local_files:
            local_path = os.path.join(POSTS_DIR, filename)
            sftp.put(local_path, f'{SERVER_BLOG_DIR}{filename}')
        
        # Sync local image assets to Astro public/images.
        set_status('upload', '正在上传本地图片...')
        remote_images_dir = SERVER_PUBLIC_IMAGES_DIR.rstrip('/') + '/'
        try:
            sftp.mkdir(remote_images_dir.rstrip('/'))
        except Exception:
            pass
        if os.path.exists(IMAGES_DIR):
            for image_name in os.listdir(IMAGES_DIR):
                local_image = os.path.join(IMAGES_DIR, image_name)
                if os.path.isfile(local_image):
                    sftp.put(local_image, f'{remote_images_dir}{image_name}')
        
        # 上传 JSON 配置到服务器 content 目录
        # Astro 构建时会读取这些 JSON 文件
        import json as json_module
        
        # 上传 config.json
        config_data = load_json(CONFIG_FILE, {})
        temp_config = os.path.join(BASE_DIR, 'temp_config.json')
        with open(temp_config, 'w', encoding='utf-8') as f:
            json_module.dump(config_data, f, ensure_ascii=False, indent=2)
        sftp.put(temp_config, f'{SERVER_CONTENT_DIR}config.json')
        os.remove(temp_config)
        
        # 上传 cities.json
        cities_data = load_json(CITIES_FILE, {'cities': []})
        temp_cities = os.path.join(BASE_DIR, 'temp_cities.json')
        with open(temp_cities, 'w', encoding='utf-8') as f:
            json_module.dump(cities_data, f, ensure_ascii=False, indent=2)
        sftp.put(temp_cities, f'{SERVER_CONTENT_DIR}cities.json')
        os.remove(temp_cities)
        
        # 上传 links.json
        links_data = load_json(LINKS_FILE, {'links': []})
        temp_links = os.path.join(BASE_DIR, 'temp_links.json')
        with open(temp_links, 'w', encoding='utf-8') as f:
            json_module.dump(links_data, f, ensure_ascii=False, indent=2)
        sftp.put(temp_links, f'{SERVER_CONTENT_DIR}links.json')
        os.remove(temp_links)
        
        # Upload open-source project data.
        projects_data = load_json(PROJECTS_FILE, {'projects': []})
        temp_projects = os.path.join(BASE_DIR, 'temp_projects.json')
        with open(temp_projects, 'w', encoding='utf-8') as f:
            json_module.dump(projects_data, f, ensure_ascii=False, indent=2)
        sftp.put(temp_projects, f'{SERVER_CONTENT_DIR}projects.json')
        os.remove(temp_projects)
        # 上传 about_content.json
        about_content_data = load_json(ABOUT_CONTENT_FILE, {'modules': []})
        temp_about = os.path.join(BASE_DIR, 'temp_about.json')
        with open(temp_about, 'w', encoding='utf-8') as f:
            json_module.dump(about_content_data, f, ensure_ascii=False, indent=2)
        sftp.put(temp_about, f'{SERVER_CONTENT_DIR}about_content.json')
        os.remove(temp_about)
        
        sftp.close()
        
        # 构建静态站点
        set_status('build', '正在构建博客站点...')
        build_cmd = f'cd {SERVER_SOURCE_DIR} && npm install && npm run build 2>&1'
        stdin, stdout, stderr = ssh.exec_command(build_cmd)
        output = stdout.read().decode('utf-8', errors='ignore')
        err_output = stderr.read().decode('utf-8', errors='ignore')
        build_exit = stdout.channel.recv_exit_status()
        combined = output + err_output
        
        if build_exit == 0 and ('Complete!' in combined or 'built in' in combined):
            set_status('deploy', '正在部署到生产目录...')
            deploy_cmd = f'sudo rsync -a --delete {SERVER_SOURCE_DIR.rstrip("/")}/dist/ {SERVER_SITE_DIR.rstrip("/")}/ 2>&1'
            stdin, deploy_stdout, deploy_stderr = ssh.exec_command(deploy_cmd)
            deploy_output = deploy_stdout.read().decode('utf-8', errors='ignore')
            deploy_err = deploy_stderr.read().decode('utf-8', errors='ignore')
            deploy_exit = deploy_stdout.channel.recv_exit_status()
            if deploy_exit != 0:
                ssh.close()
                set_status('deploy', '部署失败', error=True, error_step='deploy')
                return jsonify({'success': False, 'message': f'部署失败: {(deploy_output + deploy_err)[-500:]}', 'error_step': 'deploy'})
            ssh.close()
            elapsed = time.time() - start_time
            current_versions = get_versions()
            set_status('done', f'发布成功（{elapsed:.1f}s）', error=False)
            
            if _publish_lock.locked():
                _publish_lock.release()
            return jsonify({
                'success': True,
                'message': f'发布成功，版本快照 {version_ts}',
                'version': version_ts,
                'versions_count': len(current_versions),
                'time': f'{elapsed:.1f}s'
            })
        else:
            ssh.close()
            set_status('build', '构建失败', error=True, error_step='build')
            return jsonify({'success': False, 'message': f'构建失败: {combined[-500:]}', 'error_step': 'build'})
            
    except Exception as e:
        import traceback
        traceback.print_exc()
        # 判断错误发生阶段
        err_msg = str(e)
        if 'Authentication' in err_msg or 'auth' in err_msg.lower():
            set_status('connecting', f'连接失败: {err_msg}', error=True, error_step='connect')
        elif 'No such file' in err_msg or 'Permission' in err_msg:
            set_status('upload', f'上传失败: {err_msg}', error=True, error_step='upload')
        else:
            set_status('build', f'发布错误: {err_msg}', error=True, error_step='build')
        return jsonify({'success': False, 'message': f'发布错误: {err_msg}', 'error_step': publish_status.get('error_step', 'build')})
    finally:
        if _publish_lock.locked():
            _publish_lock.release()


@app.route('/api/sync', methods=['POST'])
def api_sync():
    """Internal helper."""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SERVER_HOST, 22, SERVER_USER, key_filename=SERVER_KEY,
                    allow_agent=False, look_for_keys=False, timeout=10)
        sftp = ssh.open_sftp()

        results = {'articles': 0, 'config_updated': False, 'cities_updated': False}

        # 解析 about.astro 中的城市与配置（兼容旧站点）
        try:
            with sftp.file('/var/www/wonelog-source/src/pages/about.astro', 'r') as f:
                about_content = f.read().decode('utf-8')

            cities = []
            if 'const cityData' in about_content:
                import re as re_module
                match = re_module.search(r'const cityData\s*=\s*(\[.*?\]);', about_content, re_module.DOTALL)
                if match:
                    try:
                        cities = json.loads(match.group(1))
                        save_json(CITIES_FILE, {'cities': cities})
                        results['cities_updated'] = True
                    except:
                        pass

            config = load_json(CONFIG_FILE, {})
            
            nick_match = re_module.search(r'关于</h1>.*?<ul.*?<li>(.*?)</li>', about_content, re_module.DOTALL)
            if nick_match:
                config['nickname'] = nick_match.group(1).strip()

            email_match = re_module.search(r'href="mailto:(.*?)"', about_content)
            if email_match:
                config['email'] = email_match.group(1).strip()

            github_match = re_module.search(r'href="https://github\.com/([^"]+)"', about_content)
            if github_match:
                if 'socials' not in config:
                    config['socials'] = {}
                config['socials']['github'] = github_match.group(1).strip()
                config['socials']['rss'] = 'https://example.com/rss.xml'

            save_json(CONFIG_FILE, config)
            results['config_updated'] = True
        except Exception as e:
            print(f"解析 about.astro 失败: {e}")

        # 解析 index.astro
        try:
            with sftp.file('/var/www/wonelog-source/src/pages/index.astro', 'r') as f:
                index_content = f.read().decode('utf-8')

            config = load_json(CONFIG_FILE, {})

            greeting_match = re_module.search(r'<h1 class="hero-greeting">([^<]+)</h1>', index_content)
            if greeting_match:
                config['greeting'] = greeting_match.group(1).strip()

            subtitle_match = re_module.search(r'<p class="hero-subtitle">([^<]+)</p>', index_content)
            if subtitle_match:
                config['subtitle'] = subtitle_match.group(1).strip()

            desc_match = re_module.search(r'<p class="hero-desc">([\s\S]*?)</p>\s*</div>', index_content)
            if desc_match:
                desc = desc_match.group(1).strip()
                desc = re_module.sub(r'<br\s*/?>.*', '\n', desc)
                desc = re_module.sub(r'<br\s*/?>', '\n', desc)
                desc = re_module.sub(r'<[^>]+>', '', desc)
                lines = [line.strip() for line in desc.split('\n') if line.strip()]
                config['description'] = lines

            gh_match = re_module.search(r'href="https://github\.com/([^"?]+)"', index_content)
            if gh_match:
                if 'socials' not in config:
                    config['socials'] = {}
                config['socials']['github'] = gh_match.group(1).strip()

            avatar_match = re_module.search(r'src="(https://cdn\.jsdelivr\.net/gh/[^"]+)"', index_content)
            if avatar_match:
                config['avatar'] = avatar_match.group(1).strip()

            save_json(CONFIG_FILE, config)
            results['config_updated'] = True
        except Exception as e:
            print(f"解析 index.astro 失败: {e}")

        # 同步文章
        remote_files = sftp.listdir(SERVER_BLOG_DIR)
        md_files = [f for f in remote_files if f.endswith('.md')]

        for filename in md_files:
            remote_path = SERVER_BLOG_DIR + filename
            local_path = os.path.join(POSTS_DIR, filename)
            sftp.get(remote_path, local_path)

        results['articles'] = len(md_files)

        sftp.close()
        ssh.close()

        parts = []
        if results['articles'] > 0:
            parts.append(f"文章 {results['articles']} 篇")
        if results['config_updated']:
            parts.append("个人信息")
        if results['cities_updated']:
            parts.append("足迹城市")

        message = "同步成功：" + "、".join(parts) if parts else "同步完成，无更新"
        return jsonify({'success': True, 'message': message, 'results': results})

    except Exception as e:
        return jsonify({'success': False, 'message': f'同步失败: {str(e)}'}), 500


@app.route('/api/health', methods=['GET'])
def api_health():
    return jsonify({'status': 'running', 'version': '2.0'})


@app.route('/api/shutdown', methods=['POST', 'GET'])
def api_shutdown():
    """Internal helper."""
    import threading
    def _shutdown():
        import time
        time.sleep(0.3)
        os._exit(0)
    threading.Thread(target=_shutdown, daemon=True).start()
    return jsonify({'success': True, 'message': 'Shutting down...'})


if __name__ == '__main__':
    os.makedirs(POSTS_DIR, exist_ok=True)
    os.makedirs(IMAGES_DIR, exist_ok=True)
    os.makedirs(VERSIONS_DIR, exist_ok=True)
    print("Wonelog 管理服务 v2.0 启动中...")
    print("   璁块棶: http://localhost:5000")
    print(f"   Version snapshots: keep latest {MAX_VERSIONS}")
    app.run(debug=True, port=5000)




