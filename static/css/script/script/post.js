document.addEventListener('DOMContentLoaded', async () => {
  const params = new URLSearchParams(location.search);
  const id = params.get('id') || params.get('file'); // 兼容旧参数
  const timeEl = document.querySelector('#postTime');
  const tagsEl = document.querySelector('#postTags');
  const bodyEl = document.querySelector('#postBody');

  if (!id) {
    bodyEl.textContent = '未指定内容参数。';
    return;
  }

  const data = await window.API.getPostDetail(id);
  const time = data.meta?.time || '';
  const tags = data.meta?.tags || [];
  timeEl.textContent = window.API.formatTime(window.API.parseTime(time));
  const sourceBadge = tags.includes('微信') ? `<span class='tag tag-source'>来自微信朋友圈</span>` : '';
  tagsEl.innerHTML = sourceBadge + tags.map(t=>`<span class='tag'>${escapeHtml(t)}</span>`).join('');
  bodyEl.innerHTML = data.html || escapeHtml(data.raw||'');
});

function escapeHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/'/g,'&#39;');
}