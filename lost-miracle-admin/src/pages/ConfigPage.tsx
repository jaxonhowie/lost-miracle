import { Button, Card, List, Modal, Space, Tabs, Typography, message } from 'antd';
import { useEffect, useState } from 'react';
import { api, unwrap } from '../api/client';
import { ConfigEditor, ConfigKeyLabel } from '../components/config/ConfigEditor';
import { useAuth } from '../contexts/AuthContext';
import type { ConfigItem, ConfigList } from '../api/types';
import { formatDateTime } from '../utils/formatDateTime';

function cloneDraft(value: Record<string, unknown>): Record<string, unknown> {
  return JSON.parse(JSON.stringify(value)) as Record<string, unknown>;
}

export default function ConfigPage() {
  const { canOperator } = useAuth();
  const [configList, setConfigList] = useState<ConfigList | null>(null);
  const [activeKey, setActiveKey] = useState('');
  const [drafts, setDrafts] = useState<Record<string, Record<string, unknown>>>({});
  const [loading, setLoading] = useState(false);

  const load = async () => {
    const data = await unwrap<ConfigList>(api.get('/config'));
    setConfigList(data);
    const nextDrafts: Record<string, Record<string, unknown>> = {};
    for (const item of data.items) {
      nextDrafts[item.configKey] = cloneDraft(item.draft);
    }
    setDrafts(nextDrafts);
    if (!activeKey && data.items.length > 0) {
      setActiveKey(data.items[0].configKey);
    }
  };

  useEffect(() => {
    void load().catch((e) => message.error(e instanceof Error ? e.message : '加载失败'));
  }, []);

  const updateDraft = (key: string, value: Record<string, unknown>) => {
    setDrafts((prev) => ({ ...prev, [key]: value }));
  };

  const saveDraft = async (configKey: string) => {
    const parsed = drafts[configKey];
    if (!parsed) return;
    setLoading(true);
    try {
      await unwrap(api.put(`/config/${encodeURIComponent(configKey)}`, { json: parsed }));
      message.success('草稿已保存');
      await load();
    } catch (e) {
      message.error(e instanceof Error ? e.message : '保存失败');
    } finally {
      setLoading(false);
    }
  };

  const publish = () => {
    Modal.confirm({
      title: '发布配置到线上？',
      content: '发布后玩家登录/进主菜单时会拉取新版本。',
      onOk: async () => {
        const note = window.prompt('发布备注（可选）') || '';
        const result = await unwrap<{ version: number }>(
          api.post('/config/publish', { note }),
        );
        message.success(`已发布 version ${result.version}`);
        await load();
      },
    });
  };

  const items =
    configList?.items.map((item) => ({
      key: item.configKey,
      label: item.description || item.configKey,
      children: (
        <ConfigTabPanel
          item={item}
          draft={drafts[item.configKey] ?? item.draft}
          canOperator={canOperator}
          loading={loading}
          onDraftChange={(value) => updateDraft(item.configKey, value)}
          onSave={() => void saveDraft(item.configKey)}
        />
      ),
    })) || [];

  return (
    <div>
      <Space style={{ marginBottom: 16, width: '100%', justifyContent: 'space-between' }}>
        <Typography.Title level={3} style={{ margin: 0 }}>
          配置中心 {configList ? `(v${configList.version})` : ''}
        </Typography.Title>
        {canOperator ? (
          <Button type="primary" danger onClick={publish}>
            发布到线上
          </Button>
        ) : null}
      </Space>
      <Tabs activeKey={activeKey} items={items} destroyInactiveTabPane onChange={setActiveKey} />
      {configList ? (
        <Card title="发布历史" style={{ marginTop: 16 }}>
          <HistoryList />
        </Card>
      ) : null}
    </div>
  );
}

function ConfigTabPanel({
  item,
  draft,
  canOperator,
  loading,
  onDraftChange,
  onSave,
}: {
  item: ConfigItem;
  draft: Record<string, unknown>;
  canOperator: boolean;
  loading: boolean;
  onDraftChange: (value: Record<string, unknown>) => void;
  onSave: () => void;
}) {
  return (
    <Space direction="vertical" style={{ width: '100%' }} size="large">
      <Card
        title="草稿"
        extra={<ConfigKeyLabel configKey={item.configKey} />}
        size="small"
      >
        <ConfigEditor
          configKey={item.configKey}
          value={draft}
          readOnly={!canOperator}
          onChange={onDraftChange}
        />
        {canOperator ? (
          <Button type="primary" loading={loading} onClick={onSave} style={{ marginTop: 16 }}>
            保存草稿
          </Button>
        ) : null}
      </Card>
      <Card title="当前线上" size="small">
        <ConfigEditor configKey={item.configKey} value={item.published} readOnly />
      </Card>
    </Space>
  );
}

function HistoryList() {
  const [items, setItems] = useState<Array<{ id: number; version: number; note: string | null; publishedAt: string }>>(
    [],
  );

  useEffect(() => {
    void (async () => {
      const data = await unwrap<{ items: typeof items }>(api.get('/config/history'));
      setItems(data.items);
    })();
  }, []);

  return (
    <List
      dataSource={items}
      renderItem={(item) => (
        <List.Item>
          v{item.version} · {formatDateTime(item.publishedAt)} · {item.note || '无备注'}
        </List.Item>
      )}
    />
  );
}
