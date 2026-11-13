# 开发环境记录（ENVIRONMENT）

记录日期：2026-11-13（Asia/Shanghai）

## 主机

| 项 | 值 |
| --- | --- |
| OS | Windows 11 25H2，build 26200 |
| CPU | 13th Gen Intel Core i9-13980HX |
| 架构 | AMD64 |
| C: 可用空间 | 136.9 GB（开工前） |
| 权限 | 标准用户（Administrators 组为 deny-only），安装机器级组件需 UAC |

## 已就绪

| 组件 | 版本 | 路径 | 验证方式 |
| --- | --- | --- | --- |
| Git | 2.49.0.windows.1 | `C:\Program Files\Git` | `git --version` |
| Node.js | v22.13.0 | `C:\Program Files\nodejs` | `node --version` |
| Corepack | 0.30.0 | 随 Node.js | `corepack --version` |
| WebView2 Runtime | 157.0.4341.46 | 系统级 | 注册表 `HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\pv` |
| PowerShell | 5.1.26100.9444 | 系统 | `$PSVersionTable` |

## 已安装（2026-11-13）

| 组件 | 版本 | 路径 | 验证方式 |
| --- | --- | --- | --- |
| Flutter | 3.50.0 stable（framework `ab2912035e`，Dart 3.14.0） | `tools\.cache\flutter` | `tools\flutter.ps1 --version` |
| Visual Studio Build Tools | 2022 17.14.45（VCTools 工作负载） | `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools` | `flutter doctor -v` → `[√] Visual Studio` |
| MSVC | 14.44.35207 | `...\VC\Tools\MSVC\14.44.35207` | `cl.exe` 存在 |
| Windows SDK | 10.0.26100 | `C:\Program Files (x86)\Windows Kits\10` | `flutter doctor` |
| pnpm | 10.12.4 | `tools\.cache\pnpm-tool` | `pnpm --version` |

安装细节：

- Flutter 官方 zip（1,782 MiB，sha256 `35fb8434…aab8`）解压到 `tools\.cache\flutter`；
  未使用安装器，未升级 SDK。`flutter doctor -v` 结果为：Flutter/Windows/Visual Studio/
  Connected device/Network resources 全部通过（Android 工具链缺失与本项目无关）。
- VS 安装命令（提权）：`vs_installer.exe modify --installPath "...\BuildTools"
  --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --norestart`。
  注意：Build Tools 的 C++ 工作负载 ID 是 `VCTools`，不是 IDE 版的 `NativeDesktop`。
- pnpm 通过 `npm install --prefix tools\.cache\pnpm-tool pnpm@10.12.4` 安装到仓库内，
  避免写入用户级缓存。
- Windows Developer Mode 注册表已置 1（`tools/enable-devmode.ps1`），但当前令牌仍未获得
  `SeCreateSymbolicLinkPrivilege`，因此 **Flutter 构建通过提权 PowerShell 执行**
  （`tools/elevated-build.ps1`）。普通 `flutter build` 会报
  “Building with plugins requires symlink support”。

### 受限环境的构建规避（仅本机）

1. 受限会话的 schannel 不可用，git 使用 `http.sslBackend=openssl`，下载使用
   `tools/download.js`（Node TLS）。
2. Dart/Flutter 进程无法写真实 `%APPDATA%`/`%TEMP%`，`tools/flutter.ps1` 与
   `tools/elevated-build.ps1` 把它们重定向到 `tools\.cache\home`、`tools\.cache\temp`。
3. `ech_http 0.2.4` 把 200 KB CA 证书包放进单个字符串字面量，MSVC 报 C2026。
   `tools/patch-ech-http.js` 在本地 pub 缓存内按证书边界拆分该字面量（不改变版本、
   lockfile 或运行内容），每次构建前自动执行。此补丁仅影响本机构建环境，不进入仓库代码。

## 最终验证

- `flutter doctor -v`：Flutter 3.50.0、Windows 11、Visual Studio、Connected device、
  Network resources 均通过；Android 工具链缺失（本项目不需要）。
- `flutter build windows --release`：成功，产物
  `app\build\windows\x64\runner\Release\kazumi.exe`（多次增量构建 45–147 秒）。
- `flutter test test\shell\moon_sidecar_test.dart`：All tests passed。
- `flutter test test\shell\account_service_test.dart`：All tests passed（DPAPI 往返解密）。
- `pnpm build`（MoonTV）与 `pnpm typecheck`：exit 0。
- 应用运行：无未捕获异常；数据目录为
  `config/ account/ anime/ movie/ cache/ logs/`，WebView2 生成 `data\movie\EBWebView`。

## 打包产物（阶段 8）

- `dist\FSYLTV-portable.zip`：约 152.8 MB；解压后约 277 MB。
- `dist\FSYLTV-Setup.zip`：约 152.8 MB；`install.ps1` 按用户安装。
- `source\FSYLTV-source.zip`：34,557,174 bytes（`git archive HEAD`）。
- 安装版验证：sidecar 从 `%LOCALAPPDATA%\FSYLTV\app\moon` 启动并打印
  `FSYLTV_READY 8466`；`uninstall.ps1` 保留 data 后程序与快捷方式均移除。
