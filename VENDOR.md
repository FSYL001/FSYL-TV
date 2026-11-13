# 上游来源与导入记录（VENDOR）

导入日期：2026-11-13

## 1. Kazumi → `app/`

| 项 | 值 |
| --- | --- |
| 仓库 | https://github.com/Predidit/Kazumi.git |
| 分支 | `main` |
| 上游 commit | `4ca04009fdae696883629e0984e7d7134cc7ed84`（version 2.4.4） |
| 上游 tree | `2b51c43cd94f436da10de024a848d6788b5cc84d` |
| 许可证 | GPL-3.0（原文见 `LICENSE` 与 `app/LICENSE`） |
| 本地 tree（验收） | `git rev-parse HEAD:app` → `2b51c43cd94f436da10de024a848d6788b5cc84d` |

子模块（未初始化，仅保留 gitlink，与上游 tree 一致）：

- `app/fastlane/.flutter` → Flutter `ab2912035e160d9cad6306df307576da6128ebdb`
- `app/fastlane/.libmpv-android-video-build` → `0443048272a511d7a990a2a3d5ca6bbaf55a869a`

这两个子模块只服务于 Android/fastlane 构建，Windows 构建不需要其工作区内容；
gitlink 的 SHA 已随 tree 导入，因此 `app/` 的 tree hash 与上游完全一致。

## 2. MoonTV → `moonserver/`

| 项 | 值 |
| --- | --- |
| 仓库 | https://github.com/samqin123/MoonTV.git |
| 分支 | `main` |
| 上游 commit | `c0bba763d16fb5cd830a808d58329025337491cf` |
| 上游 tree | `5a3e2d25c55cb9524f6c89399114c6b1655591b3` |
| 许可证 | MIT（原文见 `LICENSE-MOONTV-MIT` 与 `moonserver/LICENSE`） |
| 本地 tree（验收） | `git rev-parse HEAD:moonserver` → `5a3e2d25c55cb9524f6c89399114c6b1655591b3` |

## 3. 导入方式（实际执行）

任务书首选 `git subtree add --squash`。本机环境中 `git subtree` 无法运行：它依赖
MSYS2 `sh`，而当前受限执行环境禁止该进程创建信号管道，实际报错为

```
sh.exe: *** fatal error - couldn't create signal pipe, Win32 error 5
```

因此按任务书允许的退路执行：

1. `git clone --depth 1 <repo> app`（Moonserver 同理），记录 `HEAD` 与 `HEAD^{tree}`；
2. 删除克隆目录内的 `.git`；
3. 为消除 Windows 换行（CRLF）与符号链接模式对 tree hash 的影响，执行
   `git fetch --depth 1 <repo> <sha>` + `git read-tree --prefix=app/ FETCH_HEAD^{tree}`，
   使提交的子树对象与上游逐字节一致；
4. 单独提交，提交信息包含仓库地址与上游 SHA。

该方式与 `subtree add --squash` 的结果等价：`app/`、`moonserver/` 的 tree hash
与上游一致，且没有引入上游历史。

## 4. 复现 / 重新导入

```powershell
git fetch --depth 1 https://github.com/Predidit/Kazumi.git 4ca04009fdae696883629e0984e7d7134cc7ed84
git read-tree --prefix=app/ FETCH_HEAD^{tree}
git commit -m "vendor: import Kazumi ..."
```

MoonTV 同理，prefix 改为 `moonserver/`。

## 5. 变更记录

对上游文件的任何修改都记录在 [CHANGELOG.md](CHANGELOG.md)。创建本文件时两个子树
均为零改动。
