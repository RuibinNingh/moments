document.addEventListener('DOMContentLoaded', async () => {
  await renderCurrent();
});

async function renderCurrent() {
  const box = document.querySelector('#stateHero');
  const nameEl = document.querySelector('#stateName');
  const timeEl = document.querySelector('#stateTime');
  const contentEl = document.querySelector('#stateContent');

  const s = await window.API.getCurrentState();
  if (!s || s.error) {
    nameEl.textContent = '未设置';
    timeEl.textContent = '';
    contentEl.textContent = '无法获取当前状态，请检查后端服务。';
    return;
  }
  const meta = s.meta || {};
  nameEl.textContent = meta.name || '未设置';
  timeEl.textContent = window.API.formatTime(window.API.parseTime(meta.time||''));
  contentEl.innerHTML = s.html || escapeHtml(s.raw||'');
  const bg = box.querySelector('.bg');
  if (meta.background) bg.style.backgroundImage = `url(${meta.background})`;
}

// 移除历史搜索功能，按最新规范仅展示当前状态

// 无历史列表渲染

function escapeHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/'/g,'&#39;');
}