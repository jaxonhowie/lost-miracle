import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { api, getToken, unwrap } from '../api/client';
import type { GmMeResponse } from '../api/types';

export type GmRole = 'viewer' | 'operator' | 'super';

interface AuthContextValue {
  me: GmMeResponse | null;
  loading: boolean;
  role: GmRole | null;
  canWrite: boolean;
  canOperator: boolean;
  canSuper: boolean;
  refresh: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function normalizeRole(role: string | undefined): GmRole | null {
  if (role === 'viewer' || role === 'operator' || role === 'super') {
    return role;
  }
  return null;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [me, setMe] = useState<GmMeResponse | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = async () => {
    if (!getToken()) {
      setMe(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const profile = await unwrap<GmMeResponse>(api.get('/auth/me'));
      setMe(profile);
    } catch {
      setMe(null);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void refresh();
    const onExpired = () => {
      setMe(null);
      setLoading(false);
    };
    const onLogin = () => {
      void refresh();
    };
    window.addEventListener('gm:auth-expired', onExpired);
    window.addEventListener('gm:auth-login', onLogin);
    return () => {
      window.removeEventListener('gm:auth-expired', onExpired);
      window.removeEventListener('gm:auth-login', onLogin);
    };
  }, []);

  const role = normalizeRole(me?.role);
  const value = useMemo<AuthContextValue>(
    () => ({
      me,
      loading,
      role,
      canWrite: role === 'operator' || role === 'super',
      canOperator: role === 'operator' || role === 'super',
      canSuper: role === 'super',
      refresh,
    }),
    [me, loading, role],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return ctx;
}
