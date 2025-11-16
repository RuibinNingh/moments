/*
  文件：search.js
  作用：已废弃的实时搜索建议（保留以兼容旧引入）
  状态：当前页面未引用，仅作备份
*/
const Search = (() => {
  const input = () => document.querySelector('#searchInput');
  const box = () => document.querySelector('#searchSuggest');
  let cache = null; let timer = null; let composing = false;

  async function ensureCache() {
    if (cache) return cache;
    const posts = await window.API.getPostList();
    const statuses = await window.API.getStatusHistory();
    cache = [
      ...posts.map(p => ({
        type: 'post',
        id: window.API.getIdFromFilename(p.filename||''),
        time: p.meta?.time||'',
        tags: p.meta?.tags||[],
        text: stripHtml(p.html||p.raw||''),
      })),
      ...statuses.map(s => ({
        type: 'status',
        id: window.API.getIdFromFilename(s.filename||''),
        time: s.meta?.time||'',
        tags: [],
        name: s.meta?.name||'',
        text: stripHtml(s.html||s.raw||''),
      }))
    ];
    return cache;
  }

  /**
   * 功能：移除 HTML 标签，返回纯文本
   */
  function stripHtml(html) {
    const d = document.createElement('div');
    d.innerHTML = html; return d.textContent || d.innerText || '';
  }

  /**
   * 功能：解析时间字符串为 Date
   */
  function parseTime(t){ return window.API.parseTime(t||''); }

  /**
   * 功能：计算相关性分值
   * 输入：查询 q 与候选项 item
   * 返回：分值（越大越相关）
   */
  function score(q, item) {
    if (!q) return 0;
    const s = q.trim();
    const hay = `${item.name||''} ${item.tags.join(' ')} ${item.text}`.toLowerCase();
    let sc = 0;
    const isRegex = /^\s*\/.+\/[a-zA-Z0-9]*\s*$/.test(s);
    if (isRegex) {
      try {
        const m = s.match(/^\s*\/(.+)\/([a-zA-Z0-9]*)\s*$/);
        const re = new RegExp(m[1], (m[2]||'i').replace(/[^a-zA-Z]/g,''));
        if (re.test(hay)) sc += 90;
      } catch {}
    } else {
      const ql = s.toLowerCase();
      const smallAscii = ql.length < 2 && /^[\x00-\x7F]+$/.test(ql);
      if (item.tags.some(t => t.toLowerCase() === ql)) sc += 120;
      if ((item.name||'').toLowerCase().startsWith(ql)) sc += 90;
      if (!smallAscii) {
        if ((item.name||'').toLowerCase().includes(ql)) sc += 70;
        if (hay.includes(ql)) sc += 60;
      }
    }
    const ageDays = Math.max(0, (Date.now() - parseTime(item.time)) / 86400000);
    sc += Math.max(0, 20 - ageDays);
    return sc;
  }

  /**
   * 功能：渲染建议条
   */
  function render(items, q) {
    const el = box(); if (!el) return;
    el.innerHTML = '';
    if (!items || items.length === 0 || !q) { el.style.display = 'none'; return; }
    const frag = document.createDocumentFragment();
    items.slice(0,8).forEach(it => {
      const row = document.createElement('div');
      row.className = 'search-row';
      const time = window.API.formatTime(parseTime(it.time));
      const source = it.type === 'post' ? '动态' : '状态';
      const tagHtml = it.tags.map(t=>`<span class="tag">${escapeHtml(t)}</span>`).join('');
      const titleRaw = (it.name||it.text).slice(0,120);
      const title = highlight(titleRaw, q);
      const snippet = makeSnippet(it.text, q, 100);
      row.innerHTML = `
        <div class="search-row-left">
          <span class="search-row-title">${title}</span>
          <span class="search-row-meta">${time}</span>
        </div>
        <div class="search-row-right">
          <span class="tag tag-source">${source}</span>${tagHtml}
        </div>
        <div class="search-row-snippet">${snippet}</div>
      `;
      row.addEventListener('mousedown', (e) => { e.preventDefault(); e.stopPropagation(); });
      row.addEventListener('click', (e) => {
        e.stopPropagation();
        if (it.type === 'post') location.href = `post?id=${encodeURIComponent(it.id)}`;
        else location.href = `status/view?id=${encodeURIComponent(it.id)}`;
      });
      frag.appendChild(row);
    });
    el.appendChild(frag);
    el.style.display = 'block';
  }

  /**
   * 功能：HTML 转义
   */
  function escapeHtml(str){
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  /**
   * 功能：计算最小分值阈值（按查询类型）
   */
  function minScore(q){
    const s = (q||'').trim();
    const isRegex = /^\s*\/.+\/[a-zA-Z0-9]*\s*$/.test(s);
    if (isRegex) return 60;
    const smallAscii = s.length < 2 && /^[\x00-\x7F]+$/.test(s);
    return smallAscii ? 80 : 40;
  }

  /**
   * 功能：输入事件处理（防抖 + 排序过滤）
   */
  async function onInput(q){
    const list = await ensureCache();
    const threshold = minScore(q);
    const ranked = list.map(it => ({it, sc: score(q, it)})).filter(x=>x.sc>=threshold).sort((a,b)=>b.sc-a.sc || (parseTime(b.it.time)-parseTime(a.it.time))).map(x=>x.it);
    render(ranked, q);
  }

  /**
   * 功能：绑定输入与建议层交互
   */
  function bind(){
    const el = input(); const suggest = box(); if (!el || !suggest) return;
    el.addEventListener('compositionstart', () => { composing = true; });
    el.addEventListener('compositionend', () => { composing = false; onInput(el.value); });
    el.addEventListener('input', () => { if (composing) return; clearTimeout(timer); timer = setTimeout(()=>onInput(el.value), 150); });
    document.addEventListener('click', e => { if (!suggest.contains(e.target) && e.target !== el) suggest.style.display = 'none'; });
  }

  return { bind };
})();

document.addEventListener('DOMContentLoaded', () => { Search.bind(); });

function highlight(text, q){
  const safe = escapeHtml(String(text||''));
  const s = (q||'').trim();
  if (!s) return safe;
  const isRegex = /^\s*\/.+\/[a-zA-Z0-9]*\s*$/.test(s);
  if (isRegex) {
    try {
      const m = s.match(/^\s*\/(.+)\/([a-zA-Z0-9]*)\s*$/);
      const re = new RegExp(m[1], (m[2]||'i') + 'g');
      return safe.replace(re, (x) => `<mark class="hl">${x}</mark>`);
    } catch { return safe; }
  }
  const re = new RegExp(s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig');
  return safe.replace(re, (x) => `<mark class="hl">${x}</mark>`);
}

function makeSnippet(text, q, len){
  const s = String(text||'');
  const safe = escapeHtml(s);
  const plain = s;
  const qStr = (q||'').trim();
  if (!qStr) return safe.slice(0,len);
  const isRegex = /^\s*\/.+\/[a-zA-Z0-9]*\s*$/.test(qStr);
  let idx = -1;
  if (isRegex) {
    try {
      const m = qStr.match(/^\s*\/(.+)\/([a-zA-Z0-9]*)\s*$/);
      const re = new RegExp(m[1], m[2]||'i');
      const mm = plain.match(re);
      if (mm) idx = plain.indexOf(mm[0]);
    } catch { idx = -1; }
  } else {
    idx = plain.toLowerCase().indexOf(qStr.toLowerCase());
  }
  let base = safe;
  if (idx >= 0) {
    const start = Math.max(0, idx - Math.floor(len/2));
    const end = Math.min(safe.length, start + len);
    base = safe.slice(start, end);
  } else {
    base = safe.slice(0, len);
  }
  return highlight(base, qStr);
}