# CHANGELOG

本文件记录 **对上游文件的每一处修改**（GPL-3.0 §5(a) 要求），格式：

```
YYYY-MM-DD | 文件路径 | 修改内容
```

只记录对 `app/`（Kazumi）与 `moonserver/`（MoonTV）内上游文件的改动；
本项目新增文件不在此列，但仍会通过 git 历史公开。

## 记录

- 2026-11-13 | `moonserver/src/middleware.ts` | 新增 `FSYLTV_LOCAL_MODE` 本机无密码放行（仅 localhost）；
  跳过 `/api/health` 与 `/__shutdown` 的登录校验。未设置该变量时行为与上游一致。
- 2026-11-13 | `moonserver/src/app/layout.tsx` | 站点名优先读取 `NEXT_PUBLIC_SITE_NAME`，其次
  `SITE_NAME`，最后回退 `MoonTV`。
- 2026-11-13 | `moonserver/src/lib/config.ts` | 同上，4 处站点名读取增加 `NEXT_PUBLIC_SITE_NAME` 优先级。
- 2026-11-13 | `moonserver/next.config.js` | 新增 rewrite：`POST /__shutdown` → `/api/shutdown`
  （Next App Router 不接受 `_` 开头的路由目录）。

新增文件（非上游修改，列出以便审计）：

- `moonserver/src/app/api/health/route.ts`：健康检查。
- `moonserver/src/app/api/shutdown/route.ts`：优雅退出。
- `tools/moon/server-wrapper.js`：sidecar 入口包装，打印 `FSYLTV_READY <port>`。
- `tools/download.js`、`tools/flutter.ps1`、`tools/enable-devmode.ps1`：构建环境辅助。
- `app/lib/shell/*`（阶段 3 起）：单窗口外壳。

### 动漫板块（app/）上游文件修改

- 2026-11-13 | `app/lib/main.dart` | 启动时初始化 AppPaths；Hive 根目录改为 `data\anime\hive`；
  窗口标题改为 FSYL TV、无边框标题栏、按配置恢复窗口尺寸、最小尺寸 980×640。
- 2026-11-13 | `app/lib/app_widget.dart` | MaterialApp.router 增加 builder，用 `FsylShell` 包裹
  整个 Navigator（两个板块常驻、启动页与切换器）；标题改为 FSYL TV。
- 2026-11-13 | `app/lib/pages/player/player_controller.dart` | 订阅 `ShellBridge.animeActive`：
  切到影视时暂停当前播放器（不自动恢复）；dispose 时移除监听。未修改播放器内部逻辑。
- 2026-11-13 | `app/lib/services/storage/storage.dart` | Hive 路径改为 `AppPaths.animeDir/hive`；
  backupBox 使用同一路径。移除 path_provider 依赖点。
- 2026-11-13 | `app/lib/services/logging/logger.dart` | 日志目录改为 `AppPaths.logsDir`。
- 2026-11-13 | `app/lib/services/shaders/shader_asset_service.dart` | 着色器缓存改为
  `AppPaths.cacheDir/anime_shaders`。
- 2026-11-13 | `app/lib/services/network/proxy_aware_image_cache_manager.dart` | 图片缓存文件系统
  改为 `AppPaths.cacheDir/images`。
- 2026-11-13 | `app/lib/services/storage/image_cache_service.dart` | 缓存统计路径与上面一致。
- 2026-11-13 | `app/lib/services/sync/webdav.dart` | WebDAV 临时目录改为 `data\cache\webdavTemp`；
  Hive 文件路径改为 `data\anime\hive`。
- 2026-11-13 | `app/lib/services/sync/history_sync_service.dart` | 本地目录提供者改为 `data\anime`。
- 2026-11-13 | `app/lib/utils/file_system.dart` | 默认下载目录改为 `data\anime\downloads`。
- 2026-11-13 | `app/lib/utils/media.dart` | 播放器临时目录改为 `data\cache\player`。
- 2026-11-13 | `app/lib/services/update/auto_updater.dart` | 更新包临时目录改为 `data\cache\update`。
- 2026-11-13 | `app/lib/plugins/plugins_controller.dart` | 规则插件目录改为 `data\anime\plugins`。
- 2026-11-13 | `app/lib/pages/logs/logs_page.dart` | 日志页读取 `data\logs\kazumi_logs.log`。
- 2026-11-13 | `app/lib/pages/error/storage_error_page.dart` | 错误页显示 AppPaths 数据根，
  不再调用 path_provider。
- 2026-11-13 | `app/lib/services/network/proxy_aware_image_cache_manager.dart` | 图片缓存
  fileSystem 固定到 `data\cache\images`，元数据仓库改为同目录 JSON 文件。
- 2026-11-13 | `app/lib/services/storage/settings_keys.dart` | `useSystemFont` 默认值改为
  true，FSYL TV 默认不使用 MiSans。
- 2026-11-13 | `app/lib/main.dart` | 首次启动默认跳过 Kazumi 引导页与桌面快捷方式弹窗
  （避免用户可见 Kazumi 品牌；许可证与免责声明仍在关于页与 assets/statements 保留）。
- 2026-11-13 | `app/lib/pages/about/about_page.dart` | 关于页改为 FSYL TV，新增上游
  Kazumi/MoonTV 链接、许可证、完整源码入口与“基于其修改而来”声明。
- 2026-11-13 | `app/lib/pages/index_module.dart` | 错误页标题 Kazumi → FSYL TV。
- 2026-11-13 | `app/lib/pages/init_page.dart` | 桌面快捷方式文案 Kazumi → FSYL TV。
- 2026-11-13 | `app/lib/services/platform/tray_service.dart` | 托盘提示与退出菜单
  Kazumi → FSYL TV。
- 2026-11-13 | `app/lib/pages/settings/settings_module.dart` | 新增 `/settings/account`
  路由；许可证页应用名改为 FSYL TV。
- 2026-11-13 | `app/lib/pages/settings/sync/sync_settings_page.dart` | 新增“账号与云同步”
  卡片（本地离线模式）。
- 2026-11-13 | `app/windows/runner/main.cpp` | 窗口标题改为 FSYL TV（内部类名/mutex 不变）。
- 2026-11-13 | `app/windows/runner/Runner.rc` | 文件描述、产品名、原始文件名改为 FSYL TV /
  fsyl_tv.exe。
- 2026-11-13 | `app/assets/images/logo/*`、`app/windows/runner/resources/app_icon.ico` |
  替换为 `tools/make_icons.py` 生成的 FSYL TV 原创图标（不再使用 Kazumi logo）。
- 2026-11-13 | `moonserver/public/logo.png`、`favicon.ico`、`icons/icon-*.png` | 替换为
  FSYL TV 图标。
- 2026-11-13 | `moonserver/public/__s1.html`、`__s2.html` | 新增阶段 1 验证用测试页
  （不影响正式页面与路由）。

阶段 7 新增文件（不修改上游行为）：

- `app/lib/shell/account/account_service.dart`、`dpapi.dart`
- `app/lib/shell/sync/sync_adapter.dart`
- `app/lib/pages/settings/sync/account_sync_page.dart`
- `app/test/shell/account_service_test.dart`
- `moonserver/src/lib/sync/{types,envelope,adapter}.ts`、`README.md`

阶段 8 新增工具：

- `tools/build-moonserver.ps1`、`tools/package.ps1`、`tools/install.ps1`、
  `tools/uninstall.ps1`、`tools/make_icons.py`、`tools/patch-ech-http.js`、
  `tools/analyze_s2.py`、`tools/elevated-build.ps1`、`tools/flutter.ps1`、
  `tools/enable-devmode.ps1`、`tools/download.js`、`tools/fake-sidecar/server.js`。
