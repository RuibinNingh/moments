import os, json, time
import yaml
from flask import Flask, request, jsonify, send_from_directory, render_template
from markdown import markdown
import yaml
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

if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug='DEBUG')
