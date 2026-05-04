# CY5 Admin 后台管理系统

基于 Vue 3 + Vite + Ant Design Vue 的后台管理系统。

## 技术栈

- Vue 3
- Vite 6
- Ant Design Vue 4
- Vue Router 4
- Pinia
- TypeScript
- Axios

## 环境配置

配置文件位于 `src/configs/env/` 目录：

- `dev.js` - 开发环境
- `prod.js` - 生产环境

## 开发

```bash
# 安装依赖
pnpm install

# 启动开发服务器
pnpm dev

# 构建生产版本
pnpm build:prod

# 预览生产构建
pnpm preview
```

## 配置说明

修改 `src/configs/env/dev.js` 或 `prod.js` 中的配置：

```javascript
{
  APP_ENV: 'dev',
  APP_TITLE: '9点9 Admin',
  APP_NAMESPACE: 'vben-admin',
  APP_VERSION: '1.0.0',
  API_BASE_URL: 'http://192.168.70.54:8080/api/admin',
  PORT: 5666,
  // ...
}
```

## 目录结构

```
admin/
├── public/          # 静态资源
├── src/
│   ├── api/         # API 接口
│   ├── assets/      # 资源文件
│   ├── components/  # 组件
│   ├── configs/     # 配置文件
│   │   └── env/     # 环境配置
│   ├── layouts/     # 布局
│   ├── router/      # 路由
│   ├── store/       # 状态管理
│   ├── views/       # 页面
│   ├── app.vue      # 根组件
│   ├── bootstrap.ts # 启动文件
│   └── main.ts      # 入口文件
├── index.html
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## 默认账号

- 用户名: `admin`
- 密码: `admin123456`
