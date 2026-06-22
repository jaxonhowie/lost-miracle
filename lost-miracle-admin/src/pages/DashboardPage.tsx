import { Card, Col, Input, Popconfirm, Row, Space, Statistic, Switch, Typography, message } from 'antd';
import { useEffect, useState } from 'react';
import { api, unwrap } from '../api/client';
import { useAuth } from '../contexts/AuthContext';
import type { ConfigList, SystemSettings } from '../api/types';

export default function DashboardPage() {
  const { me, canSuper } = useAuth();
  const [configVersion, setConfigVersion] = useState(0);
  const [maintenance, setMaintenance] = useState(false);
  const [maintenanceMsg, setMaintenanceMsg] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    void (async () => {
      try {
        const [config, settings] = await Promise.all([
          unwrap<ConfigList>(api.get('/config')),
          unwrap<SystemSettings>(api.get('/system/settings')),
        ]);
        setConfigVersion(config.version);
        setMaintenance(settings.maintenance_mode);
        setMaintenanceMsg(settings.maintenance_message);
      } catch {
        // layout handles auth redirect
      }
    })();
  }, []);

  const toggleMaintenance = async (enabled: boolean) => {
    setLoading(true);
    try {
      await unwrap(api.post('/system/maintenance', {
        enabled,
        message: maintenanceMsg || '服务器维护中，请稍后再试',
      }));
      setMaintenance(enabled);
      message.success(enabled ? '维护模式已开启' : '维护模式已关闭');
    } catch {
      message.error('操作失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <Typography.Title level={3}>仪表盘</Typography.Title>
      <Row gutter={[16, 16]}>
        <Col xs={24} md={8}>
          <Card>
            <Statistic title="当前 GM" value={me?.username || '-'} />
          </Card>
        </Col>
        <Col xs={24} md={8}>
          <Card>
            <Statistic title="GM 角色" value={me?.role || '-'} />
          </Card>
        </Col>
        <Col xs={24} md={8}>
          <Card>
            <Statistic title="配置版本" value={configVersion} />
          </Card>
        </Col>
      </Row>

      {canSuper && (
        <Card
          style={{ marginTop: 16 }}
          title="维护模式"
          extra={
            <Popconfirm
              title={maintenance ? '确认关闭维护模式？' : '确认开启维护模式？玩家将无法登录。'}
              onConfirm={() => toggleMaintenance(!maintenance)}
              okText="确认"
              cancelText="取消"
            >
              <Switch
                checked={maintenance}
                loading={loading}
                checkedChildren="维护中"
                unCheckedChildren="正常"
              />
            </Popconfirm>
          }
        >
          <Space direction="vertical" style={{ width: '100%' }}>
            <Typography.Text type={maintenance ? 'danger' : 'success'}>
              {maintenance ? '⚠ 服务器处于维护模式，玩家无法登录' : '✅ 服务器正常运行'}
            </Typography.Text>
            <Input
              placeholder="维护提示消息"
              value={maintenanceMsg}
              onChange={(e) => setMaintenanceMsg(e.target.value)}
              disabled={!canSuper}
            />
          </Space>
        </Card>
      )}

      <Card style={{ marginTop: 16 }}>
        <Typography.Paragraph>
          掉率、探索权重等配置在「配置中心」编辑草稿后点击发布；玩家登录或进主菜单时会拉取最新 bundle。
        </Typography.Paragraph>
      </Card>
    </div>
  );
}
