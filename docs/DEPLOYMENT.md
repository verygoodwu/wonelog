# 部署

## 服务器准备

服务器需要 Node.js 22、npm、rsync 和一个可写博客目录的部署用户。

```bash
sudo mkdir -p /var/www/wonelog-source /var/www/wonelog
sudo chown -R deploy:deploy /var/www/wonelog-source /var/www/wonelog
```

将 `apps/blog` 上传到 `/var/www/wonelog-source`，设置 `.env` 中的 SSH 参数，并把公钥加入服务器部署用户的 `authorized_keys`。

发布服务会上传文章、配置和图片，然后在服务器源码目录执行 `npm install && npm run build`，最后通过 `rsync` 更新静态站点目录。

Nginx 只需将站点根目录指向 `/var/www/wonelog`。管理 API 不建议直接暴露到公网。