import { Button, Card, Input, List, Modal, Space, Tabs, Typography, message } from 'antd';
import { useEffect, useState } from 'react';
import { api, unwrap } from '../api/client';
import type { ConfigItem, ConfigList } from '../api/types';

export default function ConfigPage() {
  const [configList, setConfigList] = useState<ConfigList | null>(null);
  const [activeKey, setActiveKey] = useState('');
  const [draftText, setDraftText] = useState('');
  const [loading, setLoading] = useState(false);

  const load = async () => {
    const data = await unwrap<ConfigList>(api.get('/config'));
    setConfigList(data);
    if (!activeKey && data.items.length > 0) {
      setActiveKey(data.items[0].configKey);
      setDraftText(JSON.stringify(data.items[0].draft, null, 2));
    }
  };

  useEffect(() => {
    void load().catch((e) => message.error(e instanceof Error ? e.message : '加载失败'));
  }, []);

  const selectKey = (item: ConfigItem) => {
    setActiveKey(item.configKey);
    setDraftText(JSON.stringify(item.draft, null, 2));
  };

  const saveDraft = async () => {
    if (!activeKey) return;
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(draftText) as Record<string, unknown>;
    } catch {
      message.error('JSON 格式无效');
      return;
    }
    setLoading(true);
    try {
      await unwrap(api.put(`/config/${encodeURIComponent(activeKey)}`, { json: parsed }));
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
        <Card>
          <Typography.Paragraph type="secondary">Key: {item.configKey}</Typography.Paragraph>
          <Input.TextArea rows={16} value={draftText} onChange={(e) => setDraftText(e.target.value)} />
          <Space style={{ marginTop: 12 }}>
            <Button type="primary" loading={loading} onClick={() => void saveDraft()}>
              保存草稿
            </Button>
          </Space>
          <Typography.Title level={5} style={{ marginTop: 16 }}>
            当前线上
          </Typography.Title>
          <pre style={{ background: '#fafafa', padding: 12, overflow: 'auto' }}>
            {JSON.stringify(item.published, null, 2)}
          </pre>
        </Card>
      ),
    })) || [];

  return (
    <div>
      <Space style={{ marginBottom: 16, width: '100%', justifyContent: 'space-between' }}>
        <Typography.Title level={3} style={{ margin: 0 }}>
          配置中心 {configList ? `(v${configList.version})` : ''}
        </Typography.Title>
        <Button type="primary" danger onClick={publish}>
          发布到线上
        </Button>
      </Space>
      <Tabs
        activeKey={activeKey}
        items={items}
        onChange={(key) => {
          const item = configList?.items.find((i) => i.configKey === key);
          if (item) selectKey(item);
        }}
      />
      {configList ? (
        <Card title="发布历史" style={{ marginTop: 16 }}>
          <HistoryList />
        </Card>
      ) : null}
    </div>
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
          v{item.version} · {item.publishedAt} · {item.note || '无备注'}
        </List.Item>
      )}
    />
  );
}
