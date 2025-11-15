import os, json, time
import yaml
from flask import Flask, request, jsonify, send_from_directory, render_template
from markdown import markdown
import yaml
from functools import wraps
from flask import request, jsonify
from datetime import datetime
app = Flask(__name__)

# ----------------------读取配置----------------------
with open("config.yaml", "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

API_KEY = config.get("api_key", "")
VIEW_LIMIT = config.get("view_time_limit_days", 9999)
nickname = config.get("nickname", "")
avatar = config.get("avatar", "")

HOST = config["server"].get("host", "127.0.0.1")
PORT = config["server"].get("port", 5000)

def require_api_key(f):
    """验证"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get("X-API-KEY") or request.args.get("api_key")
        if API_KEY and token != API_KEY:
            return jsonify({"error": "Invalid API key"}), 401
        return f(*args, **kwargs)
    return decorated


def load_post(filepath):
    """读取单个动态文件，返回字典"""
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()
    # 解析 Markdown + YAML 前置信息
    if text.startswith("---"):
        try:
            _, fm, body = text.split("---", 2)
            meta = yaml.safe_load(fm) or {}
        except:
            meta = {}
            body = text
    else:
        meta = {}
        body = text

    html = markdown(body, extensions=["extra", "codehilite"])
    return {
        "meta": meta,
        "html": html,
        "raw": text,
        "filename": os.path.basename(filepath)
    }

@app.route("/")
def index():
    """这是主页面"""
    return render_template("index.html",
                           nickname=nickname,
                           avatar=avatar
                           )

@app.route("/api/posts")
def api_posts():
    """返回所有动态，按时间倒序（最新在前）"""
    POST_DIR = "posts"
    if not os.path.exists(POST_DIR):
        return jsonify({"count": 0, "posts": []})

    files = [os.path.join(POST_DIR, f) for f in os.listdir(POST_DIR) if f.endswith(".md")]

    posts = []
    for fp in files:
        post = load_post(fp)
        # 尝试读取 meta.time，转换为 datetime 对象
        t_str = post["meta"].get("time", "1970-01-01 00:00:00")
        try:
            post_time = datetime.strptime(t_str, "%Y-%m-%d %H:%M:%S")
        except:
            post_time = datetime(1970, 1, 1)
        post["meta"]["_datetime"] = post_time  # 临时字段，用于排序
        posts.append(post)

    # 按时间排序，最新在前
    posts.sort(key=lambda x: x["meta"]["_datetime"], reverse=True)

    # 删除临时字段
    for p in posts:
        p["meta"].pop("_datetime", None)

    return jsonify({
        "count": len(posts),
        "posts": posts
    })

@app.route("/api/post/<post_id>")
def get_single_post(post_id):
    """获取单条动态详情"""
    filepath = os.path.join("posts", f"{post_id}.md")
    if not os.path.isfile(filepath):
        return jsonify({"error": "Post not found"}), 404

    post = load_post(filepath)
    return jsonify(post)

def load_status(filepath):
    """读取单条状态文件"""
    with open(filepath, "r", encoding="utf-8") as f:
        text = f.read()

    if text.startswith("---"):
        try:
            _, fm, body = text.split("---", 2)
            meta = yaml.safe_load(fm) or {}
        except:
            meta = {}
            body = text
    else:
        meta = {}
        body = text

    html = markdown(body, extensions=["extra", "codehilite"])
    return {
        "filename": os.path.basename(filepath),
        "meta": meta,
        "raw": text,
        "html": html
    }

def list_statuses():
    """列出所有状态，按时间倒序"""
    if not os.path.exists("status"):
        return []

    files = [os.path.join("status", f) for f in os.listdir("status") if f.endswith(".md")]

    statuses = []
    for fp in files:
        s = load_status(fp)
        # 尝试解析时间
        t_str = s["meta"].get("time", "1970-01-01 00:00:00")
        try:
            s["_datetime"] = datetime.strptime(t_str, "%Y-%m-%d %H:%M:%S")
        except:
            s["_datetime"] = datetime(1970,1,1)
        statuses.append(s)

    statuses.sort(key=lambda x: x["_datetime"], reverse=True)

    # 删除临时字段
    for s in statuses:
        s.pop("_datetime", None)

    return statuses

@app.route("/api/status/current")
def api_status_current():
    """获取最新状态"""
    statuses = list_statuses()
    if not statuses:
        return jsonify({"error": "No status found"}), 404
    return jsonify(statuses[0])

@app.route("/api/status/history")
def api_status_history():
    """获取历史状态列表"""
    statuses = list_statuses()
    return jsonify({
        "count": len(statuses),
        "statuses": statuses
    })

@app.route("/api/post/new", methods=["POST"])
@require_api_key
def api_post_new():
    """创建新动态"""
    data = request.json or {}
    content = data.get("content", "")
    tags = data.get("tags", [])
    time_str = data.get("time") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if not content:
        return jsonify({"error": "Content is required"}), 400

    # 生成文件名，例如: 2025-11-15-3.md
    date_part = time_str.split(" ")[0].replace("-", "")
    existing = [f for f in os.listdir("posts") if f.startswith(date_part)]
    idx = len(existing) + 1
    filename = f"{date_part}-{idx}.md"
    filepath = os.path.join("posts", filename)

    # 写入文件
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("---\n")
        f.write(f'time: "{time_str}"\n')
        f.write(f'tags: {tags}\n')
        f.write("---\n\n")
        f.write(content)

    # 返回创建的动态
    post = load_post(filepath)
    return jsonify(post), 201

@app.route("/api/status/new", methods=["POST"])
@require_api_key
def api_status_new():
    """创建新状态"""
    data = request.json or {}
    content = data.get("content", "")
    name = data.get("name", "")
    background = data.get("background", "")
    time_str = data.get("time") or datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if not content:
        return jsonify({"error": "Content is required"}), 400

    # 生成文件名，例如: 20251115-1.md
    date_part = time_str.split(" ")[0].replace("-", "")
    existing = [f for f in os.listdir("status") if f.startswith(date_part)]
    idx = len(existing) + 1
    filename = f"{date_part}-{idx}.md"
    filepath = os.path.join("status", filename)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write("---\n")
        f.write(f'time: "{time_str}"\n')
        f.write(f'name: "{name}"\n')
        f.write(f'background: "{background}"\n')
        f.write("---\n\n")
        f.write(content)

    status = load_status(filepath)
    return jsonify(status), 201

@app.route("/css/<path:filename>")
def serve_css(filename):
    """提供 CSS 静态文件"""
    return send_from_directory("templates/css/", filename)
@app.route("/script/<path:filename>")
def serve_script(filename):
    """提供 JS 静态文件"""
    return send_from_directory("templates/script/", filename)
@app.route("/post")
def post_page():
    """动态页面"""
    return render_template("post.html",
                           nickname=nickname,
                           avatar=avatar
                           )    
@app.route("/status")
def status_page():
    """状态页面"""
    return render_template("status.html",
                           nickname=nickname,
                           avatar=avatar
                           )
@app.route("/upload/<path:filename>")
def serve_uploads(filename):
    """提供上传的静态文件"""
    return send_from_directory("upload/", filename)
if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=1)

#启动备注:cmd.exe /K "C:\Ruibin_Ningh\app\Anaconda\Scripts\activate.bat" TongYong
