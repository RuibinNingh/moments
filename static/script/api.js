// 简易 API 封装：直接请求后端 server.py 暴露的接口
(function () {
  const BASE_URL = 'http://127.0.0.1:5000';
  // 运行环境提示：若不是 Flask 5000 端口，且路径在 /static 下，提醒可能 404
  try {
    const port = window.location.port;
    const path = window.location.pathname || '';
    if (path.startsWith('/static') && port && port !== '5000') {
      console.warn('[API] 当前页面未由 Flask(5000) 提供，/api/* 将请求到', window.location.origin, '，可能导致 404。请使用 http://127.0.0.1:5000/static/index.html 打开页面以同源访问接口。');
    }
  } catch (_) {}
  const DEBUG = { last: {}, lastError: null };

  async function fetchJSON(path) {
    const url = BASE_URL + path;
    try {
      const res = await fetch(url, {
        headers: { 'Accept': 'application/json' },
        credentials: 'same-origin',
        cache: 'no-store',
        redirect: 'follow'
      });
      const contentType = res.headers.get('content-type') || '';
      const payload = contentType.includes('application/json') ? (await res.json()) : (await res.text());
      DEBUG.last[path] = { status: res.status, ok: res.ok, url, contentType, data: payload };
      if (!res.ok) {
        const errMsg = typeof payload === 'string' ? payload : (payload && payload.error) || `HTTP ${res.status}`;
        // 返回结构化错误，不再直接置空，便于上层展示细节
        return { error: errMsg, status: res.status, data: payload };
      }
      return payload;
    } catch (err) {
      DEBUG.lastError = { path, url, error: err?.message || String(err), stack: err?.stack };
      console.error(`[API] 请求异常: ${path}`, DEBUG.lastError);
      return { error: DEBUG.lastError.error, exception: true };
    }
  }

  // 不再使用本地 Mock，直接依赖后端返回

  // 时间工具
  function parseTime(str) { return new Date(str.replace(/-/g,'/')); }
  function formatTime(d) {
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  function sortByTimeDesc(items) {
    return [...items].sort((a,b) => parseTime(b.meta?.time||'') - parseTime(a.meta?.time||''));
  }

  function getIdFromFilename(filename) {
    return String(filename||'').replace(/\.md$/,'');
  }

  // API 方法（新）
  async function getPostList() {
    const data = await fetchJSON('/api/posts');
    const list = Array.isArray(data?.posts) ? data.posts : [];
    return sortByTimeDesc(list);
  }

  async function getPostDetail(idOrFilename) {
    const id = getIdFromFilename(idOrFilename);
    const data = await fetchJSON(`/api/post/${encodeURIComponent(id)}`);
    return data;
  }

  async function getCurrentState() {
    const data = await fetchJSON('/api/status/current');
    return data;
  }

  // 导出到 window
  window.API = {
    getPostList,
    getPostDetail,
    getCurrentState,
    formatTime,
    parseTime,
    getIdFromFilename,
    __debug: DEBUG
  };
})();