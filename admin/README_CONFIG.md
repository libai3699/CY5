# 环境配置说明

## 配置文件位置

环境配置文件位于 `apps/web-antd/src/configs/env/` 目录下：

- `dev.js` - 开发环境配置
- `prod.js` - 生产环境配置

## 配置项说明

```javascript
{
  APP_ENV: 'dev',                                    // 环境标识
  APP_TITLE: '9点9 Admin',                           // 应用标题
  APP_NAMESPACE: 'vben-admin',                       // 应用命名空间
  APP_VERSION: '1.0.0',                              // 应用版本
  API_BASE_URL: 'http://192.168.70.54:8080/api/admin', // API 基础地址
  PORT: 5666,                                        // 开发服务器端口
  BASE: '/',                                         // 应用基础路径
  NITRO_MOCK: false,                                 // 是否启用 Mock
  DEVTOOLS: false,                                   // 是否启用 DevTools
  INJECT_APP_LOADING: true,                          // 是否注入全局 Loading
  STORE_SECURE_KEY: 'please-replace-me-with-your-own-key' // Store 加密密钥
}
```

## 启动命令

### 开发环境
```bash
pnpm dev          # 使用开发环境配置启动
```

### 生产构建
```bash
pnpm build:prod   # 使用生产环境配置构建
```

## 环境切换原理

使用 `cross-env` 设置 `APP_ENV` 环境变量，在 `vite.config.ts` 中读取对应的配置文件并注入到应用中。

## 修改配置

1. 修改对应环境的配置文件（`dev.js` 或 `prod.js`）
2. 重启开发服务器或重新构建

## 注意事项

- 生产环境的 `API_BASE_URL` 需要修改为实际的生产环境地址
- `STORE_SECURE_KEY` 建议在生产环境使用强密钥
- 不要将敏感信息（如密钥）提交到版本控制系统
