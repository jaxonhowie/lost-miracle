import {
  Alert,
  Button,
  Card,
  Form,
  Input,
  InputNumber,
  Modal,
  Space,
  Typography,
  message,
} from 'antd';
import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, unwrap } from '../api/client';
import type { CharacterSave } from '../api/types';

export default function CharacterPage() {
  const { characterId } = useParams();
  const navigate = useNavigate();
  const [save, setSave] = useState<CharacterSave | null>(null);
  const [jsonText, setJsonText] = useState('');
  const [previewToken, setPreviewToken] = useState('');
  const [changes, setChanges] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    if (!characterId) return;
    const data = await unwrap<CharacterSave>(api.get(`/characters/${characterId}/save`));
    setSave(data);
    setJsonText(JSON.stringify(data.save, null, 2));
  };

  useEffect(() => {
    void load().catch((e) => message.error(e instanceof Error ? e.message : '加载失败'));
  }, [characterId]);

  const patchFields = async (values: Record<string, number | undefined>) => {
    if (!characterId) return;
    setLoading(true);
    try {
      await unwrap(api.patch(`/characters/${characterId}/save/fields`, values));
      message.success('字段已更新');
      await load();
    } catch (e) {
      message.error(e instanceof Error ? e.message : '更新失败');
    } finally {
      setLoading(false);
    }
  };

  const previewReplace = async () => {
    if (!characterId) return;
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(jsonText) as Record<string, unknown>;
    } catch {
      message.error('JSON 格式无效');
      return;
    }
    setLoading(true);
    try {
      const data = await unwrap<{
        confirmToken: string;
        changes: string[];
      }>(api.post(`/characters/${characterId}/save/preview`, parsed));
      setPreviewToken(data.confirmToken);
      setChanges(data.changes);
      message.info('请确认 diff 后提交');
    } catch (e) {
      message.error(e instanceof Error ? e.message : '预览失败');
    } finally {
      setLoading(false);
    }
  };

  const confirmReplace = () => {
    if (!characterId || !previewToken) return;
    Modal.confirm({
      title: '确认替换完整存档？',
      content: (
        <div>
          <Typography.Paragraph>变更摘要：</Typography.Paragraph>
          <ul>
            {changes.map((c) => (
              <li key={c}>{c}</li>
            ))}
          </ul>
        </div>
      ),
      okText: '确认替换',
      okType: 'danger',
      onOk: async () => {
        let parsed: Record<string, unknown>;
        try {
          parsed = JSON.parse(jsonText) as Record<string, unknown>;
        } catch {
          message.error('JSON 格式无效');
          return;
        }
        const reason = window.prompt('请输入改档原因（必填）');
        if (!reason?.trim()) {
          message.warning('必须填写原因');
          return;
        }
        await unwrap(
          api.put(`/characters/${characterId}/save`, {
            save: parsed,
            confirmToken: previewToken,
            reason: reason.trim(),
          }),
        );
        message.success('存档已替换');
        setPreviewToken('');
        await load();
      },
    });
  };

  if (!save) {
    return <Card loading />;
  }

  const player = (save.save.player || {}) as Record<string, number>;

  return (
    <div>
      <Space style={{ marginBottom: 16 }}>
        <Button onClick={() => navigate('/players')}>返回</Button>
        <Typography.Title level={3} style={{ margin: 0 }}>
          角色 {characterId}
        </Typography.Title>
      </Space>

      <Card title="常用字段（operator）" style={{ marginBottom: 16 }}>
        <Form
          layout="inline"
          initialValues={{
            gold: player.gold,
            level: player.level,
            exp: player.exp,
            enhanceStone: player.enhance_stone,
            healthPotion: player.health_potion,
          }}
          onFinish={(v) => void patchFields(v)}
        >
          <Form.Item name="gold" label="金币">
            <InputNumber min={0} />
          </Form.Item>
          <Form.Item name="level" label="等级">
            <InputNumber min={1} max={100} />
          </Form.Item>
          <Form.Item name="exp" label="经验">
            <InputNumber min={0} />
          </Form.Item>
          <Form.Item name="enhanceStone" label="强化石">
            <InputNumber min={0} />
          </Form.Item>
          <Form.Item name="healthPotion" label="药水">
            <InputNumber min={0} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={loading}>
              保存字段
            </Button>
          </Form.Item>
        </Form>
      </Card>

      <Card title="完整存档 JSON（super + 二次确认）">
        <Alert
          type="warning"
          showIcon
          message="修改背包装备等复杂数据请在此编辑，先预览 diff 再确认替换。"
          style={{ marginBottom: 12 }}
        />
        <Input.TextArea rows={18} value={jsonText} onChange={(e) => setJsonText(e.target.value)} />
        <Space style={{ marginTop: 12 }}>
          <Button onClick={() => void previewReplace()} loading={loading}>
            预览 Diff
          </Button>
          <Button type="primary" danger disabled={!previewToken} onClick={confirmReplace}>
            确认替换
          </Button>
        </Space>
      </Card>
    </div>
  );
}
