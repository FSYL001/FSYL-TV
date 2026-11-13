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

## 下载与安装计划

| 组件 | 状态 | 版本/来源 | 说明 |
| --- | --- | --- | --- |
| Flutter | 已下载，待解压 | 3.50.0 stable | `flutter_windows_3.50.0-stable.zip`（1,782 MiB，sha256 `35fb843409c80a1c69b64bbae1756bba437222f909622d83540e266e1759aab8`），来自 storage.googleapis.com 官方发布 |
| pnpm | 待激活 | 由 `packageManager`/lockfile 决定 | `corepack prepare pnpm@<版本> --activate` |
| VS 2022 Build Tools | 待安装 | NativeDesktop 工作负载 + 推荐组件 | 安装器需提权，见下方说明 |

### 网络限制与替代路径

受限会话中的 schannel 不可用：

```
curl: (35) schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS (0x8009030e)
```

实测可用路径：

- git 网络操作：`git -c http.sslBackend=openssl ...`（或在仓库内设置 `http.sslBackend=openssl`）。
- 下载：`node tools/download.js <url> <dest> [sha256]`，走 Node.js/OpenSSL。
- 只读网页探测：harness 的 web_fetch。

## 待补记录

Flutter 解压与 `flutter doctor -v`、pnpm 激活、VS Build Tools 安装与验证输出，
将在完成对应安装后追加到本文件。
