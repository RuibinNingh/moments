/*
  文件：index.js
  作用：渲染首页动态和状态混合列表（按时间排序）
  交互：点击卡片进入详情
*/
document.addEventListener('DOMContentLoaded', async () => {
  const listEl = document.querySelector('#postsList');
  const emptyEl = document.querySelector('#empty');
  const loadingEl = document.querySelector('#loading');

  try {
    // 同时加载动态、状态和当前状态
    const [posts, statuses, currentStatus] = await Promise.all([
      window.API.getPostList(),
      window.API.getStatusHistory(),
      window.API.getCurrentState()
    ]);
    
    loadingEl.style.display = 'none';
    
    // 合并并标记类型
    const allItems = [];
    if (posts && posts.length) {
      posts.forEach(p => allItems.push({type: 'post', data: p}));
    }
    if (statuses && statuses.length) {
      statuses.forEach(s => allItems.push({type: 'status', data: s}));
    }
    
    if (allItems.length === 0) {
      emptyEl.style.display = 'block';
      return;
    }
    
    // 按时间排序（最新在前）
    allItems.sort((a, b) => {
      const ta = window.API.parseTime(a.data.meta?.time||'');
      const tb = window.API.parseTime(b.data.meta?.time||'');
      return tb - ta;
    });
    
    const frag = document.createDocumentFragment();
    allItems.forEach(item => {
      if (item.type === 'post') {
        frag.appendChild(renderPostCard(item.data, currentStatus));
      } else {
        frag.appendChild(renderStatusCard(item.data));
      }
    });
    listEl.appendChild(frag);
  } catch (err) {
    console.error('加载列表失败', err);
    loadingEl.style.display = 'none';
    emptyEl.style.display = 'block';
  }
});

/**
 * 功能：渲染单条动态卡片
 * 输入：post 对象, currentStatus 当前状态
 * 返回：DOM 元素
 */
function renderPostCard(post, currentStatus) {
  const card = document.createElement('article');
  card.className = 'card glass breathe post-card';
  const time = window.API.formatTime(window.API.parseTime(post.meta?.time||''));
  let tags = post.meta?.tags || [];

  // 如果有 "微信"，就移除它，只用显示 "来自微信朋友圈" 徽章
  let sourceBadge = '';
  if (tags.includes('微信')) {
    sourceBadge = `<span class="tag tag-source">来自微信朋友圈</span>`;
    tags = tags.filter(t => t !== '微信');
  }

  // avatar 由 Flask 传入 window.avatar，支持绝对 URL、绝对路径或文件名
  const avatarSrc = resolveAvatar(window.avatar);
  const nickname = window.nickname || '我';

  // 当前状态图标
  let statusIconHtml = '';
  if (currentStatus && currentStatus.meta) {
    const icon = currentStatus.meta.icon || '';
    if (icon) {
      // 将状态数据存储在 data 属性中，使用单引号包裹，JSON 使用双引号，避免冲突
      const statusJson = JSON.stringify(currentStatus).replace(/'/g, '&#39;');
      statusIconHtml = `<span class="status-icon-btn" data-status='${statusJson}'>${escapeHtml(icon)}</span>`;
    }
  }

  const firstImg = extractFirstImage(post.html||'');
  card.innerHTML = `
    <div class="card-header">
      <div class="avatar"><img src="${avatarSrc}" alt="avatar" loading="lazy" decoding="async" onerror="this.onerror=null;this.src='/upload/default.png'"/></div>
      <div class="card-header-content">
        <div class="card-header-top">
          <span class="nickname">${escapeHtml(nickname)}</span>
          ${statusIconHtml}
        </div>
        <div class="tags">${sourceBadge}${tags.map(t=>`<span class='tag'>${escapeHtml(t)}</span>`).join('')}</div>
      </div>
    </div>
    ${firstImg ? `<img class="preview-img" src="${escapeHtml(firstImg)}" alt="" loading="lazy" decoding="async"/>` : ''}
    <div class="content">${post.html || escapeHtml(post.raw||'')}</div>
    <div class="card-time">${time}</div>
  `;

  // 点击卡片进入详情
  card.addEventListener('click', (e) => {
    // 如果点击的是状态图标，不跳转
    if (e.target.closest('.status-icon-btn')) {
      e.stopPropagation();
      return;
    }
    const id = window.API.getIdFromFilename(post.filename||'');
    location.href = `post?id=${encodeURIComponent(id)}`;
  });

  // 状态图标点击事件
  const statusIconBtn = card.querySelector('.status-icon-btn');
  if (statusIconBtn) {
    statusIconBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      try {
        const statusJson = statusIconBtn.getAttribute('data-status');
        const statusData = JSON.parse(statusJson);
        showStatusPopup(statusData);
      } catch (err) {
        console.error('解析状态数据失败', err);
      }
    });
  }

  return card;
}

/**
 * 功能：渲染单条状态卡片
 * 输入：status 对象
 * 返回：DOM 元素
 */
function renderStatusCard(status) {
  const card = document.createElement('article');
  card.className = 'card glass breathe status-card';
  const time = window.API.formatTime(window.API.parseTime(status.meta?.time||''));
  const avatarSrc = resolveAvatar(window.avatar);
  const nickname = window.nickname || '我';
  const name = status.meta?.name || '';
  const icon = status.meta?.icon || '';
  
  card.innerHTML = `
    <div class="card-header status-card-header">
      <div class="avatar"><img src="${avatarSrc}" alt="avatar" loading="lazy" decoding="async" onerror="this.onerror=null;this.src='/upload/default.png'"/></div>
      <div class="status-card-content">
        <div class="status-card-text">
          <span class="nickname">${escapeHtml(nickname)}</span>
          <span class="status-text">设置了状态</span>
          ${icon ? `<span class="status-icon">${escapeHtml(icon)}</span>` : ''}
          ${name ? `<span class="status-name">${escapeHtml(name)}</span>` : ''}
        </div>
        <div class="card-time">${time}</div>
      </div>
    </div>
  `;
  
  card.addEventListener('click', () => {
    const id = window.API.getIdFromFilename(status.filename||'');
    location.href = `status/view?id=${encodeURIComponent(id)}`;
  });

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

/**
 * 功能：抽取内容中的第一张图片 URL
 */
function extractFirstImage(html) {
  const d = document.createElement('div');
  d.innerHTML = html; const img = d.querySelector('img');
  return img ? img.getAttribute('src') : '';
}
function resolveAvatar(src){
  const s = String(src||'').trim();
  if (!s) return '/upload/default.png';
  if (/^https?:\/\//i.test(s)) return s;
  if (s.startsWith('/')) return s;
  return `/upload/${s}`;
}

/**
 * 功能：显示状态详情浮窗
 * 输入：status 对象
 */
function showStatusPopup(status) {
  // 移除已存在的浮窗
  const existing = document.querySelector('.status-popup');
  if (existing) existing.remove();

  const popup = document.createElement('div');
  popup.className = 'status-popup';
  
  const meta = status.meta || {};
  const time = window.API.formatTime(window.API.parseTime(meta.time||''));
  const name = meta.name || '';
  const icon = meta.icon || '';
  const background = meta.background || '';
  
  popup.innerHTML = `
    <div class="status-popup-backdrop"></div>
    <div class="status-popup-content">
      <div class="status-popup-header">
        <div class="status-popup-icon-name">
          ${icon ? `<span class="status-popup-icon">${escapeHtml(icon)}</span>` : ''}
          ${name ? `<span class="status-popup-name">${escapeHtml(name)}</span>` : ''}
        </div>
        <button class="status-popup-close" aria-label="关闭">×</button>
      </div>
      ${background ? `<div class="status-popup-bg" style="background-image: url('${escapeHtml(background)}');"></div>` : ''}
      <div class="status-popup-body">${status.html || escapeHtml(status.raw||'')}</div>
      <div class="status-popup-time">${time}</div>
    </div>
  `;
  
  document.body.appendChild(popup);
  
  // 关闭事件
  const close = () => popup.remove();
  popup.querySelector('.status-popup-close').addEventListener('click', close);
  popup.querySelector('.status-popup-backdrop').addEventListener('click', close);
  
  // ESC 键关闭
  const escHandler = (e) => {
    if (e.key === 'Escape') {
      close();
      document.removeEventListener('keydown', escHandler);
    }
  };
  document.addEventListener('keydown', escHandler);
}