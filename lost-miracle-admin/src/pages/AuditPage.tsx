import { Table, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { api, unwrap } from '../api/client';
import type { AuditLog } from '../api/types';

export default function AuditPage() {
  const [rows, setRows] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(false);

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
          { title: '时间', dataIndex: 'createdAt', width: 180 },
          { title: 'GM', dataIndex: 'gmAccountId', width: 80 },
          { title: '动作', dataIndex: 'action', width: 160 },
          { title: '目标类型', dataIndex: 'targetType', width: 100 },
          { title: '目标 ID', dataIndex: 'targetId', width: 120 },
          { title: 'IP', dataIndex: 'ip', width: 120 },
          {
            title: '详情',
            dataIndex: 'detailJson',
            ellipsis: true,
            render: (v: string | null) => v || '-',
          },
        ]}
      />
    </div>
  );
}
