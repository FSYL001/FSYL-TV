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
