import axios from 'axios';
import type { ApiResponse } from './types';

const TOKEN_KEY = 'gm_token';

// JSON 响应里 16 位以上整数在 JS 中会丢精度，先转成字符串再 parse
const LARGE_INT_JSON = /(?<=[:,[]\s*)(-?\d{16,})(?=\s*[,}\]])/g;

function parseResponseJson(text: string): unknown {
  try {
    return JSON.parse(text.replace(LARGE_INT_JSON, '"$1"'));
  } catch {
    return JSON.parse(text);
  }
}

// 登录/注册等不需要认证的路径，401/403 时不应自动踢出
const PUBLIC_PATHS = ['/auth/login', '/auth/register'];

export const api = axios.create({
  baseURL: '/api/v1/admin',
  timeout: 15000,
  transformResponse: [(data, headers) => {
    if (typeof data !== 'string' || data.length === 0) {
      return data;
    }
    const contentType = String(headers?.['content-type'] ?? '');
    if (!contentType.includes('application/json')) {
      return data;
    }
    return parseResponseJson(data);
  }],
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
    const bodyCode = error.response?.data?.code as number | undefined;

    // 仅未认证/过期时登出；权限不足(403)保留会话
    const isAuthExpired = status === 401 || bodyCode === 40100;
    if (isAuthExpired && !isPublicPath) {
      localStorage.removeItem(TOKEN_KEY);
      window.dispatchEvent(new Event('gm:auth-expired'));
    }
    const message =
      error.response?.data?.message || error.message || (status === 403 ? '权限不足' : '网络错误');
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
