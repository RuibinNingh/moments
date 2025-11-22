/*
  文件：api.js
  作用：封装前端数据请求与通用工具（时间、排序、ID）
  依赖：后端接口（/api/*）
  输出：window.API 方法集合
*/
// 简易 API 封装（含降级 Mock），适配最新接口规范
(function () {
  const BASE_URL = '';
  const USE_MOCK = new URLSearchParams(location.search).has('preview');

  async function fetchJSON(path) {
    const url = BASE_URL + path;
    try {
      const res = await fetch(url, {
        headers: { 'Accept': 'application/json' },
        credentials: 'same-origin'
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (err) {
      console.warn(`[API] 请求失败: ${path}`, err);
      return null;
    }
  }

  // Mock 数据（本地预览时使用，符合新结构）
  const now = new Date();
  function daysAgo(n) { return new Date(now.getTime() - n*24*3600*1000); }
  const MOCK_POSTS = {
    count: 3,
    posts: [
      {
        meta: {
          time: daysAgo(0).toISOString().slice(0,19).replace('T',' '),
          tags: ['Coding']
        },
        html: '<p>今天继续打磨前端，加入呼吸动画与磨砂玻璃质感。</p>',
        raw: '',
        filename: '2025-11-15-2.md'
      },
      {
        meta: {
          time: daysAgo(1).toISOString().slice(0,19).replace('T',' '),
          tags: ['设计']
        },
        html: '<p>为卡片添加了层次与细节，交互更加灵动。</p>',
        raw: '',
        filename: '2025-11-14-1.md'
      },
      {
        meta: {
          time: daysAgo(3).toISOString().slice(0,19).replace('T',' '),
          tags: ['微信']
        },
        html: '<p>开始对接 API，准备上线动态展示。</p>',
        raw: '',
        filename: '2025-11-12-3.md'
      }
    ]
  };
  const MOCK_STATE = {
    filename: '2025-11-15-1.md',
    meta: {
      time: now.toISOString().slice(0,19).replace('T',' '),
      name: 'coding(自定义)',
      background: ''
    },
    raw: '',
    html: '<p>正在开发动态项目前端，优化细节与体验。</p>'
  };

  // 时间工具
  /**
   * 功能：解析时间字符串为 Date
   * 输入：YYYY-MM-DD HH:mm:ss
   * 返回：Date
   */
  function parseTime(str) { return new Date(str.replace(/-/g,'/')); }
  /**
   * 功能：格式化时间为 YYYY-MM-DD HH:mm
   * 输入：Date
   * 返回：字符串
   */
  function formatTime(d) {
    const pad = n => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /**
   * 功能：按 meta.time 倒序排序
   * 输入：列表
   * 返回：排序后的列表
   */
  function sortByTimeDesc(items) {
    return [...items].sort((a,b) => parseTime(b.meta?.time||'') - parseTime(a.meta?.time||''));
  }

  /**
   * 功能：从文件名提取 id（去除 .md）
   * 输入：如 2025-11-15-1.md
   * 返回：如 2025-11-15-1
   */
  function getIdFromFilename(filename) {
    return String(filename||'').replace(/\.md$/,'');
  }

  // API 方法（新）
  /**
   * 功能：获取动态列表（倒序去重）
   * 输入：无
   * 返回：Array<Post>
   */
  async function getPostList() {
    const data = await fetchJSON('/api/posts');
    let list = Array.isArray(data?.posts) ? data.posts : (USE_MOCK ? MOCK_POSTS.posts : []);
    const seen = new Set();
    list = list.filter(p => {
      const k = getIdFromFilename(p.filename);
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
    return sortByTimeDesc(list);
  }

  /**
   * 功能：获取单条动态详情
   * 输入：id 或 filename
   * 返回：Post
   */
  async function getPostDetail(idOrFilename) {
    const id = getIdFromFilename(idOrFilename);
    let data = await fetchJSON(`/api/post/${encodeURIComponent(id)}`);
    if (!data) data = await fetchJSON(`/api/post/${encodeURIComponent(id)}.md`);
    if (data && data.meta && data.meta.time) return data;
    // 从 mock 列表里找一条
    const item = (MOCK_POSTS.posts.find(p => getIdFromFilename(p.filename) === id) || MOCK_POSTS.posts[0]);
    return item;
  }

  /**
   * 功能：获取当前状态
   * 输入：无
   * 返回：Status | null
   */
  async function getCurrentState() {
    const data = await fetchJSON('/api/status/current');
    return data || (USE_MOCK ? MOCK_STATE : null);
  }

  /**
   * 功能：获取历史状态列表（倒序）
   * 输入：无
   * 返回：Array<Status>
   */
  async function getStatusHistory() {
    const data = await fetchJSON('/api/status/history');
    const list = Array.isArray(data?.statuses) ? data.statuses : [];
    return sortByTimeDesc(list);
  }

  /**
   * 功能：后端搜索（正则/关键词）
   * 输入：q 查询字符串
   * 返回：{ count, items }
   */
  async function searchAll(q) {
    const data = await fetchJSON(`/api/search?q=${encodeURIComponent(q||'')}`);
    return data || { count: 0, items: [] };
  }

  async function getPostsByDate(dateStr) {
    const data = await fetchJSON(`/api/post/query?date=${encodeURIComponent(dateStr||'')}`);
    const list = Array.isArray(data?.posts) ? data.posts : [];
    return sortByTimeDesc(list);
  }

  async function getStatusesByDate(dateStr) {
    const data = await fetchJSON(`/api/status/query?date=${encodeURIComponent(dateStr||'')}`);
    const list = Array.isArray(data?.statuses) ? data.statuses : [];
    return sortByTimeDesc(list);
  }

  async function getFrontendConfig() {
    const data = await fetchJSON('/api/frontend/config');
    return data || { background: 'image' };
  }

  // 导出到 window
  window.API = {
    getPostList,
    getPostDetail,
    getCurrentState,
    getStatusHistory,
    searchAll,
    getPostsByDate,
    getStatusesByDate,
    getFrontendConfig,
    formatTime,
    parseTime,
    getIdFromFilename
  };
})();
