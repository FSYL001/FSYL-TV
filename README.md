# FSYL TV

FSYL TV 是一个 Windows 单窗口桌面客户端，在同一个窗口内整合两个独立板块：

- **影视**：基于 [MoonTV](https://github.com/samqin123/MoonTV)（MIT）改造，本地 Node sidecar + WebView2 呈现，播放器就是 MoonTV 网页自带的播放器。
- **动漫**：基于 [Kazumi](https://github.com/Predidit/Kazumi)（GPL-3.0）改造，保留其播放器、规则引擎与抓取逻辑。

两个板块的观看记录、收藏与播放器完全独立，数据全部保存在本机，不依赖任何自建服务器。

## 功能

- 启动页选择「影视 / 动漫」，进入后顶部胶囊随时切换，约 200ms 过渡。
- 两个板块常驻 `IndexedStack`，切换不销毁页面；影视 WebView2 以 Flutter Texture 合成，不是额外子窗口。
- 切走时暂停另一侧音视频并把影视捕获帧率降到 1fps；切回停在原帧。
- 无边框窗口 + 自绘标题栏，窗口尺寸/位置/上次板块持久化，可最小化/隐藏到托盘。
- 影视 sidecar 由外壳启动：空闲端口、`FSYLTV_READY` 握手、健康检查、优雅退出、Job Object 防孤儿进程；崩溃可单独重启影视模块。
- 关于页包含上游项目、仓库、许可证、完整源码入口。

## 运行

安装版：解压 `FSYLTV-Setup.zip`，运行 `install.ps1`（按用户安装，无需管理员）。
程序位于 `%LOCALAPPDATA%\FSYLTV\app`，数据位于 `%LOCALAPPDATA%\FSYLTV\data`。

便携版：解压 `FSYLTV-portable.zip`，直接运行 `FSYLTV\fsyl_tv.exe`。便携版同样把数据写到
`%LOCALAPPDATA%\FSYLTV\data`（不会在程序目录产生可写文件）。

开发运行：

```powershell
tools\flutter.ps1 pub get
# Flutter 构建需要符号链接权限，当前开发机通过提权脚本构建：
tools\elevated-build.ps1
```

## 数据目录

```
%LOCALAPPDATA%\FSYLTV\app\       程序（升级整体替换）
%LOCALAPPDATA%\FSYLTV\data\      唯一可写区（升级不触碰）
  config\ account\ anime\ movie\ cache\ logs\
```

详见 [SPEC.md](SPEC.md)。卸载时会询问是否保留 `data`。

## 构建

环境要求：Flutter 3.50.0、VS 2022 Build Tools（VCTools 工作负载）、
Node.js 22 LTS、pnpm 10.12.4、WebView2 Runtime。

```powershell
# 1) 影视 sidecar -> app\moon（先确保 pnpm 依赖已安装）
powershell -ExecutionPolicy Bypass -File tools\build-moonserver.ps1

# 2) Flutter release（需要管理员令牌/Developer Mode）
powershell -ExecutionPolicy Bypass -File tools\elevated-build.ps1

# 3) 便携版 + 安装版 + 源码包（请在 git commit 之后运行）
powershell -ExecutionPolicy Bypass -File tools\package.ps1
```

产物在 `dist\`：`FSYLTV-windows-portable.zip`、`FSYLTV-windows-setup.zip`。
`source\FSYLTV-source.zip` 是 GPL-3.0 要求的完整源码存档（`git archive HEAD`）。

## 发布与应用内更新

应用内更新读取 GitHub Release：<https://github.com/FSYL001/FSYL-TV/releases>。
发布新版本：

1. 修改 `app/lib/shell/app_version.dart` 的 `current`（例如 `1.0.1`）并提交；
2. 运行 `powershell -ExecutionPolicy Bypass -File tools\publish-release.ps1 -Version 1.0.1`；
3. 脚本会打 tag、推送、打包并创建带 `FSYLTV-windows-portable.zip` 的 Release。

启动时会自动检查（可在“更新设置”关闭）；“关于 → 检查更新”可手动检查，
下载完成后点“立即安装”，应用会退出并由更新脚本替换文件后重启。
更新只覆盖程序目录，`%LOCALAPPDATA%\FSYLTV\data` 不受影响。

## 许可证与源码

本项目整体以 **GNU General Public License v3.0** 发布，完整文本见 [LICENSE](LICENSE)。

- 动漫板块来源于 Kazumi（GPL-3.0），固定 commit `4ca04009fdae696883629e0984e7d7134cc7ed84`，
  仓库：https://github.com/Predidit/Kazumi 。本项目基于其修改而来。
- 影视板块来源于 MoonTV（MIT），固定 commit `c0bba763d16fb5cd830a808d58329025337491cf`，
  仓库：https://github.com/samqin123/MoonTV ，原始许可证见 [LICENSE-MOONTV-MIT](LICENSE-MOONTV-MIT)。
- 完整源码随安装包 `source\FSYLTV-source.zip` 提供；本仓库保留上游 LICENSE、版权头与
  第三方许可文本，未删除任何免责声明。
- 对上游文件的每一处修改见 [CHANGELOG.md](CHANGELOG.md)；来源与 SHA 见 [VENDOR.md](VENDOR.md)；
  第三方组件见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

本项目仅作为本地客户端整合上游开源软件，不提供、不托管、不分发任何影视内容。

## 已知问题

见 [KNOWN-ISSUES.md](KNOWN-ISSUES.md)（WebView2 suspend 缺陷、构建提权、
无签名安装包、云同步仅骨架等）与 [PROGRESS.md](PROGRESS.md)（各阶段真实验收数据）。
