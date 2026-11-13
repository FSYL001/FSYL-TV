# KNOWN ISSUES

最后更新：2026-11-13

## 构建环境

1. **ech_http 0.2.4 与 MSVC 的 C2026**
   该依赖把 200 KB CA 证书包放在单个字符串字面量里，MSVC 报 C2026。
   `tools/patch-ech-http.js` 在本地 pub 缓存的 `CMakeLists.txt` 中按证书边界切开
   字面量（运行时字节不变，版本/lockfile 不变）。构建脚本会自动执行；
   重新 `flutter pub get` 后需要再执行一次。

2. **webview_windows 的 NuGet 预构建**
   固定 fork 每次构建都执行 `nuget install`。受限账户读不到 NuGet 的配置/锁文件，
   但包已经还原到 `app\build\windows\x64\packages`。`tools/patch-webview-nuget.js`
   在本地 pub 缓存中跳过“包已存在”时的还原；不升级依赖、不改版本。
   `app\build\flutter_assets` 残留旧 logo 资产导致 errno 183 时，删除该目录再构建。

2. **Flutter 构建需要提权**
   当前开发机的用户令牌没有 `SeCreateSymbolicLinkPrivilege`，Developer Mode
   注册表打开后仍不足。`tools/elevated-build.ps1` 以管理员令牌构建；
   普通用户机器开启 Developer Mode 后可直接构建。

3. **Dart 写入真实 %APPDATA%/%TEMP% 被拒**
   仅出现在当前受限会话。`tools/flutter.ps1` 与 `elevated-build.ps1` 把
   HOME/APPDATA/TEMP/PUB_CACHE 重定向到 `tools\.cache`。不影响安装后的应用。

## 运行时

4. **WebView2 原生 suspend/resume 缺陷**
   固定的 webview_windows fork 中，`suspend()` 会关闭 Graphics Capture item，
   `resume()` 后捕获不恢复，画面定格（用户已复现）。
   当前策略：隐藏时执行 JS 暂停 + `setFpsLimit(1)`，保留捕获会话与页面状态；
   切回后 `setFpsLimit(0)`。实测本应用渲染进程 GPU 从约 20% 降到 0%。
   代价是隐藏期间仍有 1fps 捕获线程；若后续上游修复该 fork，可切回真正的 suspend。

5. **WebView2 环境是进程级单例**
   插件只允许初始化一个 WebView2 environment，因此动漫板块的验证码 WebView 与
   影视 WebView 共用同一个 user data folder（`data\movie`）。两者域名不同，
   localStorage/Cookie 按 origin 隔离，不会跨模块读取记录；但配置/网络状态共享。

6. **影视页切回后视频保持暂停**
   这是需求“切回停在原帧”的结果，不是卡死；页面与 HUD 会继续刷新，
   点击网页内播放按钮可继续播放。

## 功能范围

7. **云同步未实现**：账号页只保存本地配置，`pull/push` 为空实现，不发请求。
8. **安装包未签名**：阶段 8 提供按用户的 PowerShell 安装/卸载脚本与 ZIP，
   没有代码签名证书；Windows SmartScreen 可能提示未知发布者。
9. **Kazumi 引导页默认跳过**：为避免用户可见 Kazumi 品牌，首次启动直接进入首页；
   免责声明、GPL/MIT 许可证与 assets/statements 原文仍随包保留，并在关于页可查。
10. **字体**：默认使用系统字体；MiSans 字体文件与上游许可仍随仓库保留，
    但 FSYL TV 自有素材不使用该字体。
11. **S2 采样精度**：切换测试以约 220ms 间隔抓帧，未覆盖每一帧的 16ms 级残影；
    结论基于 83 帧、0 黑帧、20/20 滚动保持与人工复核。
12. **包体**：便携版/安装版 ZIP 约 146 MB，解压后约 276 MB（Flutter 运行库 +
    node.exe + MoonTV standalone）；未做进一步裁剪。
13. **源码包与提交**：`package.ps1` 用 `git archive HEAD` 生成源码包，因此必须在
    最后一次代码提交之后运行；文档的小改动若未重新打包，源码包内可能是上一版文档，
    但代码与许可证完整。
