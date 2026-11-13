# 开发进度与验收证据（PROGRESS）

本文件按阶段记录：实际执行的命令、原始输出、结论与未完成项。
最后更新：2026-11-13

## 环境摘要

详见 [ENVIRONMENT.md](ENVIRONMENT.md)。当前机器：

- Windows 11 25H2（build 26200），Intel i9-13980HX，C: 剩余约 136.9 GB。
- Git 2.49.0、Node.js v22.13.0、WebView2 Runtime 157.0.4341.46 已就绪。
- Flutter 3.50.0 stable zip 已下载（1,782 MiB，sha256 `35fb8434…`），待解压。
- 当前会话未提权（非管理员），Visual Studio Build Tools 尚未安装，pnpm 尚未激活。
- 受限执行环境的 schannel 不可用（`SEC_E_NO_CREDENTIALS`）。实际采用的替代路径：
  git 使用 `-c http.sslBackend=openssl`，下载使用 Node.js 的 TLS 栈
  （`tools/download.js`）。

## 阶段 0 — 仓库与基线（完成）

### 执行

1. `git init -b main`，本地身份 `FSYL TV Dev <dev@fsyltv.local>`，未配置任何 remote。
2. 新增 `.gitignore`（同时覆盖 Flutter 与 Next.js）与 `README.md`，
   提交 `1b4308b chore: init repository`。
3. 导入上游。首选 `git subtree add` 因环境限制失败：

   ```
   git subtree --help
   sh.exe: *** fatal error - couldn't create signal pipe, Win32 error 5
   ```

   按任务书退路：clone（记录 SHA/tree）→ 删除 `.git` → 将工作树放入 `app/`、
   `moonserver/`；为保证与上游逐字节一致，使用
   `git fetch --depth 1 <sha>` + `git read-tree --prefix=... FETCH_HEAD^{tree}` 导入
   上游 tree 对象（等价于 subtree squash，但没有引入上游历史）。
4. 分别提交：
   - `ad85235 vendor: import Kazumi at 4ca04009…`（665 个文件）
   - `5b3d71e vendor: import MoonTV at c0bba763…`（116 个文件）
5. 新增根 `LICENSE`（GPL-3.0，与 `app/LICENSE` 字节一致）、
   `LICENSE-MOONTV-MIT`（与 `moonserver/LICENSE` 字节一致）、
   `THIRD-PARTY-NOTICES.md`、`VENDOR.md`、`SPEC.md`、`CHANGELOG.md`、
   `ENVIRONMENT.md`、`PROGRESS.md`。

### 验收输出（原文）

```
$ git rev-parse HEAD:app
2b51c43cd94f436da10de024a848d6788b5cc84d
$ git rev-parse HEAD:moonserver
5a3e2d25c55cb9524f6c89399114c6b1655591b3
$ git rev-parse HEAD:app/fastlane/.flutter (gitlink)
ab2912035e160d9cad6306df307576da6128ebdb
$ git remote -v
(empty = no remote)
$ git diff --stat HEAD -- app moonserver
(empty = vendored trees unchanged)
$ git log --oneline
5b3d71e vendor: import MoonTV at c0bba763d16fb5cd830a808d58329025337491cf
ad85235 vendor: import Kazumi at 4ca04009fdae696883629e0984e7d7134cc7ed84
1b4308b chore: init repository
LICENSE sha256: 230184F60BAE2FEAF244F10A8BAC053C8FF33A183BCC365B4D8B876D2B7F4809
LICENSE-MOONTV-MIT sha256: C3BBD168DB759DC5AD4A0A165C599C284969435B0E1C7827CBE3BC20FDBD3F02
app LICENSE sha256: 230184F60BAE2FEAF244F10A8BAC053C8FF33A183BCC365B4D8B876D2B7F4809
moonserver LICENSE sha256: C3BBD168DB759DC5AD4A0A165C599C284969435B0E1C7827CBE3BC20FDBD3F02
```

对照上游 API 返回值：

- Kazumi commit `4ca04009…` → tree `2b51c43cd94f436da10de024a848d6788b5cc84d`（一致）
- MoonTV commit `c0bba763…` → tree `5a3e2d25c55cb9524f6c89399114c6b1655591b3`（一致）

### 结论

阶段 0 完成。仓库、两棵上游子树、许可证与契约文档齐备；`git status` 在文档提交后
干净；未配置 remote，未 push。未修改 `app/` 与 `moonserver/` 中任何上游文件。

## 阶段 2 — 影视模块可独立运行（完成）

### MoonTV localstorage 数据面（精读 `src/lib/db.ts` / `src/lib/db.client.ts`）

- `src/lib/db.ts` 的 `createStorage()` 在 `NEXT_PUBLIC_STORAGE_TYPE=localstorage` 时返回
  `null as unknown as IStorage`；`DbManager` 只是把调用转发给该实例。也就是说 **服务端
  在 localstorage 模式下不持有播放记录、收藏、搜索历史**。API 路由（playrecords /
  favorites / searchhistory 等）都先判断 `STORAGE_TYPE !== 'localstorage'`，命中
  localstorage 时直接返回空或“不支持”，不读写任何服务端存储。
- `src/lib/db.client.ts`（`'use client'`）直接读写浏览器 `localStorage`：
  - `moontv_play_records`：`{ "source+id": PlayRecord }`，字段含 `play_time`、
    `total_time`、`save_time`、`index` 等；读取/保存见 `getAllPlayRecords`、
    `savePlayRecord`。
  - `moontv_favorites`：收藏。
  - `moontv_search_history`：搜索历史（最多 20 条）。
  - `moontv_skip_configs`：跳过片头片尾配置。
  - `moontv_cache_<username>`：数据库模式（redis/d1/upstash）的混合缓存；localstorage
    模式不使用它。
- 谁读写：只有 WebView2 里的浏览器 JS 读写；Next.js 服务端只负责返回页面与静态资源，
  `middleware` 负责 localstorage 模式的密码校验，不接触记录内容。
- 因此影视记录实际落在 WebView2 的 user data folder（Local Storage LevelDB），
  外壳把该目录固定为 `%LOCALAPPDATA%\FSYLTV\data\movie`（开发时
  `build\dev-data\movie`）。动漫 Hive 数据在 `data\anime`，两者物理隔离。
- 无密码模式：上游 `api/login` 在 localstorage + 未设置 `PASSWORD` 时直接放行，但
  `middleware` 会先把所有页面重定向到 `/warning`，导致“无密码模式”实际不可用。
  本项目增加 `FSYLTV_LOCAL_MODE=true`（仅当请求 Host 为 127.0.0.1/localhost 且
  storage=localstorage 时生效）跳过登录；未设置该变量时行为与原版完全一致。

### 改造内容

- `next.config.js` 上游本来就有 `output: 'standalone'`，未改动这一项。
- 新增 `/api/health`（200 + `{"status":"ok"}`）、`/api/shutdown`；`POST /__shutdown`
  通过 rewrite 映射到后者。
- `middleware.ts` 跳过两个新端点，并支持本机无密码模式。
- 站点名改为优先读 `NEXT_PUBLIC_SITE_NAME`（layout.tsx、config.ts）。
- sidecar 入口包装 `tools/moon/server-wrapper.js`：读取 `PORT`/`HOSTNAME`，启动
  Next standalone，轮询 `/api/health` 后向 stdout 打印 `FSYLTV_READY <port>`，
  处理 SIGTERM/SIGINT。
- 构建：`pnpm install`（hoisted linker，保证 standalone 依赖完整）+ `pnpm build`，
  构建时注入 `NEXT_PUBLIC_SITE_NAME=FSYL TV`（静态页面在构建期烘焙站点名）。

### 验收输出（原文）

```
$ pnpm build
✓ Compiled successfully
Route (app) ... ƒ /api/health ... ƒ /api/shutdown
build exit=0

$ node.exe server.js（PORT=43126，HOSTNAME=127.0.0.1，localstorage，无 PASSWORD）
ready=True waited_ms=700
READY lines: 1
health_status=200 body={"status":"ok","app":"fsyltv","name":"FSYL TV","uptime":1,"time":1794549088613}
root_status=200 title=FSYL TV fsyl=True
shutdown_status=200 body={"status":"shutting-down"}
process_exited=True
moon_node_left=0
```

构建/运行环境：Node v22.13.0、pnpm 10.12.4（与 `packageManager` 一致）、Next 14.2.30。

### 结论

阶段 2 完成：MoonTV 可独立构建与启动，无密码本机模式、健康检查、就绪握手、
优雅退出与残留进程清理均通过真实命令验证；服务端不参与 localstorage 记录存储。
未改动播放器或视频流。
