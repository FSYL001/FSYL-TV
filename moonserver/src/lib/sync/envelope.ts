'use client';

/**
 * 同步元数据信封（阶段 7）。
 *
 * 不修改 MoonTV 现有 localStorage 键，也不改变任何读写路径；只在独立的
 * `fsyltv_sync_meta_v1` 键里记录每个对象的 updatedAt / isDeleted / dirty。
 * 因此未登录时的行为与原版完全一致。
 */

import { SyncChange, SyncEnvelope, SyncType } from './types';

const META_KEY = 'fsyltv_sync_meta_v1';

type MetaMap = Record<string, SyncEnvelope>;

function metaKey(type: SyncType, key: string): string {
  return `${type}:${key}`;
}

function readAll(): MetaMap {
  if (typeof window === 'undefined') return {};
  try {
    const raw = localStorage.getItem(META_KEY);
    return raw ? (JSON.parse(raw) as MetaMap) : {};
  } catch {
    return {};
  }
}

function writeAll(map: MetaMap): void {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(META_KEY, JSON.stringify(map));
  } catch {
    // 写入失败不影响原版功能。
  }
}

/** 记录一次本地变更（由未来接入的保存/删除逻辑调用）。 */
export function recordLocalChange(
  type: SyncType,
  key: string,
  payload: unknown,
  options: { isDeleted?: boolean } = {}
): SyncEnvelope {
  const map = readAll();
  const envelope: SyncEnvelope = {
    updatedAt: Date.now(),
    isDeleted: options.isDeleted ?? false,
    dirty: true,
    payload,
    schemaVersion: 1,
  };
  map[metaKey(type, key)] = envelope;
  writeAll(map);
  return envelope;
}

export function getEnvelope(type: SyncType, key: string): SyncEnvelope | null {
  return readAll()[metaKey(type, key)] ?? null;
}

/** 待推送的本地变更；未登录/未接线时只用于诊断。 */
export function listPending(): SyncChange[] {
  const map = readAll();
  return Object.entries(map)
    .filter(([, env]) => env.dirty)
    .map(([k, env]) => {
      const sep = k.indexOf(':');
      const type = k.slice(0, sep) as SyncType;
      const key = k.slice(sep + 1);
      return {
        module: 'movie' as const,
        type,
        key,
        payload: env.payload,
        updatedAt: env.updatedAt,
        isDeleted: env.isDeleted,
        dirty: true,
        schemaVersion: 1 as const,
      };
    });
}

export function markSynced(changes: Pick<SyncChange, 'type' | 'key'>[]): void {
  const map = readAll();
  for (const change of changes) {
    const k = metaKey(change.type, change.key);
    const env = map[k];
    if (env) env.dirty = false;
  }
  writeAll(map);
}

/**
 * 合并远端变更（冲突策略见 SPEC §6）：
 * - updatedAt 新者胜；
 * - 播放进度取较大值；
 * - isDeleted 优先。
 * 只写同步元数据，不触碰原版数据键。
 */
export function applyRemote(changes: SyncChange[]): number {
  const map = readAll();
  let applied = 0;
  for (const change of changes) {
    const k = metaKey(change.type, change.key);
    const local = map[k];
    if (local && local.updatedAt > change.updatedAt && !change.isDeleted) {
      continue;
    }
    let payload = change.payload;
    if (
      local &&
      !change.isDeleted &&
      !local.isDeleted &&
      change.type === 'history' &&
      local.payload &&
      change.payload &&
      typeof local.payload === 'object' &&
      typeof change.payload === 'object'
    ) {
      const localProgress = Number(
        (local.payload as Record<string, unknown>).play_time ?? 0
      );
      const remoteProgress = Number(
        (change.payload as Record<string, unknown>).play_time ?? 0
      );
      if (localProgress > remoteProgress) {
        payload = {
          ...(change.payload as Record<string, unknown>),
          play_time: localProgress,
        };
      }
    }
    map[k] = {
      updatedAt: change.updatedAt,
      isDeleted: change.isDeleted,
      dirty: false,
      payload,
      schemaVersion: 1,
    };
    applied += 1;
  }
  writeAll(map);
  return applied;
}
