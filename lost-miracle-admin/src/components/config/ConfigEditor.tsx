import { Card, Descriptions, Input, InputNumber, Space, Table, Typography } from 'antd';
import type { ColumnsType } from 'antd/es/table';

const MONSTER_TIERS = [
  { key: 'normal', label: '普通' },
  { key: 'elite', label: '精英' },
  { key: 'boss', label: 'Boss' },
] as const;

const EVENT_LABELS: Record<string, string> = {
  normal_monster: '普通怪物',
  chest: '宝箱',
  altar: '祭坛',
  trap: '陷阱',
};

const SPAWN_FIELDS = [
  { key: 'normal_slots_per_monster', label: '普通怪每型槽位数' },
  { key: 'normal_cooldown_sec', label: '普通刷新冷却(秒)' },
  { key: 'elite_cooldown_sec', label: '精英刷新冷却(秒)' },
  { key: 'boss_cooldown_sec', label: 'Boss 刷新冷却(秒)' },
] as const;

const ENHANCE_SCALARS = [
  { key: 'max_enhance', label: '装备最高强化' },
  { key: 'max_jewelry_enhance', label: '首饰最高强化' },
  { key: 'default_safe_until', label: '默认安全强化上限' },
  { key: 'break_from_level', label: '损坏起始等级' },
  { key: 'break_chance_normal_scroll', label: '普通卷损坏概率' },
  { key: 'break_chance_blessed_scroll', label: '祝福卷损坏概率' },
  { key: 'blessed_equipment_save_chance', label: '祝福装损坏保留概率' },
  { key: 'blessed_equipment_on_drop', label: '掉落祝福装概率' },
  { key: 'blessed_equipment_on_enhance_plus7', label: '+7 强化出祝福概率' },
] as const;

const TIER_KEYS = ['vine', 'chain', 'plate'] as const;
const TIER_LABELS: Record<string, string> = { vine: '藤', chain: '链', plate: '板' };

export interface ConfigEditorProps {
  configKey: string;
  value: Record<string, unknown>;
  readOnly?: boolean;
  onChange?: (value: Record<string, unknown>) => void;
}

export function ConfigEditor({ configKey, value, readOnly = false, onChange }: ConfigEditorProps) {
  const patch = (next: Record<string, unknown>) => {
    if (!readOnly && onChange) {
      onChange(next);
    }
  };

  switch (configKey) {
    case 'dungeon.explore':
      return <DungeonExploreEditor value={value} readOnly={readOnly} onChange={patch} />;
    case 'loot.equip_drop':
      return (
        <LootEquipEditor value={value} readOnly={readOnly} onChange={patch} />
      );
    case 'loot.gold_drop':
      return <LootRangeEditor value={value} readOnly={readOnly} onChange={patch} showRate={false} />;
    case 'loot.stone_drop':
      return <LootRangeEditor value={value} readOnly={readOnly} onChange={patch} showRate />;
    case 'enhance.rules':
      return <EnhanceRulesEditor value={value} readOnly={readOnly} onChange={patch} />;
    case 'spawn.constants':
      return <SpawnConstantsEditor value={value} readOnly={readOnly} onChange={patch} />;
    default:
      return <JsonFallbackEditor value={value} readOnly={readOnly} onChange={patch} />;
  }
}

function NumberCell({
  value,
  readOnly,
  min,
  max,
  step,
  onChange,
}: {
  value: number;
  readOnly: boolean;
  min?: number;
  max?: number;
  step?: number;
  onChange: (v: number) => void;
}) {
  if (readOnly) {
    return <span>{value}</span>;
  }
  return (
    <InputNumber
      value={value}
      min={min}
      max={max}
      step={step ?? 1}
      style={{ width: '100%' }}
      onChange={(v) => onChange(Number(v ?? 0))}
    />
  );
}

function tierMap(value: Record<string, unknown>, tier: string): Record<string, unknown> {
  const raw = value[tier];
  return raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {};
}

function patchTier(
  value: Record<string, unknown>,
  tier: string,
  field: string,
  fieldValue: number,
): Record<string, unknown> {
  return {
    ...value,
    [tier]: { ...tierMap(value, tier), [field]: fieldValue },
  };
}

function DungeonExploreEditor({
  value,
  readOnly,
  onChange,
}: {
  value: Record<string, unknown>;
  readOnly: boolean;
  onChange: (v: Record<string, unknown>) => void;
}) {
  const events =
    value.events && typeof value.events === 'object'
      ? (value.events as Record<string, { probability?: number; description?: string }>)
      : {};

  const rows = Object.entries(events).map(([eventKey, evt]) => ({
    key: eventKey,
    eventKey,
    label: EVENT_LABELS[eventKey] || eventKey,
    description: evt.description ?? '',
    probability: evt.probability ?? 0,
  }));

  const columns: ColumnsType<(typeof rows)[number]> = [
    { title: '事件', dataIndex: 'label', width: 120 },
    {
      title: '说明',
      dataIndex: 'description',
      render: (text, row) =>
        readOnly ? (
          text
        ) : (
          <Input
            value={text}
            onChange={(e) => {
              const nextEvents = { ...events, [row.eventKey]: { ...events[row.eventKey], description: e.target.value } };
              onChange({ ...value, events: nextEvents });
            }}
          />
        ),
    },
    {
      title: '概率',
      dataIndex: 'probability',
      width: 140,
      render: (prob, row) => (
        <NumberCell
          value={prob}
          readOnly={readOnly}
          min={0}
          max={1}
          step={0.01}
          onChange={(v) => {
            const nextEvents = { ...events, [row.eventKey]: { ...events[row.eventKey], probability: v } };
            onChange({ ...value, events: nextEvents });
          }}
        />
      ),
    },
  ];

  return (
    <Space direction="vertical" style={{ width: '100%' }} size="middle">
      <Table columns={columns} dataSource={rows} pagination={false} size="small" bordered />
      <Descriptions bordered size="small" column={1}>
        <Descriptions.Item label="精英自动应战概率">
          <NumberCell
            value={Number(value.elite_auto_challenge_chance ?? 0)}
            readOnly={readOnly}
            min={0}
            max={1}
            step={0.01}
            onChange={(v) => onChange({ ...value, elite_auto_challenge_chance: v })}
          />
        </Descriptions.Item>
      </Descriptions>
    </Space>
  );
}

function LootEquipEditor({
  value,
  readOnly,
  onChange,
}: {
  value: Record<string, unknown>;
  readOnly: boolean;
  onChange: (v: Record<string, unknown>) => void;
}) {
  const rows = MONSTER_TIERS.map(({ key, label }) => ({
    key,
    label,
    rate: Number(tierMap(value, key).rate ?? 0),
    min: Number(tierMap(value, key).min ?? 0),
    max: Number(tierMap(value, key).max ?? 0),
  }));

  const columns: ColumnsType<(typeof rows)[number]> = [
    { title: '怪物类型', dataIndex: 'label', width: 100 },
    {
      title: '掉落率',
      dataIndex: 'rate',
      render: (v, row) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          max={1}
          step={0.01}
          onChange={(n) => onChange(patchTier(value, row.key, 'rate', n))}
        />
      ),
    },
    {
      title: '最少',
      dataIndex: 'min',
      render: (v, row) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          onChange={(n) => onChange(patchTier(value, row.key, 'min', n))}
        />
      ),
    },
    {
      title: '最多',
      dataIndex: 'max',
      render: (v, row) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          onChange={(n) => onChange(patchTier(value, row.key, 'max', n))}
        />
      ),
    },
  ];

  return <Table columns={columns} dataSource={rows} pagination={false} size="small" bordered />;
}

function LootRangeEditor({
  value,
  readOnly,
  onChange,
  showRate,
}: {
  value: Record<string, unknown>;
  readOnly: boolean;
  onChange: (v: Record<string, unknown>) => void;
  showRate: boolean;
}) {
  const rows = MONSTER_TIERS.map(({ key, label }) => ({
    key,
    label,
    min: Number(tierMap(value, key).min ?? 0),
    max: Number(tierMap(value, key).max ?? 0),
    rate: Number(tierMap(value, key).rate ?? 0),
  }));

  const columns: ColumnsType<(typeof rows)[number]> = [
    { title: '怪物类型', dataIndex: 'label', width: 100 },
    {
      title: '最少',
      dataIndex: 'min',
      render: (v, row) => (
        <NumberCell value={v} readOnly={readOnly} min={0} onChange={(n) => onChange(patchTier(value, row.key, 'min', n))} />
      ),
    },
    {
      title: '最多',
      dataIndex: 'max',
      render: (v, row) => (
        <NumberCell value={v} readOnly={readOnly} min={0} onChange={(n) => onChange(patchTier(value, row.key, 'max', n))} />
      ),
    },
  ];

  if (showRate) {
    columns.push({
      title: '触发率',
      dataIndex: 'rate',
      render: (v, row) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          max={1}
          step={0.01}
          onChange={(n) => onChange(patchTier(value, row.key, 'rate', n))}
        />
      ),
    });
  }

  return <Table columns={columns} dataSource={rows} pagination={false} size="small" bordered />;
}

function SpawnConstantsEditor({
  value,
  readOnly,
  onChange,
}: {
  value: Record<string, unknown>;
  readOnly: boolean;
  onChange: (v: Record<string, unknown>) => void;
}) {
  return (
    <Descriptions bordered size="small" column={1}>
      {SPAWN_FIELDS.map(({ key, label }) => (
        <Descriptions.Item key={key} label={label}>
          <NumberCell
            value={Number(value[key] ?? 0)}
            readOnly={readOnly}
            min={0}
            onChange={(v) => onChange({ ...value, [key]: v })}
          />
        </Descriptions.Item>
      ))}
    </Descriptions>
  );
}

function RateMatrixEditor({
  title,
  matrix,
  readOnly,
  onChange,
}: {
  title: string;
  matrix: number[][];
  readOnly: boolean;
  onChange: (matrix: number[][]) => void;
}) {
  const rows = matrix.map((pair, index) => ({
    key: String(index),
    level: index,
    success: pair[0] ?? 0,
    keep: pair[1] ?? 0,
  }));

  const columns: ColumnsType<(typeof rows)[number]> = [
    { title: '等级', dataIndex: 'level', width: 72 },
    {
      title: '成功',
      dataIndex: 'success',
      render: (v, row) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          max={1}
          step={0.01}
          onChange={(n) => {
            const next = matrix.map((r, i) => (i === row.level ? [n, r[1] ?? 0] : r));
            onChange(next);
          }}
        />
      ),
    },
    {
      title: '不变',
      dataIndex: 'keep',
      render: (v, row) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          max={1}
          step={0.01}
          onChange={(n) => {
            const next = matrix.map((r, i) => (i === row.level ? [r[0] ?? 0, n] : r));
            onChange(next);
          }}
        />
      ),
    },
  ];

  return (
    <Card size="small" title={title} style={{ marginBottom: 12 }}>
      <Table columns={columns} dataSource={rows} pagination={false} size="small" bordered />
    </Card>
  );
}

function EnhanceRulesEditor({
  value,
  readOnly,
  onChange,
}: {
  value: Record<string, unknown>;
  readOnly: boolean;
  onChange: (v: Record<string, unknown>) => void;
}) {
  const armorRates = asMatrix(value.armor_rates);
  const jewelryRates = asMatrix(value.jewelry_rates);
  const jewelryBreakRates = asMatrix(value.jewelry_break_rates);
  const dropWeights =
    value.drop_tier_weights && typeof value.drop_tier_weights === 'object'
      ? (value.drop_tier_weights as Record<string, Record<string, number>>)
      : {};

  const weightRows = MONSTER_TIERS.map(({ key, label }) => ({
    key,
    label,
    vine: Number(dropWeights[key]?.vine ?? 0),
    chain: Number(dropWeights[key]?.chain ?? 0),
    plate: Number(dropWeights[key]?.plate ?? 0),
  }));

  const weightColumns: ColumnsType<(typeof weightRows)[number]> = [
    { title: '怪物', dataIndex: 'label', width: 80 },
    ...TIER_KEYS.map((tier) => ({
      title: TIER_LABELS[tier],
      dataIndex: tier,
      render: (v: number, row: (typeof weightRows)[number]) => (
        <NumberCell
          value={v}
          readOnly={readOnly}
          min={0}
          onChange={(n) => {
            const nextWeights = { ...dropWeights, [row.key]: { ...dropWeights[row.key], [tier]: n } };
            onChange({ ...value, drop_tier_weights: nextWeights });
          }}
        />
      ),
    })),
  ];

  return (
    <Space direction="vertical" style={{ width: '100%' }} size="middle">
      <Descriptions bordered size="small" column={2}>
        {ENHANCE_SCALARS.map(({ key, label }) => (
          <Descriptions.Item key={key} label={label}>
            <NumberCell
              value={Number(value[key] ?? 0)}
              readOnly={readOnly}
              min={0}
              max={key.includes('chance') || key.includes('rate') ? 1 : undefined}
              step={key.includes('chance') ? 0.01 : 1}
              onChange={(v) => onChange({ ...value, [key]: v })}
            />
          </Descriptions.Item>
        ))}
      </Descriptions>
      <RateMatrixEditor
        title="防具强化成功率"
        matrix={armorRates}
        readOnly={readOnly}
        onChange={(matrix) => onChange({ ...value, armor_rates: matrix })}
      />
      <RateMatrixEditor
        title="首饰强化成功率"
        matrix={jewelryRates}
        readOnly={readOnly}
        onChange={(matrix) => onChange({ ...value, jewelry_rates: matrix })}
      />
      <RateMatrixEditor
        title="首饰强化损坏率"
        matrix={jewelryBreakRates}
        readOnly={readOnly}
        onChange={(matrix) => onChange({ ...value, jewelry_break_rates: matrix })}
      />
      <Card size="small" title="掉落 tier 权重">
        <Table columns={weightColumns} dataSource={weightRows} pagination={false} size="small" bordered />
      </Card>
    </Space>
  );
}

function JsonFallbackEditor({
  value,
  readOnly,
  onChange,
}: {
  value: Record<string, unknown>;
  readOnly: boolean;
  onChange: (v: Record<string, unknown>) => void;
}) {
  const text = JSON.stringify(value, null, 2);
  if (readOnly) {
    return (
      <pre style={{ background: '#fafafa', padding: 12, overflow: 'auto', margin: 0 }}>{text}</pre>
    );
  }
  return (
    <Input.TextArea
      rows={16}
      value={text}
      onChange={(e) => {
        try {
          onChange(JSON.parse(e.target.value) as Record<string, unknown>);
        } catch {
          // 编辑过程中允许临时无效 JSON，失焦后由保存按钮校验
        }
      }}
    />
  );
}

function asMatrix(raw: unknown): number[][] {
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.map((row) => (Array.isArray(row) ? row.map((n) => Number(n)) : []));
}

export function ConfigKeyLabel({ configKey }: { configKey: string }) {
  return (
    <Typography.Text type="secondary" style={{ fontSize: 12 }}>
      {configKey}
    </Typography.Text>
  );
}
