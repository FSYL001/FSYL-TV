# FSYL TV 运行时契约（SPEC）

本文件定义 FSYL TV 的目录、进程、端口、生命周期与同步数据契约。后续所有阶段按本文件实现；
任何偏离都必须先修改本文件并说明原因。

## 1. 单窗口边界

- 整个应用只有一个顶层窗口（Flutter Windows runner 窗口），不启动第二个 exe 作为界面。
- 动画板块与影视板块在同一 Flutter 控件树内，用 `IndexedStack` 常驻，切换只改变索引。
- 不允许两个板块互相 import；共享代码只允许放在 `app/lib/shell/` 与 `app/lib/shared/`，
  且不得包含任一板块的业务模型或播放器实例。
- 不允许跨模块读取观看记录、收藏、播放器状态。配置中仅允许记录「上次停留板块」这一项偏好。

## 2. 目录（唯一根）

安装/运行时只允许一个根：

```
%LOCALAPPDATA%\FSYLTV\
  app\                      程序本体（升级时整体替换）
    fsyl_tv.exe
    moon\
      node.exe
      server\server.js      MoonTV standalone 产物
  data\                     唯一可写区（升级永不触碰）
    config\                 外壳配置：window.json、app.json、device.json
    account\                账号/token（DPAPI 加密）
    anime\                  动漫板块 Hive 与播放器数据
    movie\                  影视板块 WebView2 user data folder
    cache\                  两个板块共用的缓存根（按子目录隔开）
    logs\                   shell.log、moon.log、anime.log
```

规则：

- 目录名一律 ASCII、无空格、无中文。
- 所有路径必须由 Dart 侧 `AppPaths` 单例提供；禁止在业务代码里拼接 `%LOCALAPPDATA%`。
- 程序目录不可写（例如装在 `C:\Program Files`）时，数据仍写 `%LOCALAPPDATA%\FSYLTV\data`；
  若 `%LOCALAPPDATA%` 不可写则回退到 `%TEMP%\FSYLTV\data` 并在界面提示。
- 清理 `data\` 后首次启动必须只重新生成上面列出的子目录，不得出现散落目录
  （例如 `%APPDATA%\kazumi`、`%LOCALAPPDATA%\Temp\flutter_*` 之外的缓存）。

## 3. MoonTV sidecar

### 3.1 启动

```
%LOCALAPPDATA%\FSYLTV\app\moon\node.exe
%LOCALAPPDATA%\FSYLTV\app\moon\server\server.js
```

工作目录：`%LOCALAPPDATA%\FSYLTV\app\moon\server`。

环境变量：

| 变量 | 值 |
| --- | --- |
| `PORT` | 外壳探测到的空闲端口（127.0.0.1） |
| `HOSTNAME` | `127.0.0.1` |
| `NEXT_PUBLIC_STORAGE_TYPE` | `localstorage` |
| `NEXT_PUBLIC_SITE_NAME` | `FSYL TV` |

### 3.2 握手与健康

- sidecar 在 HTTP 监听成功后向 stdout 打印一行：`FSYLTV_READY <port>`，随后刷新 stdout。
- 外壳读取 stdout，20 秒内未读到该行视为启动失败，显示错误页与「重试」按钮。
- 健康检查：`GET http://127.0.0.1:<port>/api/health`，返回 HTTP 200 且 JSON 含 `{"status":"ok"}`。

### 3.3 退出

1. 外壳先 `POST http://127.0.0.1:<port>/__shutdown`。
2. 1.5 秒内进程未退出则 `taskkill /PID <pid> /T /F`。
3. 外壳启动时读取 `data\config\moon.pid.json`；只有 PID、进程启动时间、命令行三者
   都与记录吻合且命令行指向本应用 `moon\server\server.js` 时才清理该残留进程。
4. sidecar 运行期间写入 `data\logs\moon.log`（stdout/stderr 重定向）。

### 3.4 崩溃隔离

- 影视 sidecar 崩溃只影响影视板块：显示错误页与「重启影视模块」按钮。
- 动漫板块必须继续可用；不允许因 sidecar 退出而关闭主窗口或退出进程。
- 重启时重新探测端口、重新握手、重新加载 WebView2 页面。

## 4. WebView2

- user data folder 显式设置为 `%LOCALAPPDATA%\FSYLTV\data\movie`。
- 影视页面加载 `http://127.0.0.1:<port>/`（由外壳注入端口）。
- 切换到动漫板块时，WebView2 必须停止捕获/渲染，但保留进程与页面状态；
  切回后恢复原页面与原滚动位置。
- 不允许用 media_kit 替换影视播放器，不允许读取/转发其视频流。

## 5. 动漫板块数据

- Hive 数据库、图片缓存、日志全部落在 `data\anime`、`data\cache`、`data\logs`。
- 播放器仍为 Kazumi 的 media_kit 实现；切换板块时暂停并静音，切回不自动恢复播放。
- 规则引擎、抓取逻辑、播放器代码除品牌文字/图标/路径注入外不做修改。

## 6. 同步变更对象（本阶段只定义，不发请求）

```ts
interface SyncChange {
  module: 'anime' | 'movie';
  type: 'history' | 'favorite' | 'source';
  key: string;
  payload: unknown;
  updatedAt: number;      // UNIX 毫秒
  isDeleted: boolean;
  dirty: boolean;
  schemaVersion: 1;
}
```

冲突策略：

- `updatedAt` 新者胜。
- 同一记录若为播放进度，`progress` 取较大值。
- `isDeleted` 为真时优先删除，不再合并 payload。
- 未登录时：不产生网络请求，行为与原版完全一致；`dirty` 标记只写本地。

## 7. 账号与同步（阶段 7 骨架）

- `AccountService` 负责登录态、DPAPI 加密 token、设备 ID、服务器地址。
- `SyncAdapter.pull(since)` / `push(changes)` 两模块各一个空实现。
- `if (loggedIn)` 只允许出现在 `AccountService` / `SyncService` 内部。
- 设置页显示「本地离线模式」，输入框与开关只存本地，不联网。
