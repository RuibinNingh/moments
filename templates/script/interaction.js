/*
  文件：interaction.js
  作用：在交互期间添加 body.interacting 类以启用动效
  细节：防抖 2.5s 自动关闭，监听常见交互事件
*/
document.addEventListener('DOMContentLoaded', () => {
  let timer = null;
  const body = document.body;
  function activate() {
    if (!body.classList.contains('interacting')) body.classList.add('interacting');
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => { body.classList.remove('interacting'); }, 2500);
  }
  const evs = ['pointermove','pointerdown','touchstart','keydown','focusin'];
  evs.forEach(e => window.addEventListener(e, activate, { passive: true }));
});