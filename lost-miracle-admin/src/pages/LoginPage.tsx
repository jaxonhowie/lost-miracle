import { LockOutlined, UserOutlined } from '@ant-design/icons';
import { Alert, Button, Card, Form, Input, Typography } from 'antd';
import { useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { api, getToken, setToken, unwrap } from '../api/client';
import type { GmAuthResponse } from '../api/types';

export default function LoginPage() {
  const navigate = useNavigate();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  if (getToken()) {
    return <Navigate to="/" replace />;
  }

  const onFinish = async (values: { username: string; password: string }) => {
    setLoading(true);
    setError('');
    try {
      const data = await unwrap<GmAuthResponse>(
        api.post('/auth/login', values),
      );
      setToken(data.token);
      navigate('/');
    } catch (e) {
      setError(e instanceof Error ? e.message : '登录失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
      <Card style={{ width: 400 }}>
        <Typography.Title level={3} style={{ textAlign: 'center' }}>
          GM 登录
        </Typography.Title>
        {error ? <Alert type="error" message={error} style={{ marginBottom: 16 }} /> : null}
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item name="username" label="用户名" rules={[{ required: true }]}>
            <Input prefix={<UserOutlined />} placeholder="super" />
          </Form.Item>
          <Form.Item name="password" label="密码" rules={[{ required: true }]}>
            <Input.Password prefix={<LockOutlined />} />
          </Form.Item>
          <Button type="primary" htmlType="submit" block loading={loading}>
            登录
          </Button>
        </Form>
      </Card>
    </div>
  );
}
