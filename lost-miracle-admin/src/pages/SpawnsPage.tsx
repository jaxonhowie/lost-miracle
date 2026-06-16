import { Button, Select, Space, Table, Tag, Typography, message } from 'antd';
import { useEffect, useMemo, useState } from 'react';
import { api, unwrap } from '../api/client';
import type { DungeonSpawnState, SpawnSlotView } from '../api/types';

const DUNGEONS = [
  { value: 'bone_crypt', label: '骨穴地牢' },
  { value: 'corrupt_swamp', label: '腐化沼泽' },
  { value: 'frozen_abyss', label: '冰封深渊' },
  { value: 'forge_ruins', label: '锻造厂遗迹' },
];

export default function SpawnsPage() {
  const [dungeonId, setDungeonId] = useState('bone_crypt');
  const [state, setState] = useState<DungeonSpawnState | null>(null);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const data = await unwrap<DungeonSpawnState>(api.get(`/dungeons/${dungeonId}/spawns`));
      setState(data);
    } catch (e) {
      message.error(e instanceof Error ? e.message : '加载失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, [dungeonId]);

  const rows = useMemo(() => {
    if (!state) return [] as Array<SpawnSlotView & { spawnType: string }>;
    const list: Array<SpawnSlotView & { spawnType: string }> = [];
    for (const [monsterId, slots] of Object.entries(state.normals || {})) {
      for (const slot of slots) {
        list.push({ ...slot, spawnType: `normal:${monsterId}` });
      }
    }
    if (state.elite) list.push({ ...state.elite, spawnType: 'elite' });
    if (state.boss) list.push({ ...state.boss, spawnType: 'boss' });
    return list;
  }, [state]);

  const resetSlot = async (slotId: number) => {
    await unwrap(api.post(`/spawns/${slotId}/reset`));
    message.success('槽位已重置');
    await load();
  };

  const resetAll = async () => {
    await unwrap(api.post(`/dungeons/${dungeonId}/spawns/reset-all`));
    message.success('整图已重置');
    await load();
  };

  return (
    <div>
      <Typography.Title level={3}>刷怪状态</Typography.Title>
      <Space style={{ marginBottom: 16 }}>
        <Select
          style={{ width: 220 }}
          value={dungeonId}
          options={DUNGEONS}
          onChange={setDungeonId}
        />
        <Button onClick={() => void load()} loading={loading}>
          刷新
        </Button>
        <Button danger onClick={() => void resetAll()}>
          整图重置
        </Button>
      </Space>
      <Table
        rowKey="slotId"
        loading={loading}
        dataSource={rows}
        columns={[
          { title: '槽位 ID', dataIndex: 'slotId' },
          { title: '类型', dataIndex: 'spawnType' },
          { title: '怪物', dataIndex: 'monsterId' },
          { title: '索引', dataIndex: 'slotIndex' },
          {
            title: '状态',
            render: (_, row) =>
              row.available ? <Tag color="green">可用</Tag> : <Tag>CD {row.cooldownSec}s</Tag>,
          },
          {
            title: '操作',
            render: (_, row) => (
              <Button size="small" onClick={() => void resetSlot(row.slotId)}>
                重置
              </Button>
            ),
          },
        ]}
      />
    </div>
  );
}
