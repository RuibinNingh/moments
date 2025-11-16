/*
  文件：search_input.js
  作用：绑定搜索框回车跳转到 /search
  兼容：中文输入法的组合键处理
*/
document.addEventListener('DOMContentLoaded', () => {
  const input = document.querySelector('#searchInput');
  if (!input) return;
  let composing = false;
  function go(){ const q = String(input.value||'').trim(); if (!q) return; location.href = `/search?q=${encodeURIComponent(q)}`; }
  input.addEventListener('compositionstart', () => { composing = true; });
  input.addEventListener('compositionend', () => { composing = false; });
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !composing) { e.preventDefault(); go(); } });
});