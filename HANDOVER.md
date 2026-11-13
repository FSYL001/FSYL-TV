# FSYL TV 交接文档

最后更新：2026-11-13  
当前版本：**1.0.5**  
主要维护者：FSYL001  
仓库：[GitHub](https://github.com/FSYL001/FSYL-TV) · [Gitee](https://gitee.com/FSYL001/FSYL-TV)

本文档面向接手维护的人，说明当前实现、关键约束、构建/发布流程、已验证内容、未完成项和常见坑。面向用户的介绍与下载说明见 [README.md](README.md)。

---

## 1. 项目定位

FSYL TV 是一个 Windows 单窗口桌面客户端，把两个独立开源项目放入同一个 Flutter 窗口：

| 板块 | 上游 | 许可证 | 播放器 |
| --- | --- | --- | --- |
| 动漫 | [Kazumi](https://github.com/Predidit/Kazumi) `4ca04009fdae696883629e0984e7d7134cc7ed84` | GPL-3.0 | Kazumi 原生 media_kit |
| 影视 | [MoonTV](https://github.com/samqin123/MoonTV) `c0bba763d16fb5cd830a808d58329025337491cf` | MIT | MoonTV 网页自带播放器（WebView2） |

FSYL TV 不提供、不托管、不分发任何影视内容。

### 不可破坏的六条约束

1. 只有一个顶层窗口，不启动第二个界面 exe。
2. 两个板块不互相 import，不共享播放器实例、观看记录、收藏。
3. 影视板块必须保留 MoonTV 自己的播放器，不改用 media_kit。
4. 动漫板块的播放器、规则引擎、抓取逻辑除品牌/路径注入外不修改。
5. 不升级 Flutter、pub 依赖、Node/pnpm、git 依赖 commit；不删除上游版权与许可证。
6. 不得写入“已获授权/已获许可”等误导性表述。

任何涉及以上约束的改动，先改 [SPEC.md](SPEC.md) 并说明原因。

---

## 2. 当前交付状态

| 项目 | 状态 |
| --- | --- |
| 源码仓库 | GitHub 已推送；main 最新提交见 `git log` |
| 版本号 | `app/lib/shell/app_version.dart` → `1.0.5` |
| GitHub Release | `v1.0.5` 已创建，含 `FSYLTV-Setup.exe`、便携 ZIP、安装脚本 ZIP |
| Gitee 仓库 | `FSYL001/FSYL-TV` 已创建 |
| Gitee 源码/Release | 推送曾因 `curl 56 / RPC failed` 中断，需重试；Gitee Release 资产尚未上传 |
| 本机安装 | 文档撰写时为 1.0.4；1.0.5 需运行 Setup.exe 或应用内更新 |
| 安装器 | `install.ps1` 手工验证可安装；`FSYLTV-Setup.exe` 在受限开发会话中因 ACL 拒绝写入 LocalAppData，需普通桌面复测 |
| 自动更新 | 代码已实现下载完自动安装；尚未做 1.0.4→1.0.5 的完整端到端验收 |
| 动漫搜索 | 已加入“镜像无凭据时直连 api.bgm.tv”的修复，尚未在运行时复验 |
| 弹幕 | 未内置 DanDanPlay 凭据；等待用户申请审核 |
| 影视搜索 | 依赖 MoonTV 中用户配置的片源，代码层无缺失 API |

---

## 3. 架构

```text
Flutter Windows runner (单窗口)
└─ MaterialApp.router
   └─ FsylShell
      ├─ 自绘标题栏 + 模块胶囊
      ├─ IndexedStack
      │  ├─ animeChild: Kazumi Navigator / MaterialApp.router
      │  └─ MoviePage
      │     ├─ MoonSidecar (node.exe + server.js)
      │     └─ Webview2 Texture (webview_windows fork)
      └─ 全局退出确认 / 更新入口
```

### 3.1 单窗口外壳

关键文件：

- `app/lib/app_widget.dart`：`MaterialApp.router(builder: FsylShell(...))`。
- `app/lib/shell/shell.dart`：标题栏、胶囊切换、全屏、退出遮罩。
- `app/lib/shell/shell_bridge.dart`：外壳与页面共享的当前模块/关闭回调。
- `app/lib/shell/exit_flow.dart`：记住退出选择。
- `app/lib/bean/dialog/exit_confirmation_dialog.dart`：统一退出确认。

约束：

- 动漫 Navigator 由 Kazumi 自己管理，外壳只包裹，不重建。
- 影视页面放在 `IndexedStack` 中常驻；切走不 dispose。
- 全屏时标题栏隐藏；500ms 轮询 `windowManager.isFullScreen()` 解决最大化时无 WM_SIZE 事件的问题。

### 3.2 影视 sidecar

关键文件：`app/lib/shell/moon_sidecar.dart`、`app/lib/shell/job_object.dart`。

启动：

```text
%LOCALAPPDATA%\FSYLTV\app\moon\node.exe
%LOCALAPPDATA%\FSYLTV\app\moon\server\server.js
```

工作目录：`...\app\moon\server`。

环境变量：

| 变量 | 值 |
| --- | --- |
| `PORT` | 外壳探测的空闲端口 |
| `HOSTNAME` | `127.0.0.1` |
| `NEXT_PUBLIC_STORAGE_TYPE` | `localstorage` |
| `NEXT_PUBLIC_SITE_NAME` | `FSYL TV` |

生命周期：

1. 端口探测 → `Process.start`。
2. 读取 stdout，20 秒内必须出现 `FSYLTV_READY <port>`。
3. 调 `/api/health`，JSON `status=ok`。
4. 退出时 `POST /__shutdown`，1.5 秒未退再 `taskkill /T /F`。
5. Windows Job Object 设置 `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`，防止主进程被杀后 sidecar 残留。
6. 启动时校验 `data\config\moon.pid.json` 的 PID/启动时间/命令行，避免误杀其他 node 进程。

日志：`data\logs\moon.log`。

### 3.3 WebView2 与滚轮

关键文件：`app/lib/shell/movie_page.dart`。

- 使用 `webview_windows` 固定 fork（`2b3306d2bfb9f22cbb328743b60e547cf50f0c3c`）。
- WebView2 user data folder：`data\movie`。
- 原 fork 的滚轮事件固定发到 `(0,0)`，会被 MoonTV 左侧栏吞掉；`tools/patch-webview-scroll.js` 改为发送到 `last_cursor_pos_`。
- 该原生补丁在部分版本仍不稳定，MoviePage 外层另有 `Listener` + JS 按鼠标位置查找可滚动容器并 `scrollBy`，`data\logs\movie-scroll.log` 可观察事件。
- 不要调用原生 `suspend()`：会关闭 Graphics Capture item，`resume()` 后画面定格。当前隐藏策略是 JS 暂停 + `setFpsLimit(1)`，切回 `setFpsLimit(0)`。

### 3.4 动漫数据与修改边界

- Hive：`data\anime\hive`。
- 规则：`data\anime\plugins\v2`。
- 初始规则：`app/assets/rules/plugins.json`，首次启动由 `DefaultRules.ensureSeeded()` 复制，不覆盖已有规则。
- 播放器/规则/抓取逻辑保持 Kazumi 原实现；品牌文字、图标、路径注入、设置页增强属于允许修改。
- `AppPaths` 统一提供可写路径；不要在业务代码中直接拼 `%LOCALAPPDATA%`。

---

## 4. 数据与路径契约

完整契约见 [SPEC.md](SPEC.md)。

```text
%LOCALAPPDATA%\FSYLTV\
├─ app\                         程序目录，升级整体替换
│  ├─ fsyl_tv.exe
│  └─ moon\
│     ├─ node.exe
│     └─ server\server.js
└─ data\                        唯一可写区
   ├─ config\
   ├─ account\
   ├─ anime\
   ├─ movie\
   ├─ cache\
   └─ logs\
```

- 开发态覆盖：`FSYLTV_DATA_ROOT`、`FSYLTV_MOON_DIR`、`FSYLTV_NODE_EXE`。
- 安装版/便携版都必须把数据写到 `%LOCALAPPDATA%\FSYLTV\data`。
- 程序目录不可写时也不影响数据目录。
- 卸载时询问是否保留 `data`。
- 删除 `data` 等价于清空本地记录。

---

## 5. 代码地图

| 路径 | 职责 |
| --- | --- |
| `app/lib/main.dart` | AppPaths、Hive、窗口初始化、默认规则、单实例 |
| `app/lib/app_widget.dart` | MaterialApp + FsylShell |
| `app/lib/shell/shell.dart` | 单窗口、标题栏、切换、全屏、退出遮罩 |
| `app/lib/shell/movie_page.dart` | WebView2、错误/重试、切走渲染降频、滚轮兜底 |
| `app/lib/shell/moon_sidecar.dart` | sidecar 启停、握手、健康检查、日志 |
| `app/lib/shell/job_object.dart` | Windows Job Object |
| `app/lib/shell/app_paths.dart` | 唯一可写路径来源 |
| `app/lib/shell/default_rules.dart` | 内置规则 seeding |
| `app/lib/shell/windows_portable_update.dart` | 下载 ZIP 的解压/替换脚本 |
| `app/lib/services/update/auto_updater.dart` | 检查、下载、自动安装 |
| `app/lib/services/network/bangumi_acceleration.dart` | Bangumi 直连/镜像选择 |
| `app/lib/request/clients/bangumi_client.dart` | Bangumi 请求与签名 |
| `app/lib/pages/search/search_controller.dart` | 动漫搜索 |
| `app/lib/pages/about/about_page.dart` | 版本、更新、上游/Gitee 链接 |
| `moonserver/src/app/api/douban/categories/route.ts` | 豆瓣分类主源/回退 |
| `moonserver/src/app/api/image-proxy/route.ts` | 封面图代理 |
| `tools/elevated-build.ps1` | 提权 Flutter 构建 + 本地补丁 |
| `tools/package.ps1` | 便携版/安装包/Setup.exe/源码包 |
| `tools/publish-release.ps1` | GitHub tag、打包、Release |
| `tools/publish-gitee.ps1` | Gitee 镜像仓库、tag、Release |
| `tools/installer/Installer.cs` | Setup.exe 引导器 |

---

## 6. 构建环境

当前验证环境（2026-11-13）：

- Windows 11 25H2
- Flutter 3.50.0 stable / Dart 3.14.0
- Visual Studio Build Tools 17.14.45，VCTools
- Node.js 22.13.0
- pnpm 10.12.4
- WebView2 Runtime 157.x
- Windows PowerShell 5.1 + Git for Windows

### 6.1 依赖安装

```powershell
cd app
..\tools\flutter.ps1 pub get --enforce-lockfile
cd ..\moonserver
pnpm install --frozen-lockfile
cd ..
```

不要执行 `flutter upgrade`、`pnpm update` 或修改 `pubspec.yaml` 中的 git 依赖 SHA。

### 6.2 本机特殊补丁

只在当前受限开发机需要，脚本幂等，构建脚本会自动调用：

```powershell
node tools\patch-ech-http.js         # ech_http CA 字符串过长导致 MSVC C2026
node tools\patch-webview-nuget.js    # 跳过已还原的 NuGet 包
node tools\patch-webview-scroll.js   # 滚轮坐标修复（本地 pub 缓存）
```

补丁只改 `tools\.cache\pub-cache`，不提交依赖版本变更。

其他常见问题：

- `app\build\flutter_assets` 残留旧 logo 导致 errno 183：删除该目录再构建。
- 符号链接权限不足：用 `tools\elevated-build.ps1`。
- Dart 写真实 `%APPDATA%`/`%TEMP%` 被拒：`tools\flutter.ps1` 会重定向到 `tools\.cache`。

### 6.3 构建

```powershell
# MoonTV standalone -> build\moon
powershell -ExecutionPolicy Bypass -File tools\build-moonserver.ps1

# Flutter release（提权）
powershell -ExecutionPolicy Bypass -File tools\elevated-build.ps1
```

产物：`app\build\windows\x64\runner\Release\kazumi.exe`。

---

## 7. 打包与安装器

```powershell
powershell -ExecutionPolicy Bypass -File tools\package.ps1
```

流程：

1. `build-moonserver.ps1` 生成 `build\moon`。
2. 用 `git archive HEAD` 生成 `build\source\FSYLTV-source.zip`。
3. 把 Flutter Release、`build\moon`、文档、源码包、安装脚本复制到：
   - `dist\FSYLTV-Portable\FSYLTV`
   - `dist\FSYLTV-Setup\payload`
4. 生成 ZIP：
   - `dist\FSYLTV-windows-portable.zip`
   - `dist\FSYLTV-windows-setup.zip`
5. 生成 `dist\FSYLTV-Setup.exe`：
   - 用 `csc.exe`（.NET Framework 4.8）编译 `tools\installer\Installer.cs`；
   - 把 `FSYLTV-windows-setup.zip` 追加到 exe 尾部，并在最后 8 字节写入 zip 长度；
   - 运行时读取自身尾部、解压到 `%LOCALAPPDATA%\FSYLTV\setup-temp`、执行 `install.ps1`。

注意：

- `package.ps1` 必须**先提交代码**再运行，否则源码包不是当前工作区。
- 安装器引导器目前依赖 .NET Framework 4.8（Windows 10/11 通常自带）。
- 在受限开发会话里，Setup.exe 解压到 LocalAppData 可能被 ACL 拒绝；这是开发环境问题。若普通桌面也复现，检查 `%LOCALAPPDATA%\FSYLTV` ACL，或把临时目录改到程序可写目录。
- `FSYLTV-Setup.exe` 目前未做代码签名，SmartScreen 会提示未知发布者。

---

## 8. 应用内更新

关键文件：`app/lib/services/update/auto_updater.dart`、`app/lib/shell/windows_portable_update.dart`。

流程：

```text
启动/手动检查
  → GET api.github.com/repos/FSYL001/FSYL-TV/releases/latest
  → 失败则 GET gitee.com/api/v5/repos/FSYL001/FSYL-TV/releases/latest
  → 选择 windowsPortable ZIP
  → 下载到 data\cache\update
  → Windows 便携版：直接 _installUpdate
  → WindowsPortableUpdate.install:
       解压 ZIP
       写 apply-fsyl-update.ps1
       等待当前 PID 退出
       robocopy 覆盖程序目录
       重启 fsyl_tv.exe
  → AppExit.quit()
```

版本比较：

- `AppVersion.current` 是本项目版本，不要和 Kazumi 版本混用。
- `app/lib/utils/version.dart` 去掉前导 `v` 后比较。
- 更新只替换程序目录，不碰 `data`。

当前缺口：

- 1.0.3 及更早版本没有“下载完自动安装”，只能手动运行安装器。
- 自动更新的完整 1.0.4→1.0.5 端到端流程尚未验收；代码路径已存在。
- Gitee 回退依赖 Gitee Release 中可访问的附件；当前 Gitee Release 资产尚未上传。

---

## 9. 发布

### 9.1 GitHub

```powershell
# 1. 修改版本号
# app/lib/shell/app_version.dart -> current = '1.0.6'
# 2. 更新 CHANGELOG.md
# 3. 提交，保持工作区干净
# 4. 发布
powershell -ExecutionPolicy Bypass -File tools\publish-release.ps1 -Version 1.0.6
```

脚本当前上传：

- `dist\FSYLTV-windows-portable.zip`
- `dist\FSYLTV-windows-setup.zip`

`FSYLTV-Setup.exe` 是 1.0.5 手工补传到 Release 的。后续发布前应把 `publish-release.ps1` 的 `$assets` 加上 `dist\FSYLTV-Setup.exe`，否则 EXE 安装器不会自动上传。

### 9.2 Gitee

```powershell
powershell -ExecutionPolicy Bypass -File tools\publish-gitee.ps1 -Token <token> -Version 1.0.6
```

- 令牌需要 `projects` 权限；
- 脚本会创建仓库（若不存在）、推送 main/tag、创建 Release、上传便携 ZIP 与 Setup.exe；
- Gitee 大文件/网络可能失败，失败时以 GitHub 为准；
- 不要把 token 写入脚本、README 或提交历史。

当前 Gitee 状态：

- 仓库 `FSYL001/FSYL-TV` 已创建；
- 源码推送因 `curl 56 Recv failure: Connection was reset` / `http.postBuffer` 中断，需要重试；
- 可先只推源码，Release 资产后补。

---

## 10. 已验证与未验证

### 已验证

- Flutter Windows release 构建通过（1.0.5）。
- MoonTV sidecar 握手、健康检查、退出流程有测试记录。
- 豆瓣分类接口改为 legacy 主源后 `GET /api/douban/categories` 返回 200、20 条。
- MoviePage 外层 Listener + JS 滚轮兜底实测 `window.scrollY` 从 57 增长到 4914。
- 首页封面图代理曾实测 `200 image/jpeg`。
- 便携包、安装脚本、源码包可以生成。
- `install.ps1` 手工执行可把 1.0.5 程序复制到 `%LOCALAPPDATA%\FSYLTV\app`。

### 未验证/待复测

- `FSYLTV-Setup.exe` 在普通桌面双击安装（受限开发会话 ACL 失败）。
- 1.0.4→1.0.5 自动下载、自动替换、自动重启完整链路。
- 动漫搜索直连 Bangumi 修复的运行时结果。
- 弹幕真实播放（缺 DanDanPlay 凭据）。
- Gitee 源码/Release 完整同步。
- 安装器无签名时的 SmartScreen 行为。

---

## 11. 已知问题与待办

优先级从高到低：

1. **安装器复测**：在普通用户桌面运行 `dist\FSYLTV-Setup.exe`，确认解压、安装、快捷方式、卸载入口。若仍 ACL 失败，改用 `%LOCALAPPDATA%\FSYLTV\data\cache\setup` 或用户可写的 `%USERPROFILE%` 临时目录。
2. **自动更新端到端验收**：装 1.0.4，发布 1.0.5，点检查更新，确认下载后不弹“立即安装”、自动替换并重启。
3. **Gitee 镜像**：重试 `git push`，先推源码，再建 Release。网络重置可尝试 `http.postBuffer=524288000`、`http.version=HTTP/1.1`、`--no-thin`。
4. **DanDanPlay 弹幕**：等用户申请 AppId/AppKey；不要把凭据提交到仓库。可用设置页填写，或构建时用 `--dart-define` 注入。
5. **动漫搜索运行时复验**：确认无镜像凭据时请求的是 `api.bgm.tv`，不再出现 401。
6. **影视搜索**：不是 API 缺失，依赖 MoonTV 片源配置；空结果时先检查片源。
7. **安装包签名**：无证书；如需正式分发，购买代码签名证书并签 Setup.exe/fsyl_tv.exe。
8. **云同步**：仅本地骨架，`pull/push` 空实现，不要对外宣称可用。

更完整的构建/运行问题见 [KNOWN-ISSUES.md](KNOWN-ISSUES.md)。

---

## 12. 密钥与安全

- 仓库不得包含 AppId、AppKey、token、Cookie、用户账号数据。
- 弹幕凭据优先让用户在设置页填写；如需构建注入，使用本地未跟踪文件或 CI secrets。
- Gitee token 只通过命令行参数/环境变量传入，不写入 `.git/config`、README、CHANGELOG。
- 发布前检查：

```powershell
git grep -n -E "DANDANAPI_KEY|KAZUMI_KEY|access_token"
```

发现密钥立即撤销并清理历史，不能只删当前文件。

---

## 13. 接手后的最短路径

1. 阅读 [SPEC.md](SPEC.md)、[VENDOR.md](VENDOR.md)、[KNOWN-ISSUES.md](KNOWN-ISSUES.md)。
2. 按第 6 节还原构建环境，确认 `flutter --version`、`node -v`、`pnpm -v`。
3. 跑一次 `tools\package.ps1`，确认本地能生成三个产物。
4. 在普通桌面测试 `FSYLTV-Setup.exe`。
5. 装旧版，发布一个测试版本，验收自动更新。
6. 处理 Gitee 镜像。
7. 等 DanDan 凭据；在此之前不要宣传“弹幕可用”。

---

## 14. 常用命令速查

```powershell
# 分析 Dart
cd app
..\tools\flutter.ps1 analyze

# 构建 Flutter（提权）
powershell -ExecutionPolicy Bypass -File tools\elevated-build.ps1

# 构建 MoonTV
powershell -ExecutionPolicy Bypass -File tools\build-moonserver.ps1

# 打包
powershell -ExecutionPolicy Bypass -File tools\package.ps1

# 发布 GitHub
powershell -ExecutionPolicy Bypass -File tools\publish-release.ps1 -Version 1.0.6

# 发布 Gitee
powershell -ExecutionPolicy Bypass -File tools\publish-gitee.ps1 -Token <token> -Version 1.0.6

# 安装/卸载（开发测试）
powershell -ExecutionPolicy Bypass -File tools\install.ps1
powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1
```

---

## 15. 版本与变更

- 1.0.5：动漫搜索无镜像凭据时直连公开 Bangumi；Setup.exe 安装器；更新自动安装代码。
- 1.0.4：自动安装更新、Setup.exe 打包、Gitee 回退源。
- 1.0.3：Douban 分类主源回退、影视滚轮 JS 兜底。
- 1.0.2：webview 滚轮坐标修复。
- 1.0.1：关于页检查 FSYL Release、规则列表滚动控制器。
- 1.0.0：首个单窗口整合版本。

详细逐文件修改见 [CHANGELOG.md](CHANGELOG.md)。
