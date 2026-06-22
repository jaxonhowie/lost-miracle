import { lazy, Suspense, useEffect, useState } from 'react';
import { Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { Spin } from 'antd';
import { getToken } from './api/client';
import { AuthProvider } from './contexts/AuthContext';
import AdminLayout from './layouts/AdminLayout';

const LoginPage = lazy(() => import('./pages/LoginPage'));
const DashboardPage = lazy(() => import('./pages/DashboardPage'));
const PlayersPage = lazy(() => import('./pages/PlayersPage'));
const CharacterPage = lazy(() => import('./pages/CharacterPage'));
const SpawnsPage = lazy(() => import('./pages/SpawnsPage'));
const ConfigPage = lazy(() => import('./pages/ConfigPage'));
const AuditPage = lazy(() => import('./pages/AuditPage'));
const MailPage = lazy(() => import('./pages/MailPage'));

function PageFallback() {
  return <Spin size="large" style={{ display: 'block', margin: '48px auto' }} />;
}

function RequireAuth({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState(getToken());

  useEffect(() => {
    // 监听认证过期事件，响应式更新
    const onAuthExpired = () => setToken(null);
    window.addEventListener('gm:auth-expired', onAuthExpired);
    return () => window.removeEventListener('gm:auth-expired', onAuthExpired);
  }, []);

  if (!token) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}

/** 全局认证过期跳转处理器 */
function AuthExpiredHandler({ children }: { children: React.ReactNode }) {
  const navigate = useNavigate();

  useEffect(() => {
    const onAuthExpired = () => navigate('/login', { replace: true });
    window.addEventListener('gm:auth-expired', onAuthExpired);
    return () => window.removeEventListener('gm:auth-expired', onAuthExpired);
  }, [navigate]);

  return <>{children}</>;
}

export default function App() {
  return (
    <AuthProvider>
      <AuthExpiredHandler>
        <Suspense fallback={<PageFallback />}>
          <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            path="/"
            element={
              <RequireAuth>
                <AdminLayout />
              </RequireAuth>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="players" element={<PlayersPage />} />
            <Route path="characters/:characterId" element={<CharacterPage />} />
            <Route path="spawns" element={<SpawnsPage />} />
            <Route path="config" element={<ConfigPage />} />
            <Route path="mail" element={<MailPage />} />
            <Route path="audit" element={<AuditPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Suspense>
      </AuthExpiredHandler>
    </AuthProvider>
  );
}
