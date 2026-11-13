/**
 * FSYL TV 同步变更对象（SPEC §6）。
 *
 * 本文件只定义类型，不发起请求，也不改变现有播放记录/收藏/搜索历史的读写行为。
 */

export type SyncModule = 'anime' | 'movie';
export type SyncType = 'history' | 'favorite' | 'source';

export interface SyncChange {
  module: SyncModule;
  type: SyncType;
  key: string;
  payload: unknown;
  updatedAt: number;
  isDeleted: boolean;
  dirty: boolean;
  schemaVersion: 1;
}

export interface SyncEnvelope {
  updatedAt: number;
  isDeleted: boolean;
  dirty: boolean;
  payload: unknown;
  schemaVersion: 1;
}
