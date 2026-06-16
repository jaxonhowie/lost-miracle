export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface GmAuthResponse {
  token: string;
  expiresInSeconds: number;
  gmAccountId: number;
  username: string;
  role: string;
}

export interface GmMeResponse {
  gmAccountId: number;
  username: string;
  role: string;
}

export interface GmUserSummary {
  id: number;
  username: string;
  status: number;
  createdAt: number;
}

export interface GmUserList {
  items: GmUserSummary[];
  total: number;
  page: number;
  pageSize: number;
}

export interface CharacterSummary {
  id: number;
  name: string;
  playerClass: string;
  level: number;
  powerScore: number;
  currentDungeonId: string;
  lastLoginAt: number;
  saveVersion: number;
}

export interface CharacterList {
  items: CharacterSummary[];
  maxSlots: number;
}

export interface CharacterSave {
  characterId: number;
  saveVersion: number;
  clientUpdatedAt: number;
  checksum: string;
  save: Record<string, unknown>;
}

export interface ConfigItem {
  configKey: string;
  description: string;
  draft: Record<string, unknown>;
  published: Record<string, unknown>;
}

export interface ConfigList {
  version: number;
  items: ConfigItem[];
}

export interface AuditLog {
  id: number;
  gmAccountId: number;
  action: string;
  targetType: string;
  targetId: string;
  detailJson: string | null;
  ip: string | null;
  createdAt: string;
}

export interface SpawnSlotView {
  slotId: number;
  monsterId: string;
  slotIndex: number;
  available: boolean;
  cooldownSec: number;
}

export interface DungeonSpawnState {
  dungeonId: string;
  normals: Record<string, SpawnSlotView[]>;
  elite: SpawnSlotView | null;
  boss: SpawnSlotView | null;
}
