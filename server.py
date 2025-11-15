import os, json, time
import yaml
from flask import Flask, request, jsonify, send_from_directory, render_template
from markdown import markdown
import yaml
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
    return render_template("index.html",
                           nickname=nickname,
                           avatar=avatar
                           )

@app.route("/api/posts")
def api_posts():
    """返回所有动态"""
    if not os.path.exists("posts"):
        return jsonify({"count": 0, "posts": []})

    files = sorted(
        [os.path.join("posts", f) for f in os.listdir("posts") if f.endswith(".md")],
        reverse=True   # 最新的动态排在前面
    )

    posts = [load_post(fp) for fp in files]

    return jsonify({
        "count": len(posts),
        "posts": posts
    })

if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug='DEBUG')
