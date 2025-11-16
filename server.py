import os, json, time
import logging, sys
import yaml
from flask import Flask, request, jsonify, send_from_directory, render_template, g
from markdown import markdown
import yaml
from functools import wraps
from flask import request, jsonify
from datetime import datetime
from flask_cors import CORS
import re
app = Flask(__name__)
CORS(app, supports_credentials=True)
logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
                    handlers=[logging.StreamHandler(sys.stdout)])
logger = logging.getLogger('moments')
logger.setLevel(logging.DEBUG)
logging.getLogger('werkzeug').setLevel(logging.INFO)

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

@app.before_request
def _req_log():
    g._ts = time.time()
    ua = request.headers.get('User-Agent','')
    logger.info("REQ %s %s ip=%s ua=%s", request.method, request.path, request.remote_addr, ua[:160])

@app.after_request
def _res_log(resp):
    dur = (time.time() - getattr(g, '_ts', time.time())) * 1000.0
    try:
        length = resp.calculate_content_length()
    except Exception:
        length = '-'
    logger.info("RES %s %s status=%s dur=%.1fms len=%s", request.method, request.path, resp.status_code, dur, length)
    return resp

@app.errorhandler(Exception)
def _err_log(e):
    logger.exception("ERR %s %s", request.method, request.path)
    return jsonify({"error": "Internal Server Error"}), 500

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

    res = {
        "count": len(posts),
        "posts": posts
    }
    logger.info("api/posts count=%s", res["count"])
    return jsonify(res)

@app.route("/api/post/<post_id>")
def get_single_post(post_id):
    """获取单条动态详情"""
    filepath = os.path.join("posts", f"{post_id}.md")
    if not os.path.isfile(filepath):
        logger.warning("api/post not_found id=%s", post_id)
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
        logger.warning("api/status/current empty")
        return jsonify({"error": "No status found"}), 404
    logger.info("api/status/current filename=%s", statuses[0].get('filename'))
    return jsonify(statuses[0])

@app.route("/api/status/history")
def api_status_history():
    """获取历史状态列表"""
    statuses = list_statuses()
    res = {
        "count": len(statuses),
        "statuses": statuses
    }
    logger.info("api/status/history count=%s", res["count"])
    return jsonify(res)

def strip_html(html_text):
    return re.sub(r"<[^>]+>", "", html_text or "")

def score_item(q, item_text, name="", tags=None):
    tags = tags or []
    s = (q or "").strip()
    if not s:
        return 0
    hay = f"{name} {' '.join(tags)} {item_text}".lower()
    sc = 0
    is_regex = re.match(r"^\s*/.+/[a-zA-Z0-9]*\s*$", s)
    if is_regex:
        try:
            m = re.match(r"^\s*/(.+)/([a-zA-Z0-9]*)\s*$", s)
            pattern = m.group(1)
            flags = 0
            if m.group(2):
                if 'i' in m.group(2): flags |= re.IGNORECASE
            reg = re.compile(pattern, flags)
            if reg.search(hay): sc += 90
        except Exception:
            pass
    else:
        ql = s.lower()
        small_ascii = len(ql) < 2 and re.match(r"^[\x00-\x7F]+$", ql)
        if any(t.lower() == ql for t in tags): sc += 120
        if name.lower().startswith(ql): sc += 90
        if not small_ascii:
            if ql in name.lower(): sc += 70
            if ql in hay: sc += 60
    return sc

@app.route('/api/search')
def api_search():
    q = request.args.get('q', '')
    items = []
    if os.path.exists('posts'):
        for f in os.listdir('posts'):
            if not f.endswith('.md'):
                continue
            fp = os.path.join('posts', f)
            p = load_post(fp)
            t_str = p['meta'].get('time', '1970-01-01 00:00:00')
            try:
                dt = datetime.strptime(t_str, "%Y-%m-%d %H:%M:%S")
            except:
                dt = datetime(1970,1,1)
            plain = strip_html(p.get('html',''))
            sc = score_item(q, plain, name="", tags=p['meta'].get('tags', []))
            items.append({
                'type': 'post',
                'filename': p['filename'],
                'meta': p['meta'],
                'html': p['html'],
                'raw': p['raw'],
                '_score': sc,
                '_dt': dt
            })
    for s in list_statuses():
        t_str = s['meta'].get('time', '1970-01-01 00:00:00')
        try:
            dt = datetime.strptime(t_str, "%Y-%m-%d %H:%M:%S")
        except:
            dt = datetime(1970,1,1)
        plain = strip_html(s.get('html',''))
        sc = score_item(q, plain, name=s['meta'].get('name',''), tags=[])
        items.append({
            'type': 'status',
            'filename': s['filename'],
            'meta': s['meta'],
            'html': s['html'],
            'raw': s['raw'],
            '_score': sc,
            '_dt': dt
        })

    s_val = (q or '').strip()
    is_regex = re.match(r"^\s*/.+/[a-zA-Z0-9]*\s*$", s_val)
    if is_regex:
        threshold = 60
    else:
        small_ascii = len(s_val) < 2 and re.match(r"^[\x00-\x7F]+$", s_val or '')
        threshold = 80 if small_ascii else 40

    before = len(items)
    items = [x for x in items if x.get('_score',0) >= threshold]
    items.sort(key=lambda x: (x['_score'], x['_dt']), reverse=True)
    for x in items:
        x.pop('_score', None)
        x.pop('_dt', None)
    res = { 'count': len(items), 'items': items }
    logger.info("api/search q=%s matched=%s filtered_from=%s", (q or '')[:120], res['count'], before)
    return jsonify(res)

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
    date_part = time_str.split(" ")[0]  # 提取日期部分，保留横杠，例如: 2025-11-15
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
    logger.info("api/post/new filename=%s size=%s tags=%s", filename, len(content), len(tags))
    return jsonify(post), 201

@app.route("/api/status/new", methods=["POST"])
@require_api_key
def api_status_new():
    """创建新状态"""
    data = request.json or {}
    content = data.get("content", "")
    name = data.get("name", "")
    background = data.get("background", "")
    time_str = data.get("time") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    if not content:
        return jsonify({"error": "Content is required"}), 400

    # 生成文件名，例如: 2025-11-15-1.md
    date_part = time_str.split(" ")[0]  # 提取日期部分，保留横杠，例如: 2025-11-15
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
    logger.info("api/status/new filename=%s size=%s name=%s", filename, len(content), name)
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
@app.route("/status/view")
def status_view_page():
    return render_template("status_view.html",
                           nickname=nickname,
                           avatar=avatar
                           )
@app.route("/search")
def search_page():
    q = request.args.get('q', '')
    return render_template("search.html",
                           nickname=nickname,
                           avatar=avatar,
                           query=q)
@app.route("/upload/<path:filename>")
def serve_uploads(filename):
    """提供上传的静态文件"""
    return send_from_directory("upload/", filename)
def list_status_or_posts(folder):
    """读取状态或动态目录，按时间倒序返回解析结果"""
    if not os.path.exists(folder):
        return []

    files = [os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".md")]
    items = []

    for fp in files:
        with open(fp, "r", encoding="utf-8") as f:
            text = f.read()

        if text.startswith("---"):
            try:
                _, fm, _ = text.split("---", 2)
                meta = yaml.safe_load(fm) or {}
            except:
                meta = {}
        else:
            meta = {}

        # 解析时间
        t_str = meta.get("time", "1970-01-01 00:00:00")
        try:
            dt = datetime.strptime(t_str, "%Y-%m-%d %H:%M:%S")
        except:
            dt = datetime(1970,1,1)

        items.append({
            "filename": os.path.basename(fp),
            "meta": meta,
            "_dt": dt
        })

    items.sort(key=lambda x: x["_dt"], reverse=True)
    return items

@app.route("/api/user/info")
def api_user_info():
    """获取用户基础信息（头像、昵称、动态数量等）"""

    # 读取 posts 数量与最新时间
    posts = list_status_or_posts("posts")
    post_count = len(posts)
    latest_post_time = posts[0]["meta"].get("time") if post_count > 0 else None

    # 读取 status 数量与最新时间
    statuses = list_status_or_posts("status")
    status_count = len(statuses)
    latest_status_time = statuses[0]["meta"].get("time") if status_count > 0 else None

    info = {
        "nickname": nickname,
        "avatar": avatar,
        "post_count": post_count,
        "status_count": status_count,
        "latest_post_time": latest_post_time,
        "latest_status_time": latest_status_time
    }

    return jsonify(info)

if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=1)

#启动备注:cmd.exe /K "C:\Ruibin_Ningh\app\Anaconda\Scripts\activate.bat" TongYong

