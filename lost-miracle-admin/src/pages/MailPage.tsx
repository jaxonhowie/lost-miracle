import { useState } from 'react';
import {
  Alert,
  Button,
  Card,
  Checkbox,
  Col,
  Form,
  Input,
  InputNumber,
  Modal,
  Row,
  Space,
  Typography,
  message,
} from 'antd';
import { SendOutlined, TeamOutlined } from '@ant-design/icons';
import { api, unwrap } from '../api/client';
import type { AdminSendMailResponse } from '../api/types';
import { useAuth } from '../contexts/AuthContext';

const ATTACHMENT_FIELDS = [
  { key: 'gold', label: '金币', min: 0, max: 1000000 },
  { key: 'enhance_stone', label: '强化石', min: 0, max: 99999 },
  { key: 'blessed_enhance_stone', label: '祝福强化石', min: 0, max: 9999 },
  { key: 'jewelry_enhance_stone', label: '首饰强化石', min: 0, max: 99999 },
  { key: 'blessed_jewelry_enhance_stone', label: '祝福首饰强化石', min: 0, max: 9999 },
  { key: 'health_potion', label: '生命药水', min: 0, max: 9999 },
];

export default function MailPage() {
  const { canOperator } = useAuth();
  const [form] = Form.useForm();
  const [broadcast, setBroadcast] = useState(false);
  const [sending, setSending] = useState(false);

  const handleSend = async () => {
    try {
      const values = await form.validateFields();
      const attachments: Record<string, number> = {};
      for (const field of ATTACHMENT_FIELDS) {
        const val = values[field.key];
        if (val != null && val > 0) {
          attachments[field.key] = val;
        }
      }

      const body = {
        characterId: broadcast ? null : (values.characterId || null),
        title: values.title,
        body: values.body,
        attachments: Object.keys(attachments).length > 0 ? attachments : undefined,
      };

      if (broadcast) {
        Modal.confirm({
          title: '确认全服群发',
          content: `即将向所有角色发送邮件「${values.title}」，确定继续？`,
          okText: '确认发送',
          okType: 'danger',
          onOk: () => doSend(body),
        });
      } else {
        await doSend(body);
      }
    } catch {
      // validation failed
    }
  };

  const doSend = async (body: Record<string, unknown>) => {
    setSending(true);
    try {
      const result = await unwrap<AdminSendMailResponse>(api.post('/mail/send', body));
      message.success(`发送成功，共 ${result.sent} 封`);
      form.resetFields();
    } catch {
      message.error('发送失败');
    } finally {
      setSending(false);
    }
  };

  return (
    <div>
      <Typography.Title level={3}>邮件管理</Typography.Title>
      <Row gutter={16}>
        <Col xs={24} lg={16}>
          <Card title="发送邮件" extra={<SendOutlined />}>
            <Form form={form} layout="vertical" disabled={!canOperator}>
              <Form.Item label="发送目标">
                <Space>
                  <Checkbox checked={broadcast} onChange={(e) => setBroadcast(e.target.checked)}>
                    <TeamOutlined /> 全服群发
                  </Checkbox>
                </Space>
              </Form.Item>

              {!broadcast && (
                <Form.Item
                  name="characterId"
                  label="角色 ID"
                  rules={[{ required: !broadcast, message: '请输入角色 ID 或勾选全服群发' }]}
                >
                  <InputNumber style={{ width: '100%' }} placeholder="输入角色 ID" min={1} />
                </Form.Item>
              )}

              <Form.Item name="title" label="邮件标题" rules={[{ required: true, message: '请输入标题' }]}>
                <Input placeholder="邮件标题" maxLength={100} />
              </Form.Item>

              <Form.Item name="body" label="邮件正文" rules={[{ required: true, message: '请输入正文' }]}>
                <Input.TextArea placeholder="邮件正文" rows={4} maxLength={1000} />
              </Form.Item>

              <Card type="inner" title="附件（可选）" size="small" style={{ marginBottom: 16 }}>
                <Row gutter={[16, 8]}>
                  {ATTACHMENT_FIELDS.map((field) => (
                    <Col xs={12} sm={8} key={field.key}>
                      <Form.Item name={field.key} label={field.label} style={{ marginBottom: 0 }}>
                        <InputNumber min={0} max={field.max} style={{ width: '100%' }} placeholder="0" />
                      </Form.Item>
                    </Col>
                  ))}
                </Row>
              </Card>

              <Form.Item>
                <Button
                  type="primary"
                  icon={<SendOutlined />}
                  loading={sending}
                  onClick={handleSend}
                  size="large"
                >
                  {broadcast ? '全服群发' : '发送'}
                </Button>
              </Form.Item>
            </Form>
          </Card>
        </Col>

        <Col xs={24} lg={8}>
          <Card title="说明">
            <Alert
              type="info"
              showIcon
              message="附件说明"
              description={
                <ul style={{ paddingLeft: 16, margin: 0 }}>
                  <li>附件字段对应玩家存档的增量值</li>
                  <li>例如金币填 100 = 玩家领取后 +100 金币</li>
                  <li>留空或填 0 表示不附带该物品</li>
                  <li>全服群发将向所有角色发送相同邮件</li>
                </ul>
              }
            />
          </Card>
        </Col>
      </Row>
    </div>
  );
}
