// 首页中心变幻特效
(function() {
  if (window.location.pathname !== '/' && window.location.pathname !== '/index.html') return;
  
  var canvas = document.createElement('canvas');
  canvas.id = 'center-orb';
  canvas.style.cssText = 'position:fixed!important;top:50%!important;left:50%!important;transform:translate(-50%,-50%)!important;z-index:1!important;pointer-events:none!important;opacity:0.6;';
  document.body.appendChild(canvas);
  
  var ctx = canvas.getContext('2d');
  var time = 0;
  
  function resize() {
    canvas.width = 400;
    canvas.height = 400;
  }
  resize();
  
  // 颜色变化
  function hslToRgb(h, s, l) {
    var r, g, b;
    if (s === 0) {
      r = g = b = l;
    } else {
      var hue2rgb = function(p, q, t) {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      };
      var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      var p = 2 * l - q;
      r = hue2rgb(p, q, h + 1/3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1/3);
    }
    return 'rgb(' + Math.round(r * 255) + ',' + Math.round(g * 255) + ',' + Math.round(b * 255) + ')';
  }
  
  function draw() {
    time += 0.01;
    
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    var centerX = canvas.width / 2;
    var centerY = canvas.height / 2;
    
    // 多层变幻圆环
    for (var i = 0; i < 5; i++) {
      var radius = 50 + i * 30 + Math.sin(time * 2 + i) * 20;
      var hue = (time * 50 + i * 30) % 360;
      var saturation = 0.8 + Math.sin(time + i) * 0.2;
      var lightness = 0.5 + Math.sin(time * 1.5 + i * 0.5) * 0.2;
      
      ctx.beginPath();
      ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
      ctx.strokeStyle = hslToRgb(hue / 360, saturation, lightness);
      ctx.lineWidth = 2 + Math.sin(time * 3 + i) * 2;
      ctx.globalAlpha = 0.5 + Math.sin(time * 2 + i * 0.3) * 0.3;
      ctx.stroke();
    }
    
    // 中心光点
    var centerHue = (time * 100) % 360;
    var gradient = ctx.createRadialGradient(centerX, centerY, 0, centerX, centerY, 80);
    gradient.addColorStop(0, 'rgba(255, 255, 255, 0.8)');
    gradient.addColorStop(0.5, hslToRgb(centerHue / 360, 0.8, 0.6));
    gradient.addColorStop(1, 'rgba(0, 0, 0, 0)');
    
    ctx.beginPath();
    ctx.arc(centerX, centerY, 80, 0, Math.PI * 2);
    ctx.fillStyle = gradient;
    ctx.globalAlpha = 0.6 + Math.sin(time * 4) * 0.2;
    ctx.fill();
    
    // 漂浮粒子
    for (var j = 0; j < 20; j++) {
      var angle = time * (0.5 + j * 0.1) + j * 0.5;
      var dist = 80 + Math.sin(time * 2 + j) * 40 + j * 10;
      var px = centerX + Math.cos(angle) * dist;
      var py = centerY + Math.sin(angle) * dist;
      var size = 2 + Math.sin(time * 3 + j) * 1;
      
      ctx.beginPath();
      ctx.arc(px, py, size, 0, Math.PI * 2);
      ctx.fillStyle = hslToRgb((centerHue + j * 10) / 360, 0.9, 0.7);
      ctx.globalAlpha = 0.5 + Math.sin(time * 2 + j) * 0.3;
      ctx.fill();
    }
    
    ctx.globalAlpha = 1;
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
