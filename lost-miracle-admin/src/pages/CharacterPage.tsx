import { Alert, Button, Card, Modal, Space, Table, Typography, message } from 'antd';
import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, unwrap } from '../api/client';
import { extractOperatorPatch, SaveEditor } from '../components/save/SaveEditor';
import { useAuth } from '../contexts/AuthContext';
import type { CharacterSave } from '../api/types';

function cloneSave(save: Record<string, unknown>): Record<string, unknown> {
  return JSON.parse(JSON.stringify(save)) as Record<string, unknown>;
}

function parseChangeLine(line: string): { field: string; before: string; after: string } {
  const splitAt = line.indexOf(': ');
  if (splitAt < 0) {
    return { field: line, before: '-', after: '-' };
  }
  const field = line.slice(0, splitAt);
  const rest = line.slice(splitAt + 2);
  const arrowAt = rest.indexOf(' → ');
  if (arrowAt < 0) {
    return { field, before: '-', after: rest };
  }
  return {
    field,
    before: rest.slice(0, arrowAt),
    after: rest.slice(arrowAt + 3),
  };
}

export default function CharacterPage() {
  const { characterId } = useParams();
  const navigate = useNavigate();
  const { canOperator, canSuper } = useAuth();
  const [save, setSave] = useState<CharacterSave | null>(null);
  const [draft, setDraft] = useState<Record<string, unknown>>({});
  const [previewToken, setPreviewToken] = useState('');
  const [previewMeta, setPreviewMeta] = useState<{ beforeChecksum: string; afterChecksum: string } | null>(null);
  const [changes, setChanges] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    if (!characterId) return;
    const data = await unwrap<CharacterSave>(api.get(`/characters/${characterId}/save`));
    setSave(data);
    setDraft(cloneSave(data.save));
    setPreviewToken('');
    setPreviewMeta(null);
    setChanges([]);
  };

  useEffect(() => {
    void load().catch((e) => message.error(e instanceof Error ? e.message : '加载失败'));
  }, [characterId]);

  const patchFields = async () => {
    if (!characterId) return;
    const player = (draft.player || {}) as Record<string, unknown>;
    setLoading(true);
    try {
      await unwrap(api.patch(`/characters/${characterId}/save/fields`, extractOperatorPatch(player)));
      message.success('常用字段已保存');
      await load();
    } catch (e) {
      message.error(e instanceof Error ? e.message : '保存失败');
    } finally {
      setLoading(false);
    }
  };

  const previewReplace = async () => {
    if (!characterId) return;
    setLoading(true);
    try {
      const data = await unwrap<{
        confirmToken: string;
        beforeChecksum: string;
        afterChecksum: string;
        changes: string[];
      }>(api.post(`/characters/${characterId}/save/preview`, draft));
      setPreviewToken(data.confirmToken);
      setPreviewMeta({ beforeChecksum: data.beforeChecksum, afterChecksum: data.afterChecksum });
      setChanges(data.changes ?? []);
      if (!data.changes?.length) {
        message.warning('未检测到变更');
      } else {
        message.success(`已生成 ${data.changes.length} 条变更摘要，请确认后替换`);
      }
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
        const reason = window.prompt('请输入改档原因（必填）');
        if (!reason?.trim()) {
          message.warning('必须填写原因');
          return;
        }
        await unwrap(
          api.put(`/characters/${characterId}/save`, {
            save: draft,
            confirmToken: previewToken,
            reason: reason.trim(),
          }),
        );
        message.success('存档已替换');
        await load();
      },
    });
  };

  if (!save) {
    return <Card loading />;
  }

  return (
    <div>
      <Space style={{ marginBottom: 16 }}>
        <Button onClick={() => navigate('/players')}>返回</Button>
        <Typography.Title level={3} style={{ margin: 0 }}>
          角色 {characterId}
        </Typography.Title>
        <Typography.Text type="secondary">
          存档 v{save.saveVersion} · checksum {save.checksum.slice(0, 8)}…
        </Typography.Text>
      </Space>

      <Card
        title="角色存档"
        extra={
          canOperator && !canSuper ? (
            <Button type="primary" loading={loading} onClick={() => void patchFields()}>
              保存常用字段
            </Button>
          ) : null
        }
      >
        {!canOperator && !canSuper ? (
          <Alert type="info" showIcon message="当前账号只读，无法修改存档。" style={{ marginBottom: 16 }} />
        ) : null}
        {canSuper ? (
          <Alert
            type="warning"
            showIcon
            message="super 可编辑完整存档。修改后先预览 Diff，再确认替换。"
            style={{ marginBottom: 16 }}
          />
        ) : canOperator ? (
          <Alert
            type="info"
            showIcon
            message="operator 可修改常用字段；装备与背包需 super 权限。"
            style={{ marginBottom: 16 }}
          />
        ) : null}

        <SaveEditor
          value={draft}
          onChange={setDraft}
          canEditPlayerFields={canOperator || canSuper}
          canEditFull={canSuper}
        />

        {canSuper ? (
          <>
            <Space style={{ marginTop: 16 }}>
              <Button onClick={() => void previewReplace()} loading={loading}>
                预览 Diff
              </Button>
              <Button type="primary" danger disabled={!previewToken} onClick={confirmReplace}>
                确认替换
              </Button>
              <Button
                onClick={() => {
                  setDraft(cloneSave(save.save));
                  setPreviewToken('');
                  setPreviewMeta(null);
                  setChanges([]);
                }}
              >
                撤销修改
              </Button>
            </Space>
            {previewToken ? (
              <Card size="small" title="变更预览" style={{ marginTop: 16 }}>
                {previewMeta ? (
                  <Typography.Paragraph type="secondary" style={{ marginBottom: 8 }}>
                    checksum {previewMeta.beforeChecksum.slice(0, 8)}… → {previewMeta.afterChecksum.slice(0, 8)}…
                  </Typography.Paragraph>
                ) : null}
                {changes.length === 0 ? (
                  <Typography.Text type="secondary">无变更</Typography.Text>
                ) : (
                  <Table
                    size="small"
                    pagination={false}
                    rowKey={(row) => `${row.field}-${row.before}-${row.after}`}
                    dataSource={changes.map(parseChangeLine)}
                    columns={[
                      { title: '字段', dataIndex: 'field', width: 180 },
                      { title: '原值', dataIndex: 'before' },
                      { title: '新值', dataIndex: 'after' },
                    ]}
                  />
                )}
              </Card>
            ) : null}
          </>
        ) : null}
      </Card>
    </div>
  );
}
