import { Card, Descriptions, Input, InputNumber, Select, Space, Switch, Table, Typography } from 'antd';
import type { ColumnsType } from 'antd/es/table';

const DUNGEONS = [
  { value: 'bone_crypt', label: '骨穴地牢' },
  { value: 'corrupt_swamp', label: '腐化沼泽' },
  { value: 'frozen_abyss', label: '冰封深渊' },
  { value: 'forge_ruins', label: '锻造厂遗迹' },
];

const EQUIPMENT_SLOTS = [
  { key: 'weapon', label: '武器' },
  { key: 'helmet', label: '头盔' },
  { key: 'armor', label: '护甲' },
  { key: 'legs', label: '护腿' },
  { key: 'gloves', label: '手套' },
  { key: 'ring_left', label: '左戒' },
  { key: 'ring_right', label: '右戒' },
  { key: 'necklace', label: '项链' },
] as const;

const PLAYER_FIELDS = [
  { key: 'gold', label: '金币', min: 0 },
  { key: 'level', label: '等级', min: 1, max: 100 },
  { key: 'exp', label: '经验', min: 0 },
  { key: 'enhance_stone', label: '强化石', min: 0 },
  { key: 'blessed_enhance_stone', label: '祝福强化石', min: 0 },
  { key: 'jewelry_enhance_stone', label: '首饰强化石', min: 0 },
  { key: 'blessed_jewelry_enhance_stone', label: '祝福首饰石', min: 0 },
  { key: 'health_potion', label: '生命药水', min: 0 },
] as const;

const PRIMARY_STATS = ['STR', 'AGI', 'INT'] as const;

const BASE_STATS = [
  { key: 'max_hp', label: '生命上限' },
  { key: 'max_mp', label: '魔法上限' },
  { key: 'atk', label: '攻击' },
  { key: 'def', label: '防御' },
  { key: 'spd', label: '速度' },
  { key: 'hit', label: '命中' },
  { key: 'dodge', label: '闪避' },
] as const;

export interface SaveEditorProps {
  value: Record<string, unknown>;
  canEditPlayerFields: boolean;
  canEditFull: boolean;
  onChange: (value: Record<string, unknown>) => void;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asItemArray(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item) => item && typeof item === 'object') as Record<string, unknown>[];
}

function patchPlayer(value: Record<string, unknown>, patch: Record<string, unknown>) {
  return { ...value, player: { ...asRecord(value.player), ...patch } };
}

function patchNested(
  value: Record<string, unknown>,
  section: string,
  patch: Record<string, unknown>,
) {
  return { ...value, [section]: { ...asRecord(value[section]), ...patch } };
}

function NumberField({
  label,
  value,
  readOnly,
  min,
  max,
  onChange,
}: {
  label: string;
  value: number;
  readOnly: boolean;
  min?: number;
  max?: number;
  onChange: (v: number) => void;
}) {
  return (
    <Descriptions.Item label={label}>
      {readOnly ? (
        value
      ) : (
        <InputNumber min={min} max={max} value={value} style={{ width: '100%' }} onChange={(v) => onChange(Number(v ?? 0))} />
      )}
    </Descriptions.Item>
  );
}

export function SaveEditor({ value, canEditPlayerFields, canEditFull, onChange }: SaveEditorProps) {
  const player = asRecord(value.player);
  const world = asRecord(value.world);
  const dungeon = asRecord(value.dungeon);
  const equipment = asRecord(value.equipment);
  const inventory = asItemArray(value.inventory);
  const baseStats = asRecord(player.base_stats);
  const primaryStats = asRecord(player.primary_stats);

  const canEditPlayer = canEditPlayerFields || canEditFull;
  const inventoryByUid = new Map(inventory.map((item) => [String(item.uid ?? ''), item]));

  const equipmentRows = EQUIPMENT_SLOTS.map(({ key, label }) => {
    const uid = String(equipment[key] ?? '');
    const item = uid ? inventoryByUid.get(uid) : undefined;
    return {
      key,
      slot: label,
      uid,
      name: item ? String(item.name ?? item.base_id ?? '-') : uid ? '(未在背包)' : '-',
      enhanceLevel: item ? Number(item.enhance_level ?? 0) : null,
    };
  });

  const inventoryRows = inventory.map((item, index) => ({
    key: String(item.uid ?? index),
    uid: String(item.uid ?? ''),
    name: String(item.name ?? '-'),
    baseId: String(item.base_id ?? '-'),
    slot: String(item.slot ?? item.type ?? '-'),
    enhanceLevel: Number(item.enhance_level ?? 0),
    quality: String(item.quality ?? '-'),
    blessed: Boolean(item.is_blessed),
  }));

  const equipmentColumns: ColumnsType<(typeof equipmentRows)[number]> = [
    { title: '部位', dataIndex: 'slot', width: 80 },
    {
      title: '装备 UID',
      dataIndex: 'uid',
      render: (uid, row) =>
        canEditFull ? (
          <Input
            value={uid}
            placeholder="留空表示未穿戴"
            onChange={(e) =>
              onChange(patchNested(value, 'equipment', { ...equipment, [row.key]: e.target.value }))
            }
          />
        ) : (
          uid || '-'
        ),
    },
    { title: '名称', dataIndex: 'name' },
    {
      title: '强化',
      dataIndex: 'enhanceLevel',
      width: 72,
      render: (v) => (v == null ? '-' : `+${v}`),
    },
  ];

  const inventoryColumns: ColumnsType<(typeof inventoryRows)[number]> = [
    { title: 'UID', dataIndex: 'uid', width: 140, ellipsis: true },
    { title: '名称', dataIndex: 'name', width: 120 },
    { title: '基础 ID', dataIndex: 'baseId', width: 140, ellipsis: true },
    { title: '部位', dataIndex: 'slot', width: 72 },
    {
      title: '强化',
      dataIndex: 'enhanceLevel',
      width: 88,
      render: (level, row) =>
        canEditFull ? (
          <InputNumber
            min={0}
            max={10}
            value={level}
            onChange={(v) => {
              const next = inventory.map((item) =>
                String(item.uid) === row.uid ? { ...item, enhance_level: Number(v ?? 0) } : item,
              );
              onChange({ ...value, inventory: next });
            }}
          />
        ) : (
          `+${level}`
        ),
    },
    { title: '品质', dataIndex: 'quality', width: 72 },
    {
      title: '祝福',
      dataIndex: 'blessed',
      width: 72,
      render: (blessed, row) =>
        canEditFull ? (
          <Switch
            checked={blessed}
            onChange={(checked) => {
              const next = inventory.map((item) =>
                String(item.uid) === row.uid ? { ...item, is_blessed: checked } : item,
              );
              onChange({ ...value, inventory: next });
            }}
          />
        ) : blessed ? (
          '是'
        ) : (
          '否'
        ),
    },
  ];

  return (
    <Space direction="vertical" style={{ width: '100%' }} size="middle">
      <Card size="small" title="角色属性">
        <Descriptions bordered size="small" column={3}>
          {PLAYER_FIELDS.map(({ key, label, min, ...rest }) => (
            <NumberField
              key={key}
              label={label}
              value={Number(player[key] ?? 0)}
              readOnly={!canEditPlayer}
              min={min}
              max={'max' in rest ? rest.max : undefined}
              onChange={(v) => onChange(patchPlayer(value, { [key]: v }))}
            />
          ))}
          <Descriptions.Item label="职业">
            {canEditFull ? (
              <Select
                value={String(player.class ?? 'warrior')}
                style={{ width: '100%' }}
                options={[{ value: 'warrior', label: '战士' }]}
                onChange={(v) => onChange(patchPlayer(value, { class: v }))}
              />
            ) : (
              String(player.class ?? '-')
            )}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      <Card size="small" title="基础属性">
        <Descriptions bordered size="small" column={3}>
          {PRIMARY_STATS.map((stat) => (
            <NumberField
              key={stat}
              label={stat}
              value={Number(primaryStats[stat] ?? 0)}
              readOnly={!canEditFull}
              min={0}
              onChange={(v) =>
                onChange(
                  patchPlayer(value, {
                    primary_stats: { ...primaryStats, [stat]: v },
                  }),
                )
              }
            />
          ))}
          {BASE_STATS.map(({ key, label }) => (
            <NumberField
              key={key}
              label={label}
              value={Number(baseStats[key] ?? 0)}
              readOnly={!canEditFull}
              min={0}
              onChange={(v) =>
                onChange(
                  patchPlayer(value, {
                    base_stats: { ...baseStats, [key]: v },
                  }),
                )
              }
            />
          ))}
        </Descriptions>
      </Card>

      <Card size="small" title="世界 / 地牢">
        <Descriptions bordered size="small" column={2}>
          <Descriptions.Item label="当前地牢">
            {canEditFull ? (
              <Select
                value={String(world.current_dungeon_id ?? 'bone_crypt')}
                style={{ width: '100%' }}
                options={DUNGEONS}
                onChange={(v) => onChange(patchNested(value, 'world', { current_dungeon_id: v }))}
              />
            ) : (
              DUNGEONS.find((d) => d.value === world.current_dungeon_id)?.label
              || String(world.current_dungeon_id ?? '-')
            )}
          </Descriptions.Item>
          <Descriptions.Item label="自动战斗">
            {canEditFull ? (
              <Switch
                checked={Boolean(world.auto_battle)}
                onChange={(checked) => onChange(patchNested(value, 'world', { auto_battle: checked }))}
              />
            ) : world.auto_battle ? (
              '开启'
            ) : (
              '关闭'
            )}
          </Descriptions.Item>
          <NumberField
            label="普通击杀"
            value={Number(dungeon.normal_kill_count ?? 0)}
            readOnly={!canEditFull}
            min={0}
            onChange={(v) => onChange(patchNested(value, 'dungeon', { normal_kill_count: v }))}
          />
          <NumberField
            label="精英击杀"
            value={Number(dungeon.elite_kill_count ?? 0)}
            readOnly={!canEditFull}
            min={0}
            onChange={(v) => onChange(patchNested(value, 'dungeon', { elite_kill_count: v }))}
          />
          <NumberField
            label="Boss 击杀"
            value={Number(dungeon.boss_kill_count ?? 0)}
            readOnly={!canEditFull}
            min={0}
            onChange={(v) => onChange(patchNested(value, 'dungeon', { boss_kill_count: v }))}
          />
        </Descriptions>
      </Card>

      <Card size="small" title={`已穿戴装备 (${equipmentRows.filter((r) => r.uid).length}/8)`}>
        <Table
          columns={equipmentColumns}
          dataSource={equipmentRows}
          pagination={false}
          size="small"
          bordered
        />
      </Card>

      <Card size="small" title={`背包 (${inventoryRows.length})`}>
        {inventoryRows.length === 0 ? (
          <Typography.Text type="secondary">背包为空</Typography.Text>
        ) : (
          <Table
            columns={inventoryColumns}
            dataSource={inventoryRows}
            pagination={{ pageSize: 10, showSizeChanger: false }}
            size="small"
            bordered
            scroll={{ x: 720 }}
          />
        )}
      </Card>
    </Space>
  );
}

export function extractOperatorPatch(player: Record<string, unknown>) {
  return {
    gold: num(player.gold),
    level: num(player.level),
    exp: num(player.exp),
    enhanceStone: num(player.enhance_stone),
    blessedEnhanceStone: num(player.blessed_enhance_stone),
    jewelryEnhanceStone: num(player.jewelry_enhance_stone),
    blessedJewelryEnhanceStone: num(player.blessed_jewelry_enhance_stone),
    healthPotion: num(player.health_potion),
  };
}

function num(value: unknown): number | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  return Number(value);
}
