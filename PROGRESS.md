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

## 阶段 1 — 三个验证（完成，S1 判定通过）

环境：Windows 11 25H2、WebView2 Runtime 157.0.4341.46、Flutter 3.50.0、
VS 2022 Build Tools（MSVC 14.44）、Node 22.13。测量对象为最终架构中的
WebView2（Texture 渲染，非子窗口）。

### S1：1080p HLS 播放

测试流：`https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`，页面内嵌 hls.js 1.6.6，
强制最高码率。数据来自应用自身 `data\logs\s1.log` 与 Windows `GPU Engine` 性能计数器。

```
1920x1080, 0 dropped frames, playing=true
level=320x184,512x288,848x480,1280x720,1920x1080
frames: 301 -> 1020（持续增长，约 60fps）
GPU（本应用进程）：19.9% / 21.2% / 20.7%（3 次 1s 采样）
CPU（kazumi+node+本应用 WebView2）：3.03 core-seconds / 4s
切到动漫后（隐藏）：
GPU（本应用进程）：0% / 0% / 0%
CPU（本应用进程）：1.0 core-seconds / 4s
```

结论：可以播放、无掉帧、GPU 在切走后回落（本应用渲染进程 0%）。
未触发方案 A/B（不需要改成原生子窗口，也不需要降到 720p）。

说明：插件原生的 `suspend()` 会关闭 Graphics Capture item，`resume()` 后捕获
不再恢复，画面定格。因此隐藏时改为“JS 暂停音视频 + 捕获帧率降到 1fps”，
保留捕获会话；实测 GPU 回落到本应用 0%。该取舍记入 KNOWN-ISSUES。

### S2：列表页 ↔ WebView2 来回切 20 次

使用可滚动测试页（200 条），脚本自动循环 20 次（每次动漫 330ms、影视 520ms），
每 220ms 抓取窗口截图，共 83 帧；同时读取滚动位置。

```
S2 cycle=1..20: scroll_before=420 scroll_after=420（20/20 全部保持）
frames=83, 亮度 min=15.7 max=34.9
black_frames(mean<12)=0
最大帧间差=20.75（页面内容整体切换，无半透明叠影）
动画侧与影视侧截图均正常，标题栏胶囊状态正确
```

结论：20 次来回切换无黑屏、无残影、滚动位置完全保持。用户手动复现的
“切回影视卡住”已定位为原生 suspend/resume 缺陷，改用降帧方案后修复
（切回后 HUD 与页面继续刷新，视频按需求停在原帧）。

### S3：假 sidecar 生命周期

```
$ flutter test test\shell\moon_sidecar_test.dart
[moon] --- starting sidecar on port 9988 ---
[moon] FSYLTV_READY 9988
[moon] shutdown response 200
00:00 +1: All tests passed!
test exit=0
node leftovers: 0
```

结论：启动子进程 → 读握手行 → 健康检查 → 关闭后无残留进程，全部通过。

## 阶段 3 — 外壳与切换（完成）

- 单窗口：Flutter runner 唯一顶层窗口；影视 WebView2 以 Flutter Texture 合成，
  不是额外子窗口。
- 启动页：两张卡片（影视/动漫），显示 FSYL TV；记住上次板块。
- 顶部常驻胶囊切换器，200ms 指示器滑动 + 200ms 内容淡入；两个板块用
  `IndexedStack` 常驻，切换只改索引。
- 切走动漫：`ShellBridge.animeActive=false`，播放器暂停；切回不自动恢复。
- 切走影视：JS `pause()+muted=true`，捕获帧率降到 1fps；切回恢复帧率并停在原帧。
- 无边框窗口 + 自绘标题栏（拖动/双击最大化/最小化/托盘/关闭）；
  窗口尺寸、位置、最大化状态与上次板块写入 `data\config\window.json`、`app.json`。
- 全屏（Kazumi 播放器或 Ctrl+F）时隐藏整个自绘标题栏（胶囊与窗口按钮），
  退出全屏恢复；窗口已最大化、原生不派发全屏事件时由 500ms 状态轮询兜底。
- 关闭弹窗由外壳层渲染，动漫/影视任一板块都可见；影视区也可正常选择
  “最小化至托盘 / 退出 FSYL TV”。
- 托盘沿用上游 tray_manager，图标/提示/菜单已换为 FSYL TV。

构建验收：`flutter build windows --release` → `Built ...\Release\kazumi.exe`，
启动后 stderr 仅 Flutter 常规警告，无未捕获异常。

## 阶段 4 — 目录收敛（完成）

- `AppPaths` 单例提供全部路径：`data\{config,account,anime,movie,cache,logs}`；
  不可写时回退 `%TEMP%\FSYLTV\data` 并显示提示。
- 代码内 `path_provider` 使用点已全部移除：
  `grep -r "path_provider|getApplicationSupportDirectory|getTemporaryDirectory" app/lib` → 0 条。
- Hive → `data\anime\hive`；插件 → `data\anime\plugins`；下载 → `data\anime\downloads`；
  着色器 → `data\cache\anime_shaders`；图片缓存 → `data\cache\images`；
  播放器/更新/WebDAV 临时文件 → `data\cache\...`；日志 → `data\logs`。
- WebView2 user data folder 显式设为 `data\movie`；实测生成 `data\movie\EBWebView`。

清空数据目录后首次启动，实际生成的顶层目录（原文）：

```
account
anime
cache
config
logs
movie
```

没有散落目录；`config` 下只有 `app.json`、`window.json`、`moon.pid.json`。

## 阶段 5 — sidecar 生命周期（完成）

- 探测空闲端口 → 启动 `node.exe server.js` → 读 `FSYLTV_READY <port>`（20s 超时）
  → `/api/health` 校验 → 加载页面。
- 退出先 `POST /__shutdown`，1.5s 未退再 `taskkill /PID <pid> /T /F`；
  pid 文件记录 PID/启动时间/命令行，启动时三者吻合才清理残留。
- Job Object（`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`）绑定 sidecar。实测强杀主程序：

```
SIDECAR_PID=35072
sidecar_before_kill=True
--- kill main process (simulated crash) ---
sidecar_after_kill=False
```

- 影视 sidecar 失败/退出时 MoviePage 显示错误页与“重启影视模块”按钮；
  动漫板块不受影响。

## 阶段 6 — 品牌与关于页（完成）

用户可见文案/素材替换：

- 窗口标题、标题栏、托盘提示/菜单、启动页、关于页标题 → FSYL TV。
- 应用图标（窗口/托盘/安装包）、MoonTV `logo.png`/`favicon.ico`/PWA 图标
  改用项目方提供的角色图 `fsyl_logo_source.png`，由 `tools/make_icons.py`
  统一生成（圆角裁切，不再使用 Kazumi logo，也不再使用临时渐变图标）。
- 关闭弹窗、我的页、路由错误页中剩余的 Kazumi 文案已改为 FSYL TV；
  关于页保留“Kazumi 源代码/更新日志”等上游署名链接。
- MoonTV 站点名/标题/PWA manifest → FSYL TV（构建时注入 `NEXT_PUBLIC_SITE_NAME`）。
- 关于页写明：上游项目名、仓库链接、许可证、一句“基于其修改而来”、
  完整源码入口（安装目录 `source\FSYLTV-source.zip`）。
- 默认字体改为系统字体（不再默认使用 MiSans）；上游字体文件与 LICENSE 原样保留。
- 上游版权头、LICENSE、`assets/statements` 免责声明均未删除。

grep 审计（保留项）：`assets/statements/`、LICENSE、api user-agent、
上游仓库地址、`package:kazumi` import 路径均保留。

## 阶段 7 — 账号骨架与同步切面（完成）

- Dart：`AccountService`（登录态、DPAPI 加密 token、设备 ID、服务器地址、
  两个开关），`SyncAdapter` 两模块空壳，`SyncService`；未登录时立即返回，
  不产生网络请求。
- 设置页：`同步设置` 新增“账号与云同步”卡片 → `/settings/account`，
  显示“本地离线模式”，服务器/账号/密码三个输入框 + 两个开关，只存本地。
- DPAPI 测试：

```
$ flutter test test\shell\account_service_test.dart
00:00 +1: All tests passed!
test exit=0
```

- `loggedIn` 只出现在 `shell/account/account_service.dart` 与
  `shell/sync/sync_adapter.dart`，业务代码中无该判断。
- MoonTV：先写方案 `moonserver/src/lib/sync/README.md`，再新增
  `types.ts` / `envelope.ts` / `adapter.ts`；用独立键 `fsyltv_sync_meta_v1`
  记录 `updatedAt/isDeleted/dirty`，不修改现有数据键与读写路径。
  `pnpm typecheck` → exit 0；未登录行为与原版一致，不发请求。

## 阶段 8 — 打包（完成）

- `tools/build-moonserver.ps1`：pnpm build → standalone 整理（static/public）→
  包装入口脚本 → 复制 node.exe 到 `app\moon\`。
- `tools/package.ps1`：Flutter release 构建（提权）→ sidecar → 便携版与安装版
  两套产物 → `source\FSYLTV-source.zip`（GPL 源码）→ 两个 ZIP。
- `tools/install.ps1` / `tools/uninstall.ps1`：按用户安装到
  `%LOCALAPPDATA%\FSYLTV\app`，创建开始菜单/桌面快捷方式与卸载项；
  卸载询问是否保留 `data`。
- 构建与产物验收输出见本节下方（打包执行后追加）。

实际产物：

```
dist\FSYLTV-portable.zip        约 152.8 MB
dist\FSYLTV-Setup.zip           约 152.8 MB
解压后程序体积                   约 277 MB（两套相同）
source\FSYLTV-source.zip        34,557,174 bytes（git archive HEAD）
```

sidecar 生产布局验收（`build\moon`，即安装后的 `app\moon`）：

```
ready=True waited_ms=600
READY=FSYLTV_READY 43210
health=200 {"status":"ok","app":"fsyltv","name":"FSYL TV","uptime":1,...}
root=200 title=FSYL TV
shutdown=200 exited=True node_left=0
```

便携版验收（`dist\FSYLTV-Portable\FSYLTV\fsyl_tv.exe`，真实生产路径）：

```
PIDFILE=...\FSYLTV-Portable\FSYLTV\moon\node.exe ...\FSYLTV-Portable\FSYLTV\moon\server\server.js
USES_DIST_MOON=True
moon.log: job object assign pid=89064 ok=true
         FSYLTV_READY 13177
health=200 {"status":"ok","app":"fsyltv","name":"FSYL TV",...}
sidecar_after_kill=False
```

安装/卸载验收：

```
install exit=0
APP_DIR=C:\Users\JKH\AppData\Local\FSYLTV\app
exe=True moon_node=True moon_server=True
桌面/开始菜单快捷方式：True / True

安装版启动：
moon.log  FSYLTV_READY 8466（sidecar 从 %LOCALAPPDATA%\FSYLTV\app\moon 启动）

'n' | uninstall.ps1
uninstall exit=0
data kept at C:\Users\JKH\AppData\Local\FSYLTV\data
FSYL TV removed.
app_exists=False data_exists=True shortcuts=False
```

阶段 8 完成：便携版与按用户安装版均可运行，sidecar 使用 `app\moon\node.exe` +
`app\moon\server\server.js`，强杀主程序后无孤儿进程；GPL 源码包随包提供。

## 阶段 9 — GitHub、更新与体验修复（完成）

- 仓库：`https://github.com/FSYL001/FSYL-TV`（public，GPL-3.0，含全部源码）。
- 应用更新：启动自动检查 + 关于页手动检查 GitHub Releases；仅 Windows
  `FSYLTV-windows-portable.zip`，下载后等待退出、覆盖程序目录并重启，data 保留。
  发布脚本 `tools/publish-release.ps1` 生成 tag/Release。
- 影视首页封面：新增本地 `/api/image-proxy`，默认注入 `RUNTIME_CONFIG.IMAGE_PROXY`；
  Douban 封面带 `Referer: https://movie.douban.com/`。实测代理返回
  `200 image/jpeg`（25,535 bytes），安装版首页《热门电影/热门剧集》封面全部恢复。
- 应用更新：GitHub Release `v1.0.0` 已发布；便携版/安装版资产由
  `tools/publish-release.ps1` 生成，应用内检查更新读取该 Release。
  实测临时发布 `v1.0.1` 后启动应用，自动检查进入“正在下载更新 6.9%”；
  测试 Release 已删除，`latest` 恢复为 `v1.0.0`。
- 仓库：<https://github.com/FSYL001/FSYL-TV>（public，main 分支已推送）。
- 免责声明：三处默认文案统一为
  “本网站 / APP 仅提供影视信息搜索服务……仅供交流学习 ！”。
- 动漫规则：将当前导入的 18 条规则放入 `app/assets/rules/plugins.json`，首次启动
  复制到 `data\anime\plugins\v2`；已有文件不覆盖，规则商店/更新逻辑保持可用。
- 弹幕：定位为 DanDanPlay API 需要 AppId/AppKey；新增设置页
  `弹幕设置 → 弹幕 API 凭证`，也可在构建时用 `--dart-define` 注入。
- 图标：AppUserModelID、窗口图标、安装后 `ie4uinit` 刷新；窗口图标提取验证为
  新角色 logo。若任务栏固定项仍显示旧图，取消固定后重新固定。
- 1.0.1：关于页“检查更新”明确读取 FSYL TV Release，更新日志按钮指向 FSYL 仓库；
  规则管理列表改用独立 ScrollController，修复“资源”板块滚轮无法下滑。
- 1.0.2：修正 webview_windows 原生滚轮坐标（原来固定发到 0,0，才会被影视侧栏吞掉）；
  实测滚动前后画面变化，影视首页可正常滚轮下滑。
- 1.0.3：Douban 分类改用 `movie.douban.com/j/search_subjects` 主源、旧接口回退；
  MoviePage 增加 Flutter 滚轮 Listener + JS 兜底，日志 `logs/movie-scroll.log`。
  发布后需人工确认首页数据与滚轮。
