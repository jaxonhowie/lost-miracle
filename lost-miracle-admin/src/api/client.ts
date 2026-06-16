import axios from 'axios';
import type { ApiResponse } from './types';

const TOKEN_KEY = 'gm_token';

// 登录/注册等不需要认证的路径，401/403 时不应自动踢出
const PUBLIC_PATHS = ['/auth/login', '/auth/register'];

export const api = axios.create({
  baseURL: '/api/v1/admin',
  timeout: 15000,
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => {
    const body = response.data as ApiResponse<unknown>;
    if (body.code !== 0) {
      return Promise.reject(new Error(body.message || '请求失败'));
    }
    return response;
  },
  (error) => {
    const status = error.response?.status;
    const url = error.config?.url || '';
    const isPublicPath = PUBLIC_PATHS.some((p) => url.includes(p));

    if ((status === 401 || status === 403) && !isPublicPath) {
      localStorage.removeItem(TOKEN_KEY);
      // 使用 React Router 导航而非硬刷新，避免破坏路由状态
      // 通过自定义事件通知 App 层处理跳转
      window.dispatchEvent(new Event('gm:auth-expired'));
    }
    const message = error.response?.data?.message || error.message || '网络错误';
    return Promise.reject(new Error(message));
  },
);

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

export async function unwrap<T>(promise: Promise<{ data: ApiResponse<T> }>): Promise<T> {
  const { data } = await promise;
  return data.data;
}
