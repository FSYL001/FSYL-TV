# FSYL TV

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Platform: Windows 10/11](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4.svg)](https://github.com/FSYL001/FSYL-TV/releases)
[![Latest release](https://img.shields.io/github/v/release/FSYL001/FSYL-TV)](https://github.com/FSYL001/FSYL-TV/releases/latest)

FSYL TV 是一个面向 Windows 的**本地双板块桌面客户端**，在同一个窗口内提供两个相互独立的入口：

- **影视**：基于 [MoonTV](https://github.com/samqin123/MoonTV)（MIT）构建，使用本地 Node.js sidecar 提供页面，WebView2 负责呈现与播放。
- **动漫**：基于 [Kazumi](https://github.com/Predidit/Kazumi)（GPL-3.0）构建，保留其播放器、规则引擎与抓取逻辑。

FSYL TV 本身不提供、不托管、不分发任何影视资源。影视内容来自用户自行配置的第三方片源接口；动漫内容来自用户导入的规则与第三方站点。所有观看记录、收藏和账号配置默认仅保存在本机。

> 本项目是社区整合项目，与 Kazumi、MoonTV、豆瓣、DanDanPlay 等上游项目或服务没有隶属关系。

## 目录

- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [下载与安装](#下载与安装)
- [使用说明](#使用说明)
- [数据目录](#数据目录)
- [项目结构](#项目结构)
- [从源码构建](#从源码构建)
- [应用内更新](#应用内更新)
- [发布流程](#发布流程)
- [常见问题](#常见问题)
- [许可证与致谢](#许可证与致谢)
- [安全与贡献](#安全与贡献)
- [免责声明](#免责声明)

## 功能特性

| 功能 | 说明 |
| --- | --- |
| 单窗口双板块 | 动漫与影视为同一窗口内的两个常驻页面，顶部胶囊切换，不打开第二个界面进程 |
| 独立播放器 | 动漫使用 Kazumi 原有 media_kit 播放器；影视使用 MoonTV 网页自带播放器，互不复用 |
| 独立记录 | 两个板块的观看记录、收藏、配置互不读取，仅共享“上次停留板块”这一项外壳偏好 |
| 影视 sidecar | 自动选择空闲端口，stdout 握手，健康检查，优雅关闭，崩溃后可单独重启影视模块 |
| 无边框窗口 | 自绘标题栏，支持最大化、全屏、最小化到托盘、窗口位置持久化 |
| 本机数据 | 所有可写数据集中在 `%LOCALAPPDATA%\FSYLTV\data`，升级不覆盖 |
| 应用内更新 | 检查 GitHub Release，GitHub 不可用时回退 Gitee；便携包下载完成后自动解压替换并重启 |
| 开源合规 | 保留上游许可证、版权声明与免责声明；对上游文件的修改逐条记录 |

## 系统要求

- Windows 10 22H2 或 Windows 11（x64）
- [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)（Windows 11 通常已预装）
- 安装/便携版约 150 MB，安装后约 280 MB
- 安装脚本按当前用户安装，不需要管理员权限

影视板块需要一个本地 Node.js sidecar，发布包已经内置 `node.exe` 与 MoonTV standalone，不要求用户另装 Node.js。

## 下载与安装

从 [GitHub Releases](https://github.com/FSYL001/FSYL-TV/releases/latest) 下载最新版本：

| 文件 | 用途 |
| --- | --- |
| `FSYLTV-Setup.exe` | 推荐。安装器会复制程序到 `%LOCALAPPDATA%\FSYLTV\app`，创建开始菜单/桌面快捷方式 |
| `FSYLTV-windows-portable.zip` | 便携版。解压后运行 `FSYLTV\fsyl_tv.exe`，数据仍写入 `%LOCALAPPDATA%\FSYLTV\data` |
| `FSYLTV-windows-setup.zip` | 免 EXE 的安装脚本包，解压后运行 `install.ps1` |
| `source\FSYLTV-source.zip` | 包内附带的完整源码存档（GPL-3.0 合规），位于安装/便携目录的 `source` 子目录 |

> 当前安装包没有代码签名证书。Windows SmartScreen 可能提示“未知发布者”，请核对下载来源与 Release 校验信息后再运行。

卸载使用开始菜单中的卸载入口，或运行安装目录下的 `uninstall.ps1`。卸载时会询问是否保留 `data`。

## 使用说明

### 切换板块

启动时选择影视或动漫，进入后使用窗口顶部中央的胶囊切换。两个板块保持常驻，切换不会销毁页面或丢失播放位置。

- 切走时，另一侧的音频会暂停并静音；影视捕获帧率降到 1 fps，切回恢复。
- 影视切回后视频保持暂停，点击网页内播放按钮继续，这是为避免后台继续播放而设计的。
- 全屏时标题栏自动隐藏，按 Esc 或退出全屏后恢复。

### 动漫搜索

动漫搜索使用 Bangumi 公开 API。若未配置 Kazumi 镜像凭据，客户端会直接访问 `api.bgm.tv`，不需要申请 API Key。

搜索结果中的片源来自导入的规则站点；站点被墙、触发反爬或规则失效时，会出现“搜索无结果/网络异常”，这与 Bangumi 搜索本身无关。

### 影视片源

影视首页、搜索和播放依赖 MoonTV 的片源配置。首次使用需要在 MoonTV 管理入口中填写可用的片源 API；本项目不内置、不推荐、不保证任何第三方片源。

### 弹幕

弹幕使用 DanDanPlay 开放接口。由于官方接口要求应用级签名，本项目**不内置** DanDanPlay 的 AppId/AppKey。需要弹幕时：

1. 在 <https://doc.dandanplay.com/open/> 申请 AppId 与 AppKey；
2. 打开“设置 → 弹幕设置 → 弹幕 API 凭证”填写并保存；
3. 重新进入播放页。

只有在获得有效凭据后，弹幕接口才会返回数据。没有凭据时播放器仍可正常播放，只是没有弹幕。

## 数据目录

所有运行时可写数据都在一个根目录下：

```text
%LOCALAPPDATA%\FSYLTV\
├─ app\                         程序本体（升级时整体替换）
│  ├─ fsyl_tv.exe
│  └─ moon\                     MoonTV sidecar（node.exe + server）
└─ data\                        唯一可写区（升级不触碰）
   ├─ config\                   窗口、应用、设备配置
   ├─ account\                  DPAPI 加密的账号/token
   ├─ anime\                    动漫 Hive、播放器数据
   ├─ movie\                    影视 WebView2 user data folder
   ├─ cache\                    缓存
   └─ logs\                     shell.log、moon.log、anime.log 等
```

删除 `data` 会清空本地记录；删除前请先退出应用。便携版也不会把可写文件写到程序目录，因此可以放在只读目录运行。

更完整的目录、进程、端口与生命周期契约见 [SPEC.md](SPEC.md)。

## 项目结构

```text
.
├─ app/                         Flutter Windows 客户端（Kazumi 上游 + FSYL 外壳）
│  ├─ lib/shell/                单窗口外壳、影视 WebView、sidecar、更新、退出流程
│  ├─ lib/pages/                Kazumi 页面（搜索、番剧、播放器、设置、关于）
│  ├─ lib/services/             网络、存储、更新、播放等服务
│  └─ assets/rules/             随包内置的初始规则
├─ moonserver/                  MoonTV（Next.js standalone，MIT）
├─ tools/                       构建、打包、发布、安装、补丁脚本
├─ SPEC.md                      运行时契约
├─ VENDOR.md                    上游来源、固定 commit 与导入记录
├─ CHANGELOG.md                 对上游文件的逐项修改记录
├─ KNOWN-ISSUES.md              已知问题
├─ HANDOVER.md                  维护者交接文档
└─ dist/                        本地打包产物（不提交）
```

## 从源码构建

### 环境

| 工具 | 版本/要求 |
| --- | --- |
| Flutter | 3.50.0 stable（Dart 3.14） |
| Visual Studio | 2022 Build Tools，安装“使用 C++ 的桌面开发” |
| Node.js | 22.x（当前验证 22.13.0） |
| pnpm | 10.12.4 |
| WebView2 | Evergreen Runtime |
| PowerShell | Windows PowerShell 5.1 或 PowerShell 7 |
| .NET Framework | 4.8（仅打包 `FSYLTV-Setup.exe` 时需要 `csc.exe`） |

依赖版本已锁定。**不要升级 Flutter、pub 依赖、Node/pnpm 或 webview_windows fork 的 commit**；升级会改变播放器/抓取行为，并可能破坏 GPL 合规记录。

### 1. 获取源码

```powershell
git clone https://github.com/FSYL001/FSYL-TV.git
cd FSYL-TV
```

`app/fastlane` 下的两个 gitlink 只用于 Android/fastlane，Windows 构建不需要初始化。

### 2. 安装依赖

```powershell
cd app
..\tools\flutter.ps1 pub get --enforce-lockfile
cd ..\moonserver
pnpm install --frozen-lockfile
cd ..
```

当前开发机的受限环境还需要执行本地补丁（正常桌面环境通常不需要）：

```powershell
node tools\patch-ech-http.js
node tools\patch-webview-nuget.js
node tools\patch-webview-scroll.js
```

这些脚本只修改本地 pub 缓存中的构建文件，不修改依赖版本或 lockfile。

### 3. 构建

```powershell
# 影视 sidecar -> build\moon
powershell -ExecutionPolicy Bypass -File tools\build-moonserver.ps1

# Flutter release。Windows 符号链接权限不足时使用提权脚本
powershell -ExecutionPolicy Bypass -File tools\elevated-build.ps1
```

构建产物：`app\build\windows\x64\runner\Release\kazumi.exe`（打包时重命名为 `fsyl_tv.exe`）。

### 4. 打包

**先提交代码**，因为 GPL 源码包使用 `git archive HEAD` 生成：

```powershell
powershell -ExecutionPolicy Bypass -File tools\package.ps1
```

输出：

```text
dist\FSYLTV-Portable\FSYLTV\          便携版目录
dist\FSYLTV-Setup\                    安装目录与 payload
dist\FSYLTV-windows-portable.zip      便携版 ZIP
dist\FSYLTV-windows-setup.zip         安装脚本 ZIP
dist\FSYLTV-Setup.exe                 EXE 安装器
```

`FSYLTV-Setup.exe` 是一个小型 C# 引导器，尾部附加 `FSYLTV-windows-setup.zip`；运行后解压到 `%LOCALAPPDATA%\FSYLTV\setup-temp`，调用 `install.ps1`，完成后清理临时目录。

## 应用内更新

应用启动后会按设置自动检查更新；“关于 → 检查更新”也可以手动检查。

更新流程：

1. 读取 GitHub Releases API（`FSYL001/FSYL-TV`）；
2. GitHub 不可用时回退 Gitee Releases；
3. 选择 Windows 便携包并下载到 `%LOCALAPPDATA%\FSYLTV\data\cache\update`；
4. Windows 便携版下载完成后**自动**解压、替换程序目录并重启，不再停在“下载完成”弹窗；
5. `%LOCALAPPDATA%\FSYLTV\data` 不受影响。

升级前请确认没有正在播放的视频；更新脚本会等待旧进程退出后再覆盖文件。若自动替换失败，应用会提示错误，原程序仍可继续使用。

> 自动安装逻辑从 1.0.4 起提供。更早版本只能下载 ZIP，需要手动运行安装器。

## 发布流程

### GitHub

1. 修改 `app/lib/shell/app_version.dart` 的 `current`，同步更新 `CHANGELOG.md`；
2. 提交全部改动，保持工作区干净；
3. 运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\publish-release.ps1 -Version 1.0.6
```

脚本会校验版本号、打 tag、推送 `main`、调用 `package.ps1`、创建 GitHub Release 并上传产物。

> 当前 `publish-release.ps1` 的资产列表仍以 ZIP 为主；发布 `FSYLTV-Setup.exe` 时需确认脚本已包含该文件，或手工补传到 Release。

### Gitee 镜像

仓库地址：<https://gitee.com/FSYL001/FSYL-TV>（源码镜像，可能同步滞后；Release 以 GitHub 为准）

镜像推送需要 Gitee 私人访问令牌（`projects` 权限）：

```powershell
powershell -ExecutionPolicy Bypass -File tools\publish-gitee.ps1 -Token <token> -Version 1.0.6
```

脚本只在本地使用令牌，不写入仓库。Gitee 对单文件大小和网络稳定性有限制，发布大体积 ZIP 时可能失败；Release 以 GitHub 为准。

## 常见问题

### 动漫搜索没有结果？

先确认 Bangumi 网络是否可访问。没有 Kazumi 镜像凭据时客户端会自动直连 `api.bgm.tv`；如果 Bangumi 正常但仍无结果，通常是规则站点被墙、反爬或规则失效，可在“设置 → 规则管理”更新/导入规则。

### 影视首页提示“获取豆瓣分类数据失败”？

客户端会优先请求 `movie.douban.com/j/search_subjects`，失败时回退旧接口。若两者都失败，说明当前网络无法访问豆瓣；数据接口不提供 API Key，也不是配置问题。

### 影视搜索为空？

影视搜索使用 MoonTV 中配置的片源 API，不是全局搜索引擎。请先在 MoonTV 管理入口添加可用片源；本项目不内置片源。

### 弹幕 403？

需要 DanDanPlay AppId/AppKey。见[弹幕](#弹幕)。

### 更新下载了 ZIP 但没安装？

1.0.4 之前的版本不会自动安装；请运行 Release 中的 `FSYLTV-Setup.exe` 升级一次。1.0.4 及之后会自动替换并重启。

### 安装时 SmartScreen 拦截？

安装包未签名。可点击“更多信息 → 仍要运行”，或使用便携版。请只从本仓库 Release 下载。

## 许可证与致谢

本项目整体以 **GNU General Public License v3.0** 发布，完整文本见 [LICENSE](LICENSE)。

### 上游项目

| 项目 | 许可证 | 固定版本 | 用途 |
| --- | --- | --- | --- |
| [Kazumi](https://github.com/Predidit/Kazumi) | GPL-3.0 | `4ca04009fdae696883629e0984e7d7134cc7ed84` | 动漫板块、播放器、规则引擎 |
| [MoonTV](https://github.com/samqin123/MoonTV) | MIT | `c0bba763d16fb5cd830a808d58329025337491cf` | 影视板块、网页播放器 |

- 上游 LICENSE、版权头、免责声明均保留；MIT 原文见 [LICENSE-MOONTV-MIT](LICENSE-MOONTV-MIT)。
- 来源、tree hash 与导入方式见 [VENDOR.md](VENDOR.md)。
- 对上游文件的修改逐条记录在 [CHANGELOG.md](CHANGELOG.md)。
- 第三方组件与许可见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
- 每个安装包内都包含 `source\FSYLTV-source.zip`，对应发布提交的完整源码。

### 特别说明

FSYL TV 只是把两个独立开源项目整合到同一个 Windows 外壳中：

- 没有修改或替换动漫板块的播放器、规则引擎和抓取逻辑；
- 没有修改或替换影视板块的网页播放器；
- 没有把任何一方的观看记录、收藏或播放器实例暴露给另一方；
- 没有删除任何上游版权声明或免责声明。

## 安全与贡献

### 报告问题

请使用 [GitHub Issues](https://github.com/FSYL001/FSYL-TV/issues) 报告可复现的缺陷。涉及令牌、账号、未公开安全问题，请使用 GitHub Security Advisory，不要在公开 Issue 中粘贴密钥。

### 提交 PR

- 不要提交任何 AppId、AppKey、token、Cookie 或用户数据；
- 不要随意升级依赖或修改 git 依赖 commit；
- 修改上游文件时，在 `CHANGELOG.md` 增加一行记录；
- 保留 GPL/MIT 许可证、版权头与免责声明；
- 涉及影视/动漫模块边界时，先阅读 [SPEC.md](SPEC.md)。

## 免责声明

本网站 / APP 仅提供影视信息搜索服务，所有内容均来自第三方网站。本站不存储任何视频资源，不对任何内容的准确性、合法性、完整性负责。仅供交流学习 ！

本项目按“现状”提供，不提供任何明示或暗示担保。使用者应自行确认所在地区法律法规及第三方服务条款，并对自己的使用行为负责。

## 维护者文档

- [SPEC.md](SPEC.md)：运行时契约
- [HANDOVER.md](HANDOVER.md)：交接清单、构建/发布细节、已知风险
- [KNOWN-ISSUES.md](KNOWN-ISSUES.md)：已知问题
- [PROGRESS.md](PROGRESS.md)：各阶段验收记录
- [CHANGELOG.md](CHANGELOG.md)：上游文件修改记录
