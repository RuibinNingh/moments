/*
  文件：status.js
  作用：渲染当前状态与历史列表
  交互：点击历史卡片可进入详情（同页面展示摘要）
*/
document.addEventListener('DOMContentLoaded', async () => {
  await renderCurrent();
  await renderHistory();
});

/**
 * 功能：渲染当前状态区块
 */
async function renderCurrent() {
  const box = document.querySelector('#stateHero');
  const nameEl = document.querySelector('#stateName');
  const timeEl = document.querySelector('#stateTime');
  const contentEl = document.querySelector('#stateContent');

  const s = await window.API.getCurrentState();
  if (!s) { box.style.display = 'none'; return; }
  const meta = s.meta || {};
  nameEl.textContent = meta.name || '未设置';
  timeEl.textContent = window.API.formatTime(window.API.parseTime(meta.time||''));
  contentEl.innerHTML = s.html || escapeHtml(s.raw||'');
  const bg = box.querySelector('.bg');
  if (meta.background) bg.style.backgroundImage = `url(${meta.background})`;
}

/**
 * 功能：渲染历史状态列表（排除当前）
 */
async function renderHistory() {
  const listEl = document.querySelector('#statusHistory');
  if (!listEl) return;
  const current = await window.API.getCurrentState();
  let rows = await window.API.getStatusHistory();
  if (current && Array.isArray(rows)) {
    rows = rows.filter(s => s.filename !== current.filename);
  }
  if (!rows || rows.length === 0) { listEl.style.display = 'none'; return; }
  const frag = document.createDocumentFragment();
  rows.forEach(s => frag.appendChild(renderStatusCard(s)));
  listEl.appendChild(frag);
}

/**
 * 功能：渲染单条历史状态卡片
 * 输入：状态对象
 * 返回：DOM 元素
 */
function renderStatusCard(s) {
  const card = document.createElement('article');
  card.className = 'card glass breathe';
  const time = window.API.formatTime(window.API.parseTime(s.meta?.time||''));
  const name = s.meta?.name || '';
  const body = stripHtml(s.html||s.raw||'');
  card.innerHTML = `
    <div class="card-header">
      <div>
        <div class="meta"><span class="time">${time}</span></div>
        <div class="tags"><span class='tag'>${escapeHtml(name)}</span></div>
      </div>
    </div>
    <div class="content ellipsis-2">${escapeHtml(body)}</div>
  `;
  return card;
}

/**
 * 功能：移除 HTML 标签，返回纯文本
 */
function stripHtml(html) {
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return tmp.textContent || tmp.innerText || '';
}

// 移除历史搜索功能，按最新规范仅展示当前状态

// 无历史列表渲染

/**
 * 功能：HTML 转义，避免 XSS
 */
function escapeHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/'/g,'&#39;');
}