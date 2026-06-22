import {
  AuditOutlined,
  CloudServerOutlined,
  DashboardOutlined,
  MailOutlined,
  SettingOutlined,
  TeamOutlined,
  ThunderboltOutlined,
} from '@ant-design/icons';
import { Layout, Menu, Typography } from 'antd';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';
import { clearToken } from '../api/client';

const { Header, Sider, Content } = Layout;

const items = [
  { key: '/', icon: <DashboardOutlined />, label: '仪表盘' },
  { key: '/players', icon: <TeamOutlined />, label: '玩家管理' },
  { key: '/spawns', icon: <ThunderboltOutlined />, label: '刷怪状态' },
  { key: '/config', icon: <SettingOutlined />, label: '配置中心' },
  { key: '/mail', icon: <MailOutlined />, label: '邮件管理' },
  { key: '/audit', icon: <AuditOutlined />, label: '审计日志' },
];

export default function AdminLayout() {
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider breakpoint="lg" collapsedWidth={64}>
        <div style={{ padding: 16, color: '#fff', fontWeight: 700 }}>
          <CloudServerOutlined /> GM
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[location.pathname === '/' ? '/' : `/${location.pathname.split('/')[1]}`]}
          items={items}
          onClick={({ key }) => navigate(key)}
        />
      </Sider>
      <Layout>
        <Header
          style={{
            background: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            paddingInline: 24,
          }}
        >
          <Typography.Title level={4} style={{ margin: 0 }}>
            失落奇迹 · GM 后台
          </Typography.Title>
          <Typography.Link
            onClick={() => {
              clearToken();
              window.dispatchEvent(new Event('gm:auth-expired'));
            }}
          >
            退出登录
          </Typography.Link>
        </Header>
        <Content style={{ margin: 24 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
