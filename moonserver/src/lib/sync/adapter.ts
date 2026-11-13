'use client';

/**
 * 影视侧 SyncAdapter 空实现（阶段 7）。
 *
 * 所有方法都只在本地读写同步元数据，不发起任何网络请求；未登录时 pull
 * 立即返回空数组、push 立即返回。
 */

import {
  applyRemote,
  listPending,
  markSynced,
  recordLocalChange,
} from './envelope';
import { SyncChange, SyncType } from './types';

export interface MovieSyncAdapterLike {
  pull(sinceMs: number): Promise<SyncChange[]>;
  push(changes: SyncChange[]): Promise<void>;
}

export class MovieSyncAdapter implements MovieSyncAdapterLike {
  async pull(_sinceMs: number): Promise<SyncChange[]> {
    // 未启用云同步：不读取远端，也不产生请求。
    return [];
  }

  async push(_changes: SyncChange[]): Promise<void> {
    // 未启用云同步：不写入远端，也不产生请求。
  }
}

export const movieSyncAdapter = new MovieSyncAdapter();

/** 未来由播放记录/收藏/搜索历史/AdminConfig 的保存路径调用。 */
export function recordMovieChange(
  type: SyncType,
  key: string,
  payload: unknown,
  options: { isDeleted?: boolean } = {}
) {
  return recordLocalChange(type, key, payload, options);
}

export function pendingMovieChanges(): SyncChange[] {
  return listPending();
}

export function acceptRemoteChanges(changes: SyncChange[]): number {
  return applyRemote(changes);
}

export function markMovieChangesPushed(
  changes: Pick<SyncChange, 'type' | 'key'>[]
): void {
  markSynced(changes);
}
