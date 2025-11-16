/*
  文件：search_page.js
  作用：搜索页请求后端并渲染结果列表
  输入：URL 参数 q
*/
document.addEventListener('DOMContentLoaded', async () => {
  const params = new URLSearchParams(location.search);
  const q = params.get('q') || '';
  const infoEl = document.querySelector('#searchInfo');
  const listEl = document.querySelector('#searchResults');
  infoEl.textContent = q ? `正在搜索：${q}` : '请输入关键词进行搜索';
  if (!q) return;
  const res = await window.API.searchAll(q);
  const items = Array.isArray(res?.items) ? res.items : [];
  infoEl.textContent = `共 ${items.length} 条匹配：${q}`;
  const frag = document.createDocumentFragment();
  items.forEach(it => frag.appendChild(renderRow(it, q)));
  listEl.appendChild(frag);
});

/**
 * 功能：渲染单条搜索结果卡片
 */
function renderRow(it, q){
  const card = document.createElement('article');
  card.className = 'card glass breathe';
  const time = window.API.formatTime(window.API.parseTime(it.meta?.time||''));
  const source = it.type === 'post' ? '动态' : '状态';
  const tags = it.meta?.tags || [];
  const name = it.meta?.name || '';
  const titleRaw = name || stripHtml(it.html||it.raw||'').slice(0,120);
  const title = highlight(titleRaw, q);
  const snippet = makeSnippet(stripHtml(it.html||it.raw||''), q, 140);
  card.innerHTML = `
    <div class="card-header">
      <div>
        <div class="meta"><span class="time">${time}</span></div>
        <div class="tags"><span class="tag tag-source">${source}</span>${tags.map(t=>`<span class='tag'>${escapeHtml(t)}</span>`).join('')}</div>
      </div>
    </div>
    <div class="content">${title}</div>
    <div class="search-row-snippet">${snippet}</div>
  `;
  card.addEventListener('click', () => {
    const id = window.API.getIdFromFilename(it.filename||'');
    if (it.type === 'post') location.href = `post?id=${encodeURIComponent(id)}`;
    else location.href = `status/view?id=${encodeURIComponent(id)}`;
  });
  return card;
}

/** 功能：移除 HTML 标签 */
function stripHtml(html){ const d = document.createElement('div'); d.innerHTML = html; return d.textContent || d.innerText || ''; }
/** 功能：HTML 转义 */
function escapeHtml(str){ return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
/** 功能：对命中文本做下划线与黄底高亮 */
function highlight(text, q){
  const safe = escapeHtml(String(text||''));
  const s = (q||'').trim();
  if (!s) return safe;
  const isRegex = /^\s*\/.+\/[a-zA-Z0-9]*\s*$/.test(s);
  if (isRegex) {
    try { const m = s.match(/^\s*\/(.+)\/([a-zA-Z0-9]*)\s*$/); const re = new RegExp(m[1], (m[2]||'i') + 'g'); return safe.replace(re, x=>`<mark class="hl">${x}</mark>`);} catch { return safe; }
  }
  const re = new RegExp(s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'ig');
  return safe.replace(re, x=>`<mark class="hl">${x}</mark>`);
}
/** 功能：生成包含命中的上下文片段 */
function makeSnippet(text, q, len){
  const s = String(text||''); const safe = escapeHtml(s); const qStr = (q||'').trim(); if (!qStr) return safe.slice(0,len);
  const isRegex = /^\s*\/.+\/[a-zA-Z0-9]*\s*$/.test(qStr);
  let idx = -1;
  if (isRegex) { try { const m = qStr.match(/^\s*\/(.+)\/([a-zA-Z0-9]*)\s*$/); const re = new RegExp(m[1], m[2]||'i'); const mm = s.match(re); if (mm) idx = s.indexOf(mm[0]); } catch { idx = -1; } }
  else { idx = s.toLowerCase().indexOf(qStr.toLowerCase()); }
  let base = safe; if (idx >= 0) { const start = Math.max(0, idx - Math.floor(len/2)); base = safe.slice(start, start+len);} else { base = safe.slice(0,len); }
  return highlight(base, qStr);
}