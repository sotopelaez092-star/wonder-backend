# Wonder MVP — Backend (Level 2)

干净版后端 + 管理面板。一台机器跑全部：

- **Hono + better-sqlite3** 后端 → `localhost:3001`
- **Caddy** 反代 + 静态文件 → `:80`
- **Cloudflare Tunnel** 对外暴露（免费 HTTPS + CDN）
- **PM2** 守 Node 进程

## 目录

```
wonder-backend/
├── app/                 # Hono Node 后端
├── www/                 # 静态文件（用户访问的所有页面）
│   ├── index.html       # 导航页（自包含，内联资源）
│   ├── courses.json     # 课程包结构（admin 编辑）
│   ├── courses/<id>/    # 每个课程一个目录
│   ├── assets/          # 共享资产
│   └── admin/           # 管理面板（单页）
├── data/                # SQLite + 日志（gitignore）
├── Caddyfile
└── cloudflared.example.yml
```

## Win 一键部署

在 Win 主机 PowerShell（管理员）跑：

```powershell
irm http://8.155.166.119/install-win.ps1 | iex
```

它会自动：装 Node + Caddy + cloudflared + git + 克隆这个 repo + 装 npm 依赖 + 初始化 db + 启动 PM2 + 启动 Caddy + 启动 cloudflared + 输出公开 URL。

完工后访问 `https://<给你的>.trycloudflare.com/` 看导航，`/admin` 进管理面板。

## 本地开发

```bash
cd app
cp .env.example .env
# 改 .env 里的 ADMIN_PASSWORD
npm install
npm run init-db
npm run dev    # nodemon
# 另开终端
caddy run --config ../Caddyfile
```

打开 `http://localhost/`。

## API 端点

### 公开
- `GET  /api/health` — 健康检查
- `GET  /api/courses` — 读 `www/courses.json` 返给前端
- `POST /api/events` — 写埋点
- `POST /api/waitlist` — 候补提交

### Admin（要 Bearer token）
- `POST /api/admin/auth/login` — `{ password }` → `{ token, expires_at }`
- `POST /api/admin/auth/logout`
- `GET  /api/admin/auth/me`
- `GET  /api/admin/leads?limit=&offset=&q=` — 候补列表
- `GET  /api/admin/leads/export.csv` — CSV 导出
- `GET  /api/admin/stats/funnel`
- `GET  /api/admin/stats/timeline?days=14`
- `GET  /api/admin/stats/recent-events?limit=200`
- `GET  /api/admin/courses` — 读 courses.json
- `PUT  /api/admin/courses` — 整个写回 courses.json
- `GET  /api/admin/courses/folders` — 实际磁盘上有哪些目录
- `POST /api/admin/courses/upload` — `multipart: file (zip) + id` → 解压到 `www/courses/<id>/`
- `DELETE /api/admin/courses/folder/:id` — 删目录

## 加新课程的两种方式

**方式 A：admin 面板上传 zip**
1. 浏览器开 `/admin` → 登录
2. Courses Tab → 选 zip → 填课程 id（小写字母数字-_）→ 上传
3. 编辑 courses.json：把这个 lesson 加到某个 pack 下，点保存

**方式 B：直接拖文件夹**
1. 在 `www/courses/` 下放一个新目录，里面是 `index.html`（自包含游戏）
2. admin 面板编辑 courses.json 加一行

任何形式的课程（HTML 游戏、Vite build、视频、PDF）只要打包成"目录里有 index.html"，规则都一样。

## 数据库 schema

只有 3 张表：
- `events` — 埋点
- `waitlist` — 候补
- `admin_sessions` — 管理员登录 token

课程结构在 `www/courses.json` 文件里，不入库。

## 凭据安全

- `app/.env` 里的 `ADMIN_PASSWORD` **不要 commit**（.gitignore 已排除）
- Cloudflare Tunnel 凭据（`cloudflared` login 后存于 `%USERPROFILE%\.cloudflared\*.json`）也不要 commit
