// 三进制黑洞特效 - 全屏首页
(function() {
  // 只在首页显示
  if (window.location.pathname !== '/' && window.location.pathname !== '/index.html' && window.location.pathname !== '/index.htm') return;
  
  var canvas = document.createElement('canvas');
  canvas.id = 'blackhole-canvas';
  canvas.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:0!important;pointer-events:none!important;';
  document.body.insertBefore(canvas, document.body.firstChild);
  
  var ctx = canvas.getContext('2d');
  var time = 0;
  var width, height;
  
  function resize() {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);
  
  // 三进制数字
  var trits = [];
  for (var i = 0; i < 50; i++) {
    trits.push({
      text: Math.random() > 0.5 ? '1' : '0',
      x: Math.random() * width,
      y: Math.random() * height,
      size: 14 + Math.random() * 12,
      speed: 0.3 + Math.random() * 0.8,
      angle: Math.random() * Math.PI * 2,
      distance: 100 + Math.random() * 300,
      opacity: Math.random() * 0.6 + 0.3
    });
  }
  
  // 吸积盘粒子
  var particles = [];
  for (var i = 0; i < 200; i++) {
    var angle = Math.random() * Math.PI * 2;
    particles.push({
      size: 1 + Math.random() * 3,
      speed: 0.3 + Math.random() * 2,
      angle: angle,
      distance: 50 + Math.random() * Math.min(width, height) * 0.4,
      opacity: Math.random() * 0.6 + 0.2,
      color: Math.random() > 0.5 ? '#00ffff' : '#ff00ff'
    });
  }
  
  function draw() {
    time += 0.016;
    
    ctx.fillStyle = 'rgba(0, 0, 0, 0.15)';
    ctx.fillRect(0, 0, width, height);
    
    var centerX = width / 2;
    var centerY = height / 2;
    var scale = Math.min(width, height) / 600;
    
    // 黑洞核心
    var coreSize = 80 * scale;
    var coreGradient = ctx.createRadialGradient(centerX, centerY, 0, centerX, centerY, coreSize);
    coreGradient.addColorStop(0, '#000000');
    coreGradient.addColorStop(0.6, 'rgba(30, 0, 50, 0.9)');
    coreGradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
    
    ctx.beginPath();
    ctx.arc(centerX, centerY, coreSize, 0, Math.PI * 2);
    ctx.fillStyle = coreGradient;
    ctx.fill();
    
    // 吸积盘
    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      
      p.angle += p.speed * 0.015;
      p.distance -= 0.2;
      
      if (p.distance < 30 * scale) {
        p.distance = Math.min(width, height) * 0.45 + Math.random() * 50;
        p.angle = Math.random() * Math.PI * 2;
      }
      
      var px = centerX + Math.cos(p.angle) * p.distance;
      var py = centerY + Math.sin(p.angle) * p.distance;
      var pSize = p.size * scale;
      
      var glow = ctx.createRadialGradient(px, py, 0, px, py, pSize * 4);
      glow.addColorStop(0, p.color);
      glow.addColorStop(1, 'rgba(0, 0, 0, 0)');
      
      ctx.beginPath();
      ctx.arc(px, py, pSize * 4, 0, Math.PI * 2);
      ctx.fillStyle = glow;
      ctx.globalAlpha = p.opacity;
      ctx.fill();
      
      ctx.beginPath();
      ctx.arc(px, py, pSize, 0, Math.PI * 2);
      ctx.fillStyle = '#ffffff';
      ctx.fill();
    }
    
    ctx.globalAlpha = 1;
    
    // 三进制数字
    ctx.font = 'bold 16px monospace';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    
    for (var i = 0; i < trits.length; i++) {
      var t = trits[i];
      
      t.angle += t.speed * 0.008;
      var orbitRadius = t.distance * scale;
      
      t.x = centerX + Math.cos(t.angle) * orbitRadius;
      t.y = centerY + Math.sin(t.angle) * orbitRadius * 0.6;
      
      var distToCenter = Math.sqrt(Math.pow(t.x - centerX, 2) + Math.pow(t.y - centerY, 2));
      var alpha = Math.max(0.1, 1 - (distToCenter / (300 * scale)));
      
      if (distToCenter < 40 * scale) {
        t.distance = 200 + Math.random() * 150;
        t.angle = Math.random() * Math.PI * 2;
        t.text = Math.random() > 0.5 ? '1' : '0';
      }
      
      ctx.fillStyle = distToCenter > 150 * scale ? '#00ffff' : '#ff00ff';
      ctx.globalAlpha = alpha * 0.8;
      ctx.font = 'bold ' + (12 * scale) + 'px monospace';
      ctx.fillText(t.text, t.x, t.y);
    }
    
    ctx.globalAlpha = 1;
    
    // 外圈光环
    ctx.beginPath();
    ctx.ellipse(centerX, centerY, 280 * scale, 100 * scale, Math.PI / 6, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(100, 0, 150, 0.15)';
    ctx.lineWidth = 2 * scale;
    ctx.stroke();
    
    ctx.beginPath();
    ctx.ellipse(centerX, centerY, 320 * scale, 120 * scale, -Math.PI / 6, 0, Math.PI * 2);
    ctx.strokeStyle = 'rgba(0, 150, 200, 0.1)';
    ctx.lineWidth = scale;
    ctx.stroke();
    
    requestAnimationFrame(draw);
  }
  
  draw();
})();

// 滚动标题
(function() {
  var title = '🔮 三进制黑洞 🌌 - 生活 · 工作 · 随笔 ';
  var pos = 0;
  
  function scrollTitle() {
    pos++;
    if (pos >= title.length) pos = 0;
    document.title = title.substring(pos) + title.substring(0, pos);
  }
  
  setInterval(scrollTitle, 300);
})();
