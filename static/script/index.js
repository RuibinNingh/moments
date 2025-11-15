document.addEventListener('DOMContentLoaded', async () => {
  const listEl = document.querySelector('#postsList');
  const emptyEl = document.querySelector('#empty');
  const loadingEl = document.querySelector('#loading');

  try {
    const posts = await window.API.getPostList();
    loadingEl.style.display = 'none';
    if (!posts || posts.length === 0) {
      emptyEl.textContent = '暂时没有内容或接口未返回数据';
      emptyEl.style.display = 'block';
      // 输出详细调试信息到控制台
      console.error('列表为空或接口未返回数据', {
        lastResponse: window.API.__debug?.last['/api/posts'] || null,
        lastError: window.API.__debug?.lastError || null
      });
      return;
    }
    const frag = document.createDocumentFragment();
    posts.forEach(p => frag.appendChild(renderCard(p)));
    listEl.appendChild(frag);
  } catch (err) {
    console.error('加载列表失败', err);
    loadingEl.style.display = 'none';
    emptyEl.textContent = '加载失败，请检查后端服务是否已启动';
    emptyEl.style.display = 'block';
    // 同步打印最近一次响应与错误细节
    console.error('调试信息', {
      lastResponse: window.API.__debug?.last['/api/posts'] || null,
      lastError: window.API.__debug?.lastError || null
    });
  }
});

function renderCard(post) {
  const card = document.createElement('article');
  card.className = 'card glass breathe';
  const time = window.API.formatTime(window.API.parseTime(post.meta?.time||''));
  const tags = post.meta?.tags || [];
  const sourceBadge = tags.includes('微信') ? `<span class="tag tag-source">来自微信朋友圈</span>` : '';
  card.innerHTML = `
    <div class="card-header">
      <div class="avatar" aria-hidden="true"></div>
      <div>
        <div class="meta">
          <span class="time">${time}</span>
        </div>
        <div class="tags">${sourceBadge}${tags.map(t=>`<span class='tag'>${escapeHtml(t)}</span>`).join('')}</div>
      </div>
    </div>
    <div class="content ellipsis-2">${escapeHtml(stripHtml(post.html||''))}</div>
  `;
  card.addEventListener('click', () => {
    const id = window.API.getIdFromFilename(post.filename||'');
    location.href = `post.html?id=${encodeURIComponent(id)}`;
  });
  return card;
}

function stripHtml(html) {
  const tmp = document.createElement('div');
  tmp.innerHTML = html;
  return tmp.textContent || tmp.innerText || '';
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g,'&amp;')
    .replace(/</g,'&lt;')
    .replace(/>/g,'&gt;')
    .replace(/"/g,'&quot;')
    .replace(/'/g,'&#39;');
}