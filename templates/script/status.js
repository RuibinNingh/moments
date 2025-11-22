/*
  文件：status.js
  作用：渲染状态列表，支持列表视图和日历视图切换
  交互：点击状态卡片可进入详情
*/
document.addEventListener('DOMContentLoaded', async () => {
  let isCalendarView = false;
  const statusListEl = document.querySelector('#statusList');
  const calendarViewEl = document.querySelector('#calendarView');
  const toggleBtn = document.querySelector('#toggleView');
  const viewIcon = document.querySelector('#viewIcon');
  const viewText = document.querySelector('#viewText');
  
  // 视图切换
  toggleBtn.addEventListener('click', () => {
    isCalendarView = !isCalendarView;
    if (isCalendarView) {
      statusListEl.style.display = 'none';
      calendarViewEl.style.display = 'block';
      viewIcon.textContent = '📋';
      viewText.textContent = '列表视图';
      initCalendar();
    } else {
      statusListEl.style.display = 'block';
      calendarViewEl.style.display = 'none';
      viewIcon.textContent = '📅';
      viewText.textContent = '日历视图';
    }
  });
  
  // 初始加载列表视图
  await renderStatusList();
});

/**
 * 功能：渲染状态列表
 */
async function renderStatusList() {
  const listEl = document.querySelector('#statusList');
  if (!listEl) return;
  
  const statuses = await window.API.getStatusHistory();
  if (!statuses || statuses.length === 0) {
    listEl.innerHTML = '<section class="card glass breathe" style="text-align:center; padding:32px;">还没有状态记录</section>';
    return;
  }
  
  const frag = document.createDocumentFragment();
  statuses.forEach(s => frag.appendChild(renderStatusCard(s)));
  listEl.innerHTML = '';
  listEl.appendChild(frag);
}

/**
 * 功能：渲染单条状态卡片
 * 输入：状态对象
 * 返回：DOM 元素
 */
function renderStatusCard(s) {
  const card = document.createElement('article');
  card.className = 'card glass breathe';
  const time = window.API.formatTime(window.API.parseTime(s.meta?.time||''));
  const name = s.meta?.name || '';
  const icon = s.meta?.icon || '';
  const avatarSrc = resolveAvatar(window.avatar);
  
  card.innerHTML = `
    <div class="card-header">
      <div class="avatar"><img src="${avatarSrc}" alt="avatar" loading="lazy" decoding="async" onerror="this.onerror=null;this.src='/upload/default.png'"/></div>
      <div>
        <div class="meta"><span class="time">${time}</span></div>
        <div class="tags">${icon ? `<span class='tag'>${escapeHtml(icon)}</span>` : ''}${name ? `<span class='tag'>${escapeHtml(name)}</span>` : ''}<span class='tag tag-source'>状态</span></div>
      </div>
    </div>
    <div class="content">${s.html || escapeHtml(s.raw||'')}</div>
  `;
  
  card.addEventListener('click', () => {
    const id = window.API.getIdFromFilename(s.filename||'');
    location.href = `status/view?id=${encodeURIComponent(id)}`;
  });
  
  return card;
}

/**
 * 功能：初始化日历视图
 */
let calendarInitialized = false;
function initCalendar() {
  if (calendarInitialized) return;
  calendarInitialized = true;
  
  const grid = document.querySelector('#calendarGrid');
  const monthLabel = document.querySelector('#monthLabel');
  const dayLabel = document.querySelector('#dayLabel');
  const dayList = document.querySelector('#dayList');
  const dayEmpty = document.querySelector('#dayEmpty');
  const prevBtn = document.querySelector('#prevMonth');
  const nextBtn = document.querySelector('#nextMonth');

  function currentDateStrUTC8(){
    const now = new Date();
    const t = now.getTime() + (8*60 - now.getTimezoneOffset())*60000;
    const d = new Date(t);
    const y = d.getUTCFullYear(); const M = String(d.getUTCMonth()+1).padStart(2,'0'); const D = String(d.getUTCDate()).padStart(2,'0');
    return `${y}-${M}-${D}`;
  }
  let todayStr = currentDateStrUTC8();
  let cursor = new Date();
  let selectedDateStr = todayStr;
  
  // 加载所有状态，用于日历标记
  let allStatuses = [];
  let statusDaysMap = new Map();
  
  async function loadStatuses() {
    allStatuses = await window.API.getStatusHistory();
    statusDaysMap.clear();
    allStatuses.forEach(s => { 
      const d = (s.meta?.time||'').slice(0,10); 
      if (d) {
        const icon = s.meta?.icon || '';
        if (!statusDaysMap.has(d) || icon) {
          statusDaysMap.set(d, icon);
        }
      }
    });
  }

  function daysInMonth(y,m){ return new Date(y, m+1, 0).getDate(); }
  function startWeekday(y,m){ return new Date(y, m, 1).getDay(); }
  function fmtDate(d){ const y=d.getFullYear(); const M=String(d.getMonth()+1).padStart(2,'0'); const D=String(d.getDate()).padStart(2,'0'); return `${y}-${M}-${D}`; }

  async function renderDayPanel(dateStr){
    dayLabel.textContent = dateStr;
    const statuses = await window.API.getStatusesByDate(dateStr);
    dayList.innerHTML = '';
    
    if (!statuses || statuses.length === 0) {
      dayEmpty.style.display = 'block';
      return;
    }
    
    dayEmpty.style.display = 'none';
    const frag = document.createDocumentFragment();
    statuses.sort((a, b) => {
      const ta = window.API.parseTime(a.meta?.time||'');
      const tb = window.API.parseTime(b.meta?.time||'');
      return tb - ta;
    }).forEach(s => {
      frag.appendChild(renderStatusRow(s));
    });
    dayList.appendChild(frag);
  }

  function renderStatusRow(s){
    const card = document.createElement('article');
    card.className = 'card glass calendar-post-card breathe';
    const time = window.API.formatTime(window.API.parseTime(s.meta?.time||''));
    const avatarSrc = resolveAvatar(window.avatar);
    const name = s.meta?.name || '';
    const icon = s.meta?.icon || '';
    card.innerHTML = `
      <div class="card-header">
        <div class="avatar"><img src="${avatarSrc}" alt="avatar" loading="lazy" decoding="async" onerror="this.onerror=null;this.src='/upload/default.png'"/></div>
        <div>
          <div class="meta"><span class="time">${time}</span></div>
          <div class="tags">${icon ? `<span class='tag'>${escapeHtml(icon)}</span>` : ''}${name ? `<span class='tag'>${escapeHtml(name)}</span>` : ''}<span class='tag tag-source'>状态</span></div>
        </div>
      </div>
      <div class="content">${s.html || escapeHtml(s.raw||'')}</div>
    `;
    card.addEventListener('click', () => {
      const id = window.API.getIdFromFilename(s.filename||'');
      location.href = `status/view?id=${encodeURIComponent(id)}`;
    });
    return card;
  }

  function renderGrid(dir){
    const y = cursor.getFullYear(); const m = cursor.getMonth();
    monthLabel.textContent = `${y}年${String(m+1).padStart(2,'0')}月`;
    const first = startWeekday(y,m);
    const total = daysInMonth(y,m);
    const prevTotal = daysInMonth(y, m-1);
    const cells = [];
    for (let i=0;i<first;i++){ const d = prevTotal-first+i+1; cells.push({ num:d, other:true, date:new Date(y,m-1,d)}); }
    for (let d=1; d<=total; d++){ cells.push({ num:d, other:false, date:new Date(y,m,d)}); }
    const tail = 42 - cells.length; for (let i=1;i<=tail;i++){ cells.push({ num:i, other:true, date:new Date(y,m+1,i)}); }

    grid.innerHTML = '';
    const frag = document.createDocumentFragment();
    cells.forEach(c => {
      const cell = document.createElement('div');
      cell.className = 'day-cell' + (c.other ? ' other' : '');
      const dateStr = fmtDate(c.date);
      const statusIcon = statusDaysMap.get(dateStr);
      
      if (statusIcon) {
        const iconEl = document.createElement('div');
        iconEl.className = 'day-icon day-icon-status';
        iconEl.textContent = statusIcon;
        cell.appendChild(iconEl);
      }
      
      const num = document.createElement('div');
      num.className = 'day-num';
      num.textContent = String(c.num);
      cell.appendChild(num);
      
      if (fmtDate(c.date) === todayStr) cell.classList.add('today');
      if (fmtDate(c.date) === selectedDateStr) cell.classList.add('selected');
      cell.addEventListener('click', async () => {
        const ds = fmtDate(c.date);
        selectedDateStr = ds;
        await renderDayPanel(ds);
        renderGrid();
      });
      frag.appendChild(cell);
    });
    grid.appendChild(frag);
    if (dir==='left') { grid.classList.remove('slide-right'); grid.classList.add('slide-left'); setTimeout(()=>grid.classList.remove('slide-left'), 240); }
    else if (dir==='right') { grid.classList.remove('slide-left'); grid.classList.add('slide-right'); setTimeout(()=>grid.classList.remove('slide-right'), 240); }
  }

  prevBtn.addEventListener('click', () => { cursor.setMonth(cursor.getMonth()-1); renderGrid('right'); });
  nextBtn.addEventListener('click', () => { cursor.setMonth(cursor.getMonth()+1); renderGrid('left'); });

  // 初始化
  loadStatuses().then(() => {
    renderDayPanel(selectedDateStr);
    renderGrid();
  });
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

function resolveAvatar(src){
  const s = String(src||'').trim();
  if (!s) return '/upload/default.png';
  if (/^https?:\/\//i.test(s)) return s;
  if (s.startsWith('/')) return s;
  return `/upload/${s}`;
}
