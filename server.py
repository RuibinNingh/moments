import os, json, time
import logging, sys
import yaml
from flask import Flask, request, jsonify, send_from_directory, render_template, g, send_file
from werkzeug.utils import secure_filename
from markdown import markdown
import yaml
from functools import wraps
from flask import request, jsonify
from datetime import datetime, timedelta
from flask_cors import CORS
import re
import jieba
try:
    from latex2mathml.converter import convert as latex_to_mathml
except ImportError:
    latex_to_mathml = None
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

def filter_by_time_limit(items, time_key="meta", time_field="time"):
    """
    根据配置的天数限制过滤数据
    items: 数据列表，每个元素应该有 meta.time 或类似的字段
    time_key: 时间字段所在的键（如 "meta"）
    time_field: 时间字段名（如 "time"）
    返回: 过滤后的列表
    """
    if VIEW_LIMIT < 0:
        # -1 表示无限制
        return items
    
    now = datetime.now()
    limit_date = now - timedelta(days=VIEW_LIMIT)
    filtered = []
    
    for item in items:
        # 支持不同的数据结构
        if time_key:
            time_obj = item.get(time_key, {})
            if isinstance(time_obj, dict):
                t_str = time_obj.get(time_field, "1970-01-01 00:00:00")
            else:
                t_str = str(time_obj)
        else:
            t_str = item.get(time_field, "1970-01-01 00:00:00")
        
        try:
            item_time = datetime.strptime(t_str, "%Y-%m-%d %H:%M:%S")
            if item_time >= limit_date:
                filtered.append(item)
        except:
            # 如果时间解析失败，默认保留（向后兼容）
            filtered.append(item)
    
    return filtered

def is_mobile_client():
    """检测是否为移动端客户端请求"""
    user_agent = request.headers.get("User-Agent", "").lower()
    # 检查 User-Agent 中是否包含移动端标识
    mobile_keywords = ["flutter", "dart", "android", "ios", "mobile"]
    if any(keyword in user_agent for keyword in mobile_keywords):
        return True
    # 也可以通过请求参数指定
    if request.args.get("client") == "mobile":
        return True
    return False

def render_latex_in_html(html, convert_to_mathml=True):
    """将 HTML 中的 LaTeX 公式转换为 MathML 或保留原始格式
    
    Args:
        html: HTML 内容
        convert_to_mathml: 如果为 True，转换为 MathML；如果为 False，保留原始 LaTeX 格式
    """
    if not convert_to_mathml:
        # 移动端：保留原始 LaTeX 格式，不做转换
        return html
    
    if not latex_to_mathml:
        # 如果 latex2mathml 未安装，返回原始 HTML
        return html
    
    def replace_latex(match, is_block=False):
        """替换单个 LaTeX 公式"""
        latex_code = match.group(1)
        try:
            mathml = latex_to_mathml(latex_code)
            # 如果是块级公式，用 div 包裹并居中
            if is_block:
                return f'<div style="text-align: center; margin: 16px 0;">{mathml}</div>'
            return mathml
        except Exception as e:
            logger.warning("latex2mathml conversion error: %s, latex: %s", e, latex_code[:50])
            # 转换失败时返回原始 LaTeX
            return match.group(0)
    
    # 先处理块级公式 $$...$$
    # 使用非贪婪匹配，避免跨多个公式匹配
    html = re.sub(r'\$\$([^$]+?)\$\$', lambda m: replace_latex(m, is_block=True), html, flags=re.DOTALL)
    
    # 再处理行内公式 $...$
    # 使用负向前瞻和后顾，确保 $ 不是 $$ 的一部分，且不匹配空内容
    html = re.sub(r'(?<!\$)\$([^$\n]+?)\$(?!\$)', lambda m: replace_latex(m, is_block=False), html)
    
    return html

def load_post(filepath, convert_latex_to_mathml=True):
    """读取单个动态文件，返回字典
    
    Args:
        filepath: 文件路径
        convert_latex_to_mathml: 是否将 LaTeX 转换为 MathML（移动端设为 False）
    """
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
    # 处理 LaTeX 公式
    html = render_latex_in_html(html, convert_to_mathml=convert_latex_to_mathml)
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

    # 检测是否为移动端请求
    is_mobile = is_mobile_client()
    convert_latex = not is_mobile  # 移动端不转换 LaTeX

    posts = []
    for fp in files:
        post = load_post(fp, convert_latex_to_mathml=convert_latex)
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

    # 应用天数限制过滤
    posts = filter_by_time_limit(posts, time_key="meta", time_field="time")

    res = {
        "count": len(posts),
        "posts": posts
    }
    logger.info("api/posts count=%s, mobile=%s", res["count"], is_mobile)
    return jsonify(res)

@app.route("/api/post/<post_id>")
def get_single_post(post_id):
    """获取单条动态详情"""
    filepath = os.path.join("posts", f"{post_id}.md")
    if not os.path.isfile(filepath):
        logger.warning("api/post not_found id=%s", post_id)
        return jsonify({"error": "Post not found"}), 404

    # 检测是否为移动端请求
    is_mobile = is_mobile_client()
    convert_latex = not is_mobile  # 移动端不转换 LaTeX
    
    post = load_post(filepath, convert_latex_to_mathml=convert_latex)
    # 检查是否超过天数限制
    filtered = filter_by_time_limit([post], time_key="meta", time_field="time")
    if not filtered:
        logger.warning("api/post expired id=%s", post_id)
        return jsonify({"error": "Post not found"}), 404
    
    return jsonify(post)

@app.route("/api/post/query")
def api_post_query():
    """查询动态（按日期或文件名）"""
    date = request.args.get("date")
    filename = request.args.get("filename")
    limit = request.args.get("limit", type=int) or 20
    offset = request.args.get("offset", type=int) or 0

    # date 和 filename 至少提供一个
    if not date and not filename:
        return jsonify({"error": "At least one of 'date' or 'filename' must be provided"}), 400

    # 如果提供了 filename，优先按文件名查询（返回单个动态）
    if filename:
        filepath = os.path.join("posts", filename)
        if not os.path.isfile(filepath):
            logger.warning("api/post/query not_found filename=%s", filename)
            return jsonify({"error": "Post not found"}), 404
        
        # 检测是否为移动端请求
        is_mobile = is_mobile_client()
        convert_latex = not is_mobile  # 移动端不转换 LaTeX
        
        post = load_post(filepath, convert_latex_to_mathml=convert_latex)
        # 检查是否超过天数限制
        filtered = filter_by_time_limit([post], time_key="meta", time_field="time")
        if not filtered:
            logger.warning("api/post/query expired filename=%s", filename)
            return jsonify({"error": "Post not found"}), 404
        
        logger.info("api/post/query filename=%s, mobile=%s", filename, is_mobile)
        return jsonify(post)
    
    # 按日期查询（返回列表）
    if date:
        # 验证日期格式
        try:
            datetime.strptime(date, "%Y-%m-%d")
        except ValueError:
            return jsonify({"error": "Invalid date format, expected YYYY-MM-DD"}), 400
        
        # 查找该日期的所有动态文件
        POST_DIR = "posts"
        if not os.path.exists(POST_DIR):
            return jsonify({"count": 0, "posts": []})
        
        files = [os.path.join(POST_DIR, f) for f in os.listdir(POST_DIR) 
                 if f.endswith(".md") and f.startswith(date)]
        
        # 检测是否为移动端请求
        is_mobile = is_mobile_client()
        convert_latex = not is_mobile  # 移动端不转换 LaTeX
        
        # 加载所有动态
        posts = []
        for fp in files:
            try:
                post = load_post(fp, convert_latex_to_mathml=convert_latex)
                # 验证时间是否匹配（以防文件名格式不一致）
                t_str = post["meta"].get("time", "")
                if t_str.startswith(date):
                    posts.append(post)
            except Exception as e:
                logger.warning("api/post/query error loading file=%s error=%s", fp, e)
                continue
        
        # 按时间排序（最新在前）
        posts.sort(key=lambda x: x["meta"].get("time", ""), reverse=True)
        
        # 应用天数限制过滤
        posts = filter_by_time_limit(posts, time_key="meta", time_field="time")
        
        # 分页
        total_count = len(posts)
        paginated_posts = posts[offset:offset + limit]
        
        res = {
            "count": total_count,
            "posts": paginated_posts
        }
        logger.info("api/post/query date=%s count=%s offset=%s limit=%s", date, total_count, offset, limit)
        return jsonify(res)
    
    return jsonify({"error": "Invalid parameters"}), 400

def load_status(filepath, convert_latex_to_mathml=True):
    """读取单条状态文件
    
    Args:
        filepath: 文件路径
        convert_latex_to_mathml: 是否将 LaTeX 转换为 MathML（移动端设为 False）
    """
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
    # 处理 LaTeX 公式
    html = render_latex_in_html(html, convert_to_mathml=convert_latex_to_mathml)
    return {
        "filename": os.path.basename(filepath),
        "meta": meta,
        "raw": text,
        "html": html
    }

def list_statuses(convert_latex_to_mathml=True):
    """列出所有状态，按时间倒序
    
    Args:
        convert_latex_to_mathml: 是否将 LaTeX 转换为 MathML（移动端设为 False）
    """
    if not os.path.exists("status"):
        return []

    files = [os.path.join("status", f) for f in os.listdir("status") if f.endswith(".md")]

    statuses = []
    for fp in files:
        s = load_status(fp, convert_latex_to_mathml=convert_latex_to_mathml)
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
    # 检测是否为移动端请求
    is_mobile = is_mobile_client()
    convert_latex = not is_mobile  # 移动端不转换 LaTeX
    
    statuses = list_statuses(convert_latex_to_mathml=convert_latex)
    # 应用天数限制过滤
    statuses = filter_by_time_limit(statuses, time_key="meta", time_field="time")
    if not statuses:
        logger.warning("api/status/current empty")
        return jsonify({"error": "No status found"}), 404
    logger.info("api/status/current filename=%s, mobile=%s", statuses[0].get('filename'), is_mobile)
    return jsonify(statuses[0])

@app.route("/api/status/history")
def api_status_history():
    """获取历史状态列表"""
    # 检测是否为移动端请求
    is_mobile = is_mobile_client()
    convert_latex = not is_mobile  # 移动端不转换 LaTeX
    
    statuses = list_statuses(convert_latex_to_mathml=convert_latex)
    # 应用天数限制过滤
    statuses = filter_by_time_limit(statuses, time_key="meta", time_field="time")
    res = {
        "count": len(statuses),
        "statuses": statuses
    }
    logger.info("api/status/history count=%s, mobile=%s", res["count"], is_mobile)
    return jsonify(res)

@app.route("/api/status/query")
def api_status_query():
    """查询状态（按日期或文件名）"""
    date = request.args.get("date")
    filename = request.args.get("filename")
    limit = request.args.get("limit", type=int) or 20
    offset = request.args.get("offset", type=int) or 0

    # date 和 filename 至少提供一个
    if not date and not filename:
        return jsonify({"error": "At least one of 'date' or 'filename' must be provided"}), 400

    # 如果提供了 filename，优先按文件名查询（返回单个状态）
    if filename:
        filepath = os.path.join("status", filename)
        if not os.path.isfile(filepath):
            logger.warning("api/status/query not_found filename=%s", filename)
            return jsonify({"error": "Status not found"}), 404
        
        # 检测是否为移动端请求
        is_mobile = is_mobile_client()
        convert_latex = not is_mobile  # 移动端不转换 LaTeX
        
        status = load_status(filepath, convert_latex_to_mathml=convert_latex)
        # 检查是否超过天数限制
        filtered = filter_by_time_limit([status], time_key="meta", time_field="time")
        if not filtered:
            logger.warning("api/status/query expired filename=%s", filename)
            return jsonify({"error": "Status not found"}), 404
        
        logger.info("api/status/query filename=%s, mobile=%s", filename, is_mobile)
        return jsonify(status)
    
    # 按日期查询（返回列表）
    if date:
        # 验证日期格式
        try:
            datetime.strptime(date, "%Y-%m-%d")
        except ValueError:
            return jsonify({"error": "Invalid date format, expected YYYY-MM-DD"}), 400
        
        # 查找该日期的所有状态文件
        STATUS_DIR = "status"
        if not os.path.exists(STATUS_DIR):
            return jsonify({"count": 0, "statuses": []})
        
        files = [os.path.join(STATUS_DIR, f) for f in os.listdir(STATUS_DIR) 
                 if f.endswith(".md") and f.startswith(date)]
        
        # 检测是否为移动端请求
        is_mobile = is_mobile_client()
        convert_latex = not is_mobile  # 移动端不转换 LaTeX
        
        # 加载所有状态
        statuses = []
        for fp in files:
            try:
                status = load_status(fp, convert_latex_to_mathml=convert_latex)
                # 验证时间是否匹配（以防文件名格式不一致）
                t_str = status["meta"].get("time", "")
                if t_str.startswith(date):
                    statuses.append(status)
            except Exception as e:
                logger.warning("api/status/query error loading file=%s error=%s", fp, e)
                continue
        
        # 按时间排序（最新在前）
        statuses.sort(key=lambda x: x["meta"].get("time", ""), reverse=True)
        
        # 应用天数限制过滤
        statuses = filter_by_time_limit(statuses, time_key="meta", time_field="time")
        
        # 分页
        total_count = len(statuses)
        paginated_statuses = statuses[offset:offset + limit]
        
        res = {
            "count": total_count,
            "statuses": paginated_statuses
        }
        logger.info("api/status/query date=%s count=%s offset=%s limit=%s", date, total_count, offset, limit)
        return jsonify(res)
    
    return jsonify({"error": "Invalid parameters"}), 400

def strip_html(html_text):
    """把 HTML 内容去掉标签，只保留纯文本。"""
    return re.sub(r"<[^>]+>", "", html_text or "")

def segment_terms(s):
    """jieba 分词"""
    s = (s or "").strip()
    if not s:
        return []
    toks = []
    if jieba:
        try:
            toks = list(jieba.cut_for_search(s))
        except Exception:
            toks = []
    if not toks:
        ascii_runs = re.findall(r"[A-Za-z0-9_]+", s)
        zh_runs = re.findall(r"[\u4e00-\u9fff]+", s)
        toks = ascii_runs + zh_runs
    seen = set(); ordered = []
    for t in toks:
        tl = t.lower()
        if tl and tl not in seen:
            seen.add(tl)
            ordered.append(tl)
    return ordered

def score_item(q, item_text, name="", tags=None):
    """给一条动态或状态打分，表示它和搜索词 q 的匹配程度。"""
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
            if ql in hay: sc += 110
        toks = segment_terms(ql)
        for t in toks:
            L = max(1, len(t))
            base = 8 * L
            if any(tt.lower() == t for tt in tags): sc += base + 40
            if name.lower().startswith(t): sc += base + 30
            if t in name.lower(): sc += base + 20
            if t in hay: sc += base + 16
    return sc


@app.route('/api/search')
def api_search():
    q = request.args.get('q', '')
    # 检测是否为移动端请求
    is_mobile = is_mobile_client()
    convert_latex = not is_mobile  # 移动端不转换 LaTeX
    
    items = []
    if os.path.exists('posts'):
        for f in os.listdir('posts'):
            if not f.endswith('.md'):
                continue
            fp = os.path.join('posts', f)
            p = load_post(fp, convert_latex_to_mathml=convert_latex)
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
    # 应用天数限制过滤
    items = filter_by_time_limit(items, time_key="meta", time_field="time")
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

    # 检测是否为移动端请求
    is_mobile = is_mobile_client()
    convert_latex = not is_mobile  # 移动端不转换 LaTeX
    
    # 返回创建的动态
    post = load_post(filepath, convert_latex_to_mathml=convert_latex)
    logger.info("api/post/new filename=%s size=%s tags=%s, mobile=%s", filename, len(content), len(tags), is_mobile)
    return jsonify(post), 201

@app.route("/api/status/new", methods=["POST"])
@require_api_key
def api_status_new():
    """创建新状态"""
    data = request.json or {}
    content = data.get("content", "")
    name = data.get("name", "")
    icon = data.get("icon", "")  # 获取图标字段（Emoji）
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
        if icon:  # 如果有图标，写入图标字段
            f.write(f'icon: {icon}\n')
        if background:  # 如果有背景，写入背景字段
            f.write(f'background: "{background}"\n')
        f.write("---\n\n")
        f.write(content)

    # 新建状态时，默认转换为 MathML（网页端显示）
    # 移动端会在下次请求时获取保留 LaTeX 的版本
    status = load_status(filepath, convert_latex_to_mathml=True)
    logger.info("api/status/new filename=%s size=%s name=%s icon=%s", filename, len(content), name, icon)
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
    """提供上传的静态文件（公开访问，不需要API Key）"""
    return send_from_directory("upload/", filename)

@app.route("/upload", methods=["POST"])
@require_api_key
def api_upload_file():
    """上传文件接口"""
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400
    
    # 确保upload目录存在
    upload_dir = "upload"
    if not os.path.exists(upload_dir):
        os.makedirs(upload_dir)
    
    # 安全文件名
    filename = secure_filename(file.filename)
    filepath = os.path.join(upload_dir, filename)
    
    # 如果文件已存在，添加时间戳
    if os.path.exists(filepath):
        name, ext = os.path.splitext(filename)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{name}_{timestamp}{ext}"
        filepath = os.path.join(upload_dir, filename)
    
    try:
        file.save(filepath)
        base_url = f"http://{HOST}:{PORT}"
        return jsonify({
            "message": "File uploaded",
            "filename": filename,
            "url": f"{base_url}/download/{filename}"
        }), 200
    except Exception as e:
        logger.error(f"Upload error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/download/<path:filename>", methods=["GET"])
@require_api_key
def api_download_file(filename):
    """下载文件接口"""
    filepath = os.path.join("upload", filename)
    if not os.path.exists(filepath):
        return jsonify({"error": "File not found"}), 404
    
    try:
        return send_file(filepath, as_attachment=True)
    except Exception as e:
        logger.error(f"Download error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/files", methods=["GET"])
@require_api_key
def api_list_files():
    """获取文件列表接口"""
    upload_dir = "upload"
    if not os.path.exists(upload_dir):
        return jsonify({"files": []}), 200
    
    files = []
    for filename in os.listdir(upload_dir):
        filepath = os.path.join(upload_dir, filename)
        if os.path.isfile(filepath):
            stat = os.stat(filepath)
            size = stat.st_size
            
            # 格式化文件大小
            if size < 1024:
                size_human = f"{size} B"
            elif size < 1024 * 1024:
                size_human = f"{size / 1024:.1f} KB"
            else:
                size_human = f"{size / (1024 * 1024):.1f} MB"
            
            # 格式化修改时间
            modified = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            
            files.append({
                "name": filename,
                "size": size,
                "size_human": size_human,
                "modified": modified
            })
    
    # 按修改时间倒序排列
    files.sort(key=lambda x: x["modified"], reverse=True)
    
    return jsonify({"files": files}), 200

@app.route("/files/<path:filename>", methods=["DELETE"])
@require_api_key
def api_delete_file(filename):
    """删除文件接口"""
    filepath = os.path.join("upload", filename)
    if not os.path.exists(filepath):
        return jsonify({"error": "File not found"}), 404
    
    try:
        os.remove(filepath)
        return jsonify({"message": "File deleted", "filename": filename}), 200
    except Exception as e:
        logger.error(f"Delete error: {e}")
        return jsonify({"error": str(e)}), 500
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

    # 读取 posts 数量与最新时间（考虑天数限制）
    posts = list_status_or_posts("posts")
    posts = filter_by_time_limit(posts, time_key="meta", time_field="time")
    post_count = len(posts)
    latest_post_time = posts[0]["meta"].get("time") if post_count > 0 else None

    # 读取 status 数量与最新时间（考虑天数限制）
    statuses = list_status_or_posts("status")
    statuses = filter_by_time_limit(statuses, time_key="meta", time_field="time")
    status_count = len(statuses)
    latest_status_time = statuses[0]["meta"].get("time") if status_count > 0 else None

    info = {
        "nickname": nickname,
        "avatar": avatar,
        "post_count": post_count,
        "status_count": status_count,
        "view_time_limit_days": VIEW_LIMIT,
        "latest_post_time": latest_post_time,
        "latest_status_time": latest_status_time
    }

    return jsonify(info)

@app.route("/api/frontend/config")
def api_frontend_config():
    """获取前端个性化配置"""
    # 从配置文件中读取 frontend.background.type
    # 如果没有配置，默认使用 "image"
    background_type = "image"
    try:
        frontend_config = config.get("frontend", {})
        background_config = frontend_config.get("background", {})
        background_type = background_config.get("type", "image")
    except Exception as e:
        logger.warning("api/frontend/config error reading config: %s", e)
    
    result = {
        "background": background_type
    }
    
    logger.info("api/frontend/config background=%s", background_type)
    return jsonify(result)

@app.route("/api/remove", methods=["POST"])
@require_api_key
def api_remove():
    """删除动态或状态"""
    data = request.json or {}
    file_type = data.get("type", "").lower()
    filename = data.get("file", "")
    
    if not file_type:
        return jsonify({"error": "Parameter 'type' is required"}), 400
    
    if not filename:
        return jsonify({"error": "Parameter 'file' is required"}), 400
    
    # 验证type参数
    if file_type not in ["posts", "status"]:
        return jsonify({"error": "Parameter 'type' must be 'posts' or 'status'"}), 400
    
    # 确保文件名以.md结尾
    if not filename.endswith(".md"):
        filename = f"{filename}.md"
    
    # 构建文件路径
    folder = "posts" if file_type == "posts" else "status"
    filepath = os.path.join(folder, filename)
    
    # 检查文件是否存在
    if not os.path.isfile(filepath):
        logger.warning("api/remove not_found type=%s file=%s", file_type, filename)
        return jsonify({"error": "File not found"}), 404
    
    try:
        os.remove(filepath)
        logger.info("api/remove deleted type=%s file=%s", file_type, filename)
        return jsonify({"message": "File deleted", "type": file_type, "file": filename}), 200
    except Exception as e:
        logger.error("api/remove error type=%s file=%s error=%s", file_type, filename, e)
        return jsonify({"error": str(e)}), 500

@app.route("/api/post/edit", methods=["POST"])
@require_api_key
def api_post_edit():
    """编辑动态"""
    data = request.json or {}
    post_file = data.get("post_file", "")
    content = data.get("content")
    tags = data.get("tags")
    time_str = data.get("time")
    
    if not post_file:
        return jsonify({"error": "Parameter 'post_file' is required"}), 400
    
    # 确保文件名以.md结尾
    if not post_file.endswith(".md"):
        post_file = f"{post_file}.md"
    
    filepath = os.path.join("posts", post_file)
    
    # 检查文件是否存在
    if not os.path.isfile(filepath):
        logger.warning("api/post/edit not_found file=%s", post_file)
        return jsonify({"error": "Post not found"}), 404
    
    # 读取现有文件
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            text = f.read()
        
        # 解析现有内容
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
        
        # 更新字段（如果提供了新值）
        if content is not None:
            body = content
        if tags is not None:
            meta["tags"] = tags
        if time_str is not None:
            meta["time"] = time_str
        
        # 确保time字段存在
        if "time" not in meta:
            meta["time"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 写入文件
        with open(filepath, "w", encoding="utf-8") as f:
            f.write("---\n")
            f.write(f'time: "{meta["time"]}"\n')
            if "tags" in meta:
                f.write(f'tags: {meta["tags"]}\n')
            f.write("---\n\n")
            f.write(body)
        
        # 检测是否为移动端请求
        is_mobile = is_mobile_client()
        convert_latex = not is_mobile  # 移动端不转换 LaTeX
        
        # 返回更新后的动态
        post = load_post(filepath, convert_latex_to_mathml=convert_latex)
        logger.info("api/post/edit updated file=%s, mobile=%s", post_file, is_mobile)
        return jsonify(post), 200
        
    except Exception as e:
        logger.error("api/post/edit error file=%s error=%s", post_file, e)
        return jsonify({"error": str(e)}), 500

@app.route("/api/status/edit", methods=["PUT"])
@require_api_key
def api_status_edit():
    """编辑状态"""
    data = request.json or {}
    status_file = data.get("status_file", "")
    content = data.get("content")
    name = data.get("name")
    icon = data.get("icon")
    background = data.get("background")
    time_str = data.get("time")
    
    if not status_file:
        return jsonify({"error": "Parameter 'status_file' is required"}), 400
    
    # 确保文件名以.md结尾
    if not status_file.endswith(".md"):
        status_file = f"{status_file}.md"
    
    filepath = os.path.join("status", status_file)
    
    # 检查文件是否存在
    if not os.path.isfile(filepath):
        logger.warning("api/status/edit not_found file=%s", status_file)
        return jsonify({"error": "Status not found"}), 404
    
    # 读取现有文件
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            text = f.read()
        
        # 解析现有内容
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
        
        # 更新字段（如果提供了新值）
        if content is not None:
            body = content
        if name is not None:
            meta["name"] = name
        if icon is not None:
            meta["icon"] = icon
        if background is not None:
            meta["background"] = background
        if time_str is not None:
            meta["time"] = time_str
        
        # 确保time字段存在
        if "time" not in meta:
            meta["time"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        # 写入文件
        with open(filepath, "w", encoding="utf-8") as f:
            f.write("---\n")
            f.write(f'time: "{meta["time"]}"\n')
            if "name" in meta:
                f.write(f'name: "{meta["name"]}"\n')
            if "icon" in meta:
                f.write(f'icon: {meta["icon"]}\n')
            if "background" in meta:
                f.write(f'background: "{meta["background"]}"\n')
            f.write("---\n\n")
            f.write(body)
        
        # 检测是否为移动端请求
        is_mobile = is_mobile_client()
        convert_latex = not is_mobile  # 移动端不转换 LaTeX
        
        # 返回更新后的状态
        status = load_status(filepath, convert_latex_to_mathml=convert_latex)
        logger.info("api/status/edit updated file=%s, mobile=%s", status_file, is_mobile)
        return jsonify(status), 200
        
    except Exception as e:
        logger.error("api/status/edit error file=%s error=%s", status_file, e)
        return jsonify({"error": str(e)}), 500

@app.route("/api/reload", methods=["GET"])
@require_api_key
def api_reload():
    """刷新配置，重新读取config.yaml"""
    global config, API_KEY, VIEW_LIMIT, nickname, avatar, HOST, PORT
    
    try:
        with open("config.yaml", "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
        
        # 更新全局变量
        API_KEY = config.get("api_key", "")
        VIEW_LIMIT = config.get("view_time_limit_days", 9999)
        nickname = config.get("nickname", "")
        avatar = config.get("avatar", "")
        HOST = config["server"].get("host", "127.0.0.1")
        PORT = config["server"].get("port", 5000)
        
        logger.info("api/reload success")
        return jsonify({
            "message": "Configuration reloaded",
            "nickname": nickname,
            "avatar": avatar,
            "view_time_limit_days": VIEW_LIMIT,
            "host": HOST,
            "port": PORT
        }), 200
        
    except Exception as e:
        logger.error("api/reload error: %s", e)
        return jsonify({"error": str(e)}), 500

@app.route("/api/config", methods=["GET"])
@require_api_key
def api_get_config():
    """获取配置文件（返回 YAML 格式）"""
    try:
        with open("config.yaml", "r", encoding="utf-8") as f:
            yaml_content = f.read()
        
        logger.info("api/config success")
        # 返回 YAML 格式的文本，设置正确的 Content-Type
        from flask import Response
        return Response(
            yaml_content,
            mimetype="application/x-yaml",
            headers={"Content-Type": "application/x-yaml; charset=utf-8"}
        )
        
    except Exception as e:
        logger.error("api/config error: %s", e)
        return jsonify({"error": str(e)}), 500

@app.route("/api/config/edit", methods=["POST"])
@require_api_key
def api_edit_config():
    """编辑配置文件（接收 YAML 格式）"""
    global config, API_KEY, VIEW_LIMIT, nickname, avatar, HOST, PORT
    
    try:
        # 获取请求体中的 YAML 内容
        yaml_content = request.get_data(as_text=True)
        
        if not yaml_content:
            return jsonify({"error": "YAML content is required"}), 400
        
        # 验证 YAML 格式
        try:
            test_config = yaml.safe_load(yaml_content)
            if not isinstance(test_config, dict):
                return jsonify({"error": "Invalid YAML format"}), 400
        except yaml.YAMLError as e:
            logger.error("api/config/edit yaml_error: %s", e)
            return jsonify({"error": f"Invalid YAML format: {str(e)}"}), 400
        
        # 备份原配置文件
        import shutil
        backup_path = "config.yaml.backup"
        if os.path.exists("config.yaml"):
            shutil.copy2("config.yaml", backup_path)
        
        # 写入新配置
        with open("config.yaml", "w", encoding="utf-8") as f:
            f.write(yaml_content)
        
        # 重新加载配置到内存
        config = yaml.safe_load(yaml_content)
        API_KEY = config.get("api_key", "")
        VIEW_LIMIT = config.get("view_time_limit_days", 9999)
        nickname = config.get("nickname", "")
        avatar = config.get("avatar", "")
        HOST = config["server"].get("host", "127.0.0.1")
        PORT = config["server"].get("port", 5000)
        
        logger.info("api/config/edit success")
        return jsonify({
            "message": "Configuration updated successfully",
            "nickname": nickname,
            "avatar": avatar,
            "view_time_limit_days": VIEW_LIMIT,
            "host": HOST,
            "port": PORT
        }), 200
        
    except Exception as e:
        logger.error("api/config/edit error: %s", e)
        # 如果出错，尝试恢复备份
        if os.path.exists("config.yaml.backup"):
            try:
                shutil.copy2("config.yaml.backup", "config.yaml")
            except:
                pass
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host=HOST, port=PORT, debug=1)

#启动备注:cmd.exe /K "C:\Ruibin_Ningh\app\Anaconda\Scripts\activate.bat" TongYong

