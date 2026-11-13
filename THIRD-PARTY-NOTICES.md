# 第三方组件与许可证声明（THIRD-PARTY NOTICES）

FSYL TV 整体以 GPL-3.0 发布（见 `LICENSE`）。本文件列出主要上游项目、固定版本、
许可证与使用方式。所有上游版权声明、LICENSE 与免责声明均保留在原位，不因品牌改造删除。

## 1. 核心上游

### Kazumi

- 来源：https://github.com/Predidit/Kazumi
- 固定 commit：`4ca04009fdae696883629e0984e7d7134cc7ed84`（version 2.4.4）
- 许可证：GNU General Public License v3.0
- 使用方式：`app/` 为其 Flutter 工程，保留播放器、规则引擎与抓取逻辑；仅做外壳接入、
  品牌替换与路径注入（每处修改见 `CHANGELOG.md`）。
- 许可证原文：`app/LICENSE`、根目录 `LICENSE`。

### MoonTV

- 来源：https://github.com/samqin123/MoonTV
- 固定 commit：`c0bba763d16fb5cd830a808d58329025337491cf`
- 许可证：MIT（Copyright (c) 2025 senshinya）
- 使用方式：`moonserver/` 作为本地 sidecar 运行，WebView2 内嵌显示；仅新增健康检查、
  就绪握手与退出接口等外壳适配（每处修改见 `CHANGELOG.md`）。
- 许可证原文：`moonserver/LICENSE`、根目录 `LICENSE-MOONTV-MIT`。

## 2. 运行时与构建工具

| 组件 | 版本 | 许可证 | 说明 |
| --- | --- | --- | --- |
| Flutter | 3.50.0 stable | BSD-3-Clause | 动漫板块 UI/播放器运行时 |
| Dart | Flutter 3.50.0 内置 | BSD-3-Clause | 应用逻辑 |
| Node.js | 22.13.0（LTS） | MIT 及若干第三方许可证 | 运行 MoonTV sidecar（打包时复制 `node.exe`） |
| Microsoft Edge WebView2 Runtime | 157.0.4341.46 | Microsoft 专有许可 | 影视板块渲染，作为系统依赖安装，不随仓库分发 |
| Next.js | 14.x（随 MoonTV 锁定） | MIT | MoonTV Web 服务 |
| React / React DOM | 18.x（随 MoonTV 锁定） | MIT | MoonTV UI |
| pnpm | 由项目锁定 | MIT | MoonTV 包管理 |

## 3. 主要库（由两个上游的 lockfile 固定）

- Kazumi 侧：`media_kit` / `media_kit_video`（MIT，内置 libmpv 按其构建选项适用
  LGPL-2.1+ 或 GPL-2.0+）、`webview_windows`（MIT）、`hive_ce`（Apache-2.0）、
  `flutter_modular`（MIT）、`dio`（MIT）等。完整依赖与版本见 `app/pubspec.lock`。
- MoonTV 侧：`hls.js`（Apache-2.0）、`artplayer`（MIT）、`vidstack`（MIT）、
  `tailwindcss`（MIT）、`next-pwa`（MIT）等。完整依赖与版本见
  `moonserver/pnpm-lock.yaml`。

各依赖的完整许可证文本随其软件包或 `licenses/` 目录提供；本项目不放宽、不删除
任何上游许可证或版权声明。

## 4. 字体与素材

- 上游 Kazumi 自带 MiSans 字体仅作为上游资源保留；FSYL TV 自有界面素材（阶段 6）
  独立设计，不使用其 logo。
- 本项目新增图标与界面图形为原创，不使用上游商标作为本项目标识。

## 5. 免责声明

本项目仅作为本地客户端整合上游开源软件，不提供、不托管、不分发任何影视内容。
使用者应遵守所在地法律法规及内容来源的服务条款。上游项目各自的免责声明原文
保持不变，例如 `app/assets/statements/` 下的文本。
