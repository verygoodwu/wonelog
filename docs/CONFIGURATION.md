# 配置参考

## 站点配置

`data/config.json` 控制站点名称、头像、昵称、首页文案、邮箱、备案号、开站时间和社交链接。首次运行前可以直接编辑，也可以在桌面客户端的设置页修改。

## 环境变量

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `PUBLIC_SITE_URL` | 构建时 | 博客公开地址，例如 `https://blog.example.com` |
| `WONELOG_SERVER_HOST` | 发布时 | SSH 服务器域名或 IP；留空时禁用发布 |
| `WONELOG_SERVER_USER` | 发布时 | 最小权限部署用户 |
| `WONELOG_SERVER_KEY` | 发布时 | SSH 私钥在当前运行环境中的路径 |
| `WONELOG_SERVER_SOURCE_DIR` | 发布时 | 服务器上的 Astro 源码目录 |
| `WONELOG_SERVER_SITE_DIR` | 发布时 | Nginx 静态站点目录 |
| `WONELOG_SERVER_BLOG_DIR` | 发布时 | 服务器文章目录 |
| `WONELOG_SERVER_CONTENT_DIR` | 发布时 | 服务器 JSON 内容目录 |
| `WONELOG_SERVER_PUBLIC_IMAGES_DIR` | 发布时 | 服务器公开图片目录 |
| `WONELOG_GITHUB_TOKEN` | 可选 | GitHub 图库 Token |
| `WONELOG_GITHUB_REPO` | 可选 | 图库仓库，格式 `owner/repo` |
| `WONELOG_GITHUB_BRANCH` | 可选 | 图库分支，默认 `main` |

## Docker SSH 配置

默认 `docker-compose.yml` 不挂载私钥，因此可以安全启动并体验管理功能。需要发布时：

1. 将私钥放到 `secrets/id_ed25519`。
2. 使用 `deploy/docker-compose.publish.yml.example` 作为额外 Compose 配置。
3. 设置 `WONELOG_SERVER_KEY=/run/secrets/wonelog_ssh_key`。

```bash
docker compose -f docker-compose.yml -f deploy/docker-compose.publish.yml.example up --build
```

不要把真实 `.env` 和 `secrets/` 提交到 Git。