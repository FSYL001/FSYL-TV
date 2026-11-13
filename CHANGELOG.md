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
