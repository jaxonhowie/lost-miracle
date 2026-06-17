import { Button, Input, Space, Table, Tag, Typography } from 'antd';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api, unwrap } from '../api/client';
import type { CharacterList, GmUserList, GmUserSummary } from '../api/types';

export default function PlayersPage() {
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [users, setUsers] = useState<GmUserSummary[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [characters, setCharacters] = useState<CharacterList['items']>([]);

  const search = async () => {
    if (!query.trim()) return;
    setLoading(true);
    try {
      const data = await unwrap<GmUserList>(api.get('/users', { params: { q: query.trim() } }));
      setUsers(data.items);
      setSelectedUserId(null);
      setCharacters([]);
    } finally {
      setLoading(false);
    }
  };

  const loadCharacters = async (userId: string) => {
    setSelectedUserId(userId);
    const data = await unwrap<CharacterList>(api.get(`/users/${userId}/characters`));
    setCharacters(data.items);
  };

  return (
    <div>
      <Typography.Title level={3}>玩家管理</Typography.Title>
      <Space style={{ marginBottom: 16 }}>
        <Input
          placeholder="用户名或用户 ID"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onPressEnter={() => void search()}
          style={{ width: 280 }}
        />
        <Button type="primary" onClick={() => void search()} loading={loading}>
          搜索
        </Button>
      </Space>

      <Table
        rowKey="id"
        dataSource={users}
        pagination={false}
        columns={[
          { title: 'ID', dataIndex: 'id' },
          { title: '用户名', dataIndex: 'username' },
          {
            title: '状态',
            dataIndex: 'status',
            render: (v: number) => (v === 1 ? <Tag color="green">正常</Tag> : <Tag color="red">封禁</Tag>),
          },
          {
            title: '操作',
            render: (_, row) => (
              <Button type="link" onClick={() => void loadCharacters(row.id)}>
                查看角色
              </Button>
            ),
          },
        ]}
      />

      {selectedUserId !== null ? (
        <Table
          style={{ marginTop: 24 }}
          rowKey="id"
          dataSource={characters}
          title={() => `用户 ${selectedUserId} 的角色`}
          columns={[
            { title: '角色 ID', dataIndex: 'id' },
            { title: '名称', dataIndex: 'name' },
            { title: '等级', dataIndex: 'level' },
            { title: '战力', dataIndex: 'powerScore' },
            { title: '地牢', dataIndex: 'currentDungeonId' },
            {
              title: '存档',
              render: (_, row) => <Link to={`/characters/${row.id}`}>编辑存档</Link>,
            },
          ]}
        />
      ) : null}
    </div>
  );
}
