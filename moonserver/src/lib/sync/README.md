# MoonTV 同步切面方案（阶段 7）

## 目标

在不改变任何现有行为的前提下，为影视侧对象定义
`updatedAt` / `isDeleted` / `dirty` 元数据，并留出 `pull(since)` / `push(changes)`
空接口。当前阶段**不发任何网络请求**，不改变未登录时的行为。

## 数据面

MoonTV 的记录、收藏、搜索历史、视频源全部由浏览器侧 `localStorage` 持有
（见 `src/lib/db.client.ts` 与 `src/lib/config.ts` 的 localstorage 分支）。
Node 服务端在 localstorage 模式下不持有这些数据。因此同步切面也放在浏览器侧，
不新增服务端存储。

## 包裹方式（只新增文件）

- 现有键保持原样：`moontv_play_records`、`moontv_favorites`、
  `moontv_search_history`、`moontv_skip_configs`，以及 `config.json` 驱动、
  由 AdminConfig API 管理的视频源。
- 新增加一个独立键 `fsyltv_sync_meta_v1`，按 `type:key` 记录信封：

```ts
{
  updatedAt: number;
  isDeleted: boolean;
  dirty: boolean;
  payload: unknown;
  schemaVersion: 1;
}
```

- `recordLocalChange(type, key, payload, { isDeleted })` 写信封，不触碰原数据键。
- `listPending()` 返回 `dirty` 变更；`markSynced()` 清除脏标记。
- `applyRemote()` 按 SPEC §6 合并：`updatedAt` 新者胜、播放进度取较大值、
  `isDeleted` 优先。它同样只写元数据键。

## 未来接线点

未来若启用云同步，只需在 `db.client.ts` 的保存/删除函数尾部调用
`recordLocalChange(...)`，并在 `config.ts` 保存 AdminConfig 时调用一次；
这属于 1–2 个上游文件的最小改动，当前阶段不做。

## 当前状态

- 新增 `src/lib/sync/types.ts`、`envelope.ts`、`adapter.ts`，无上游文件修改。
- `MovieSyncAdapter.pull/push` 为空实现，未登录时立即返回。
- 未接线到播放记录/收藏的保存路径，因此原版行为逐字节保持不变。
