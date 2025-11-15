// 简易 API 封装：直接请求后端 server.py 暴露的接口
(function () {
  const BASE_URL = '';
  const DEBUG = { last: {}, lastError: null };

  async function fetchJSON(path) {
    const url = BASE_URL + path;
    try {
      const res = await fetch(url, {
        headers: { 'Accept': 'application/json' },
        credentials: 'same-origin'
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      DEBUG.last[path] = { status: res.status, ok: res.ok, url, data: json };
      return json;
    } catch (err) {
      DEBUG.lastError = { path, url, error: err?.message || String(err), stack: err?.stack };
      console.error(`[API] 请求失败: ${path}`, DEBUG.lastError);
      return null;
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