// 星空特效 - 全屏覆盖
(function() {
  var canvas = document.createElement('canvas');
  canvas.id = 'bg-canvas';
  canvas.style.cssText = 'position:fixed!important;top:0!important;left:0!important;width:100%!important;height:100%!important;z-index:-9999!important;pointer-events:none!important;';
  document.body.appendChild(canvas);
  
  var ctx = canvas.getContext('2d');
  
  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }
  resize();
  window.addEventListener('resize', resize);
  
  var stars = [];
  var numStars = 300;
  
  for (var i = 0; i < numStars; i++) {
    stars.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      size: Math.random() * 2 + 0.5,
      speed: Math.random() * 0.5 + 0.2,
      angle: Math.random() * Math.PI * 2,
      opacity: Math.random() * 0.5 + 0.5,
      twinkle: Math.random() * 0.02
    });
  }
  
  function draw() {
    // 半透明黑色覆盖，产生拖尾效果
    ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    var centerX = canvas.width / 2;
    var centerY = canvas.height / 2;
    
    for (var i = 0; i < numStars; i++) {
      var star = stars[i];
      
      // 星星绕中心旋转
      star.angle += star.speed * 0.005;
      var radius = Math.sqrt(Math.pow(star.x - centerX, 2) + Math.pow(star.y - centerY, 2));
      star.x = centerX + Math.cos(star.angle) * radius;
      star.y = centerY + Math.sin(star.angle) * radius;
      
      // 闪烁
      star.opacity += star.twinkle;
      if (star.opacity > 1 || star.opacity < 0.3) {
        star.twinkle = -star.twinkle;
      }
      
      // 画星星
      ctx.beginPath();
      ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255, 255, 255, ' + star.opacity + ')';
      ctx.fill();
    }
    
    // 随机流星
    if (Math.random() > 0.99) {
      var startX = Math.random() * canvas.width;
      var startY = Math.random() * canvas.height * 0.5;
      ctx.beginPath();
      ctx.moveTo(startX, startY);
      ctx.lineTo(startX - 50 - Math.random() * 50, startY + 50 + Math.random() * 50);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
      ctx.lineWidth = Math.random() * 2;
      ctx.stroke();
    }
    
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
