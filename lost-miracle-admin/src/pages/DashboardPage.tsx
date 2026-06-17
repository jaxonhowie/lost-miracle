import { Card, Col, Row, Statistic, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { api, unwrap } from '../api/client';
import { useAuth } from '../contexts/AuthContext';
import type { ConfigList } from '../api/types';

export default function DashboardPage() {
  const { me } = useAuth();
  const [configVersion, setConfigVersion] = useState(0);

  useEffect(() => {
    void (async () => {
      try {
        const config = await unwrap<ConfigList>(api.get('/config'));
        setConfigVersion(config.version);
      } catch {
        // layout handles auth redirect
      }
    })();
  }, []);

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
      <Card style={{ marginTop: 16 }}>
        <Typography.Paragraph>
          掉率、探索权重等配置在「配置中心」编辑草稿后点击发布；玩家登录或进主菜单时会拉取最新 bundle。
        </Typography.Paragraph>
      </Card>
    </div>
  );
}
