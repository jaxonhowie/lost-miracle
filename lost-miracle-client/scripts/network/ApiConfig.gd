class_name ApiConfig

const BASE_URL := "http://127.0.0.1:8080/api/v1"
const TIMEOUT := 15.0

## 免鉴权的健康探活端点（服务端 actuator，已在 SecurityConfig 中放行）。
const HEALTH_PATH := "/actuator/health"

## 鉴权失败时服务端返回 HTTP 401（未认证/过期）。
const HTTP_UNAUTHORIZED := 401

## ApiClient 识别 token 过期/无效时使用的客户端业务码（与服务端 40100 登录失败区分）。
const CLIENT_AUTH_EXPIRED_CODE := 40101
const AUTH_FAILURE_MESSAGE := "登录已过期，请重新登录"

## 连接探活参数：在线时低频确认，离线时指数退避快速发现恢复。
const PROBE_INTERVAL_ONLINE := 60.0
const PROBE_INTERVAL_OFFLINE_INIT := 2.0
const PROBE_INTERVAL_OFFLINE_MAX := 30.0

## 云存档重试队列的指数退避参数。
const SYNC_RETRY_INIT_SEC := 3.0
const SYNC_RETRY_MAX_SEC := 60.0
