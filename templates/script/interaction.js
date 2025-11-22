/*
  文件：interaction.js
  作用：在交互期间添加 body.interacting 类以启用动效
  细节：防抖 2.5s 自动关闭，监听常见交互事件
*/
document.addEventListener('DOMContentLoaded', async () => {
  let timer = null;
  const body = document.body;
  function activate() {
    if (!body.classList.contains('interacting')) body.classList.add('interacting');
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => { body.classList.remove('interacting'); }, 2500);
  }
  const evs = ['pointermove','pointerdown','touchstart','keydown','focusin'];
  evs.forEach(e => window.addEventListener(e, activate, { passive: true }));

  try {
    const cfg = await (window.API && window.API.getFrontendConfig ? window.API.getFrontendConfig() : Promise.resolve({background:'image'}));
    if (cfg && cfg.background === 'dynamic-halo') initHaloBackground();
  } catch {}

  function initHaloBackground(){
    if (document.getElementById('bg-halo')) return;
    body.classList.add('bg-halo');
    const canvas = document.createElement('canvas');
    canvas.id = 'bg-halo';
    canvas.style.position = 'fixed';
    canvas.style.inset = '0';
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.pointerEvents = 'none';
    canvas.style.zIndex = '-2';
    document.body.appendChild(canvas);

    const ctx = canvas.getContext('2d');
    let W = window.innerWidth; let H = window.innerHeight;
    canvas.width = W; canvas.height = H;
    window.addEventListener('resize', () => { W = window.innerWidth; H = window.innerHeight; canvas.width = W; canvas.height = H; initBlobs(); });
    const blobCount = 20;
    const blobs = [];
    function random(min, max) { return Math.random() * (max - min) + min; }
    function initBlobs(){
      blobs.length = 0;
      for(let i=0;i<blobCount;i++){
        const radius = random(40, 70);
        const angle = random(0, Math.PI*2);
        const speed = random(0.001, 0.003);
        const orbitX = W/2 + random(-100,100);
        const orbitY = H/2 + random(-50,50);
        const orbitRX = random(200, 400);
        const orbitRY = random(150, 300);
        const color = `hsla(${random(0,360)}, 80%, 60%, 0.3)`;
        blobs.push({radius, angle, speed, orbitX, orbitY, orbitRX, orbitRY, color});
      }
    }
    initBlobs();
    function draw(){
      ctx.clearRect(0,0,W,H);
      for(const b of blobs){
        const x = b.orbitX + b.orbitRX * Math.cos(b.angle);
        const y = b.orbitY + b.orbitRY * Math.sin(b.angle);
        const grad = ctx.createRadialGradient(x, y, 0, x, y, b.radius);
        grad.addColorStop(0, b.color);
        grad.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(x, y, b.radius, 0, Math.PI*2);
        ctx.fill();
        b.angle += b.speed;
      }
      requestAnimationFrame(draw);
    }
    draw();
  }
});