import { useEffect, useState } from 'react';
import { Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { getToken } from './api/client';
import AdminLayout from './layouts/AdminLayout';
import AuditPage from './pages/AuditPage';
import CharacterPage from './pages/CharacterPage';
import ConfigPage from './pages/ConfigPage';
import DashboardPage from './pages/DashboardPage';
import LoginPage from './pages/LoginPage';
import PlayersPage from './pages/PlayersPage';
import SpawnsPage from './pages/SpawnsPage';

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
    <AuthExpiredHandler>
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
          <Route path="audit" element={<AuditPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AuthExpiredHandler>
  );
}
