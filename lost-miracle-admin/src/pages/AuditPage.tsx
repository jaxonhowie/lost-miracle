import { Button, Modal, Table, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { api, unwrap } from '../api/client';
import type { AuditLog } from '../api/types';
import { formatDateTime } from '../utils/formatDateTime';

function formatDetailJson(raw: string): string {
  try {
    return JSON.stringify(JSON.parse(raw), null, 2);
  } catch {
    return raw;
  }
}

export default function AuditPage() {
  const [rows, setRows] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(false);
  const [detailRow, setDetailRow] = useState<AuditLog | null>(null);

  useEffect(() => {
    void (async () => {
      setLoading(true);
      try {
        const data = await unwrap<{ items: AuditLog[] }>(api.get('/audit-log'));
        setRows(data.items);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  return (
    <div>
      <Typography.Title level={3}>审计日志</Typography.Title>
      <Table
        rowKey="id"
        loading={loading}
        dataSource={rows}
        pagination={{ pageSize: 20 }}
        columns={[
          {
            title: '时间',
            dataIndex: 'createdAt',
            width: 180,
            render: (v: string) => formatDateTime(v),
          },
          { title: 'GM', dataIndex: 'gmAccountId', width: 80 },
          { title: '动作', dataIndex: 'action', width: 160 },
          { title: '目标类型', dataIndex: 'targetType', width: 100 },
          { title: '目标 ID', dataIndex: 'targetId', width: 120 },
          { title: 'IP', dataIndex: 'ip', width: 120 },
          {
            title: '详情',
            dataIndex: 'detailJson',
            width: 100,
            render: (_: string | null, row: AuditLog) =>
              row.detailJson ? (
                <Button type="link" size="small" onClick={() => setDetailRow(row)}>
                  查看
                </Button>
              ) : (
                '-'
              ),
          },
        ]}
      />
      <Modal
        title={detailRow ? `${detailRow.action} · 详情` : '详情'}
        open={detailRow !== null}
        onCancel={() => setDetailRow(null)}
        footer={null}
        width={640}
        destroyOnClose
      >
        {detailRow?.detailJson ? (
          <pre
            style={{
              margin: 0,
              maxHeight: 480,
              overflow: 'auto',
              padding: 12,
              background: '#f5f5f5',
              borderRadius: 6,
              fontSize: 13,
              lineHeight: 1.5,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-word',
            }}
          >
            {formatDetailJson(detailRow.detailJson)}
          </pre>
        ) : (
          <Typography.Text type="secondary">无详情</Typography.Text>
        )}
      </Modal>
    </div>
  );
}
