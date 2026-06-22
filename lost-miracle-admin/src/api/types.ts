export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface GmAuthResponse {
  token: string;
  expiresInSeconds: number;
  gmAccountId: string;
  username: string;
  role: string;
}

export interface GmMeResponse {
  gmAccountId: string;
  username: string;
  role: string;
}

export interface GmUserSummary {
  id: string;
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
  id: string;
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
  characterId: string;
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
  id: string;
  gmAccountId: string;
  action: string;
  targetType: string;
  targetId: string;
  detailJson: string | null;
  ip: string | null;
  createdAt: string;
}

export interface SpawnSlotView {
  slotId: string;
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

export interface AdminSendMailRequest {
  characterId?: number | null;
  title: string;
  body: string;
  attachments?: Record<string, number>;
}

export interface AdminSendMailResponse {
  sent: number;
}

export interface SystemSettings {
  maintenance_mode: boolean;
  maintenance_message: string;
}
