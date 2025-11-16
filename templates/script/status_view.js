/*
  文件：status_view.js
  作用：渲染单条状态详情页面
  输入：URL 参数 id
*/
document.addEventListener('DOMContentLoaded', async () => {
  const params = new URLSearchParams(location.search);
  const id = params.get('id');
  const nameEl = document.querySelector('#statusViewName');
  const timeEl = document.querySelector('#statusViewTime');
  const bodyEl = document.querySelector('#statusViewBody');
  if (!id) { bodyEl.textContent = '未指定状态'; return; }
  const rows = await window.API.getStatusHistory();
  const item = rows.find(s => window.API.getIdFromFilename(s.filename||'') === id);
  if (!item) { bodyEl.textContent = '未找到状态'; return; }
  const meta = item.meta||{};
  nameEl.textContent = meta.name||'';
  timeEl.textContent = window.API.formatTime(window.API.parseTime(meta.time||''));
  bodyEl.innerHTML = item.html || escapeHtml(item.raw||'');
});

/**
 * 功能：HTML 转义，避免 XSS
 */
function escapeHtml(str){
  return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
}