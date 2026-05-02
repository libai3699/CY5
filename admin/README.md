# Vue Vben Admin - 精简版

## 📋 项目说明

基于 Vue 3 + Vite + TypeScript + Ant Design Vue 的企业级中后台管理系统。

**特点**:
- ✅ 只保留 Ant Design Vue 版本
- ✅ 完整的用户管理 CRUD 功能
- ✅ 精简的菜单结构
- ✅ Mock 后端服务
- ✅ JWT 认证

---

## 🚀 快速开始

### 1. 安装依赖
```bash
pnpm install
```

### 2. 启动开发
```bash
# 启动前端
pnpm dev

# 启动后端 Mock 服务
pnpm dev:mock
```

### 3. 访问应用
- **前端**: http://localhost:5173
- **后端**: http://localhost:5320

### 4. 登录
- **用户名**: `vben`
- **密码**: `123456`

---

## 📦 项目结构

```
admin/
├── apps/
│   ├── web-antd/              # 前端应用
│   │   ├── src/
│   │   │   ├── api/           # API 接口
│   │   │   │   └── core/
│   │   │   │       ├── auth.ts    # 认证接口
│   │   │   │       └── user.ts    # 用户接口
│   │   │   ├── views/         # 页面
│   │   │   │   ├── _core/     # 核心页面（登录、错误页等）
│   │   │   │   ├── dashboard/ # 工作台
│   │   │   │   └── system/    # 系统管理
│   │   │   │       └── user/  # 用户管理
│   │   │   ├── router/        # 路由
│   │   │   ├── store/         # 状态管理
│   │   │   └── ...
│   │   └── package.json
│   └── backend-mock/          # Mock 后端
│       ├── api/               # API 路由
│       │   ├── auth/          # 认证接口
│       │   ├── user/          # 用户接口
│       │   ├── menu/          # 菜单接口
│       │   └── system/        # 系统管理接口
│       ├── utils/             # 工具函数
│       └── package.json
└── packages/                  # 共享包
```

---

## 🎯 核心功能

### 已实现
- ✅ **用户认证** - 登录、登出、Token 刷新
- ✅ **用户管理** - 完整的 CRUD 操作
  - 用户列表（分页）
  - 创建用户
  - 编辑用户
  - 删除用户
- ✅ **权限管理** - 基于角色的权限控制
- ✅ **菜单管理** - 动态菜单加载
- ✅ **工作台** - 首页仪表盘

### 已删除
- ❌ 其他 UI 版本（Element Plus, Naive UI 等）
- ❌ Demos 演示页面
- ❌ Analytics 分析页面
- ❌ 文档站点
- ❌ Playground

---

## 🛠️ 可用命令

### 开发
```bash
pnpm dev              # 启动前端
pnpm dev:antd         # 启动前端（同上）
pnpm dev:mock         # 启动 Mock 后端
```

### 构建
```bash
pnpm build            # 构建生产版本
pnpm build:analyze    # 构建并分析包大小
```

### 代码质量
```bash
pnpm lint             # 代码检查
pnpm format           # 代码格式化
pnpm check:type       # TypeScript 类型检查
```

### 其他
```bash
pnpm clean            # 清理构建文件
pnpm reinstall        # 重新安装依赖
```

---

## 📚 API 文档

详细的 API 文档请查看: [API_DOCUMENTATION.md](./API_DOCUMENTATION.md)

### 快速示例

#### 登录
```bash
curl -X POST http://localhost:5320/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"vben","password":"123456"}'
```

#### 获取用户列表
```bash
curl -X POST http://localhost:5320/api/user/list \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"page":1,"pageSize":10}'
```

---

## 🎨 技术栈

### 前端
- **Vue 3** - 渐进式 JavaScript 框架
- **Vite** - 下一代前端构建工具
- **TypeScript** - JavaScript 的超集
- **Ant Design Vue** - 企业级 UI 组件库
- **Vue Router** - 路由管理
- **Pinia** - 状态管理

### 后端
- **Nitro** - 服务端框架
- **H3** - HTTP 工具库
- **JWT** - Token 认证

---

## 👥 默认账号

| 用户名 | 密码 | 角色 | 首页 |
|--------|------|------|------|
| vben | 123456 | super | 工作台 |
| admin | 123456 | admin | 工作台 |
| jack | 123456 | user | 工作台 |

---

## 📝 菜单结构

```
├── 工作台 (/)
└── 系统管理 (/system)
    └── 用户管理 (/system/user)
```

---

## 🔧 环境要求

- **Node.js**: `^20.19.0 || ^22.18.0 || ^24.0.0`
- **pnpm**: `>=10.0.0`

---

## 📖 相关文档

- **Ant Design Vue**: https://antdv.com/
- **Vue 3**: https://vuejs.org/
- **Vite**: https://vitejs.dev/
- **Nitro**: https://nitro.unjs.io/

---

## 🎯 下一步开发建议

### 可以添加的功能
1. **角色管理** - 角色的 CRUD 操作
2. **部门管理** - 部门的 CRUD 操作
3. **菜单管理** - 菜单的 CRUD 操作
4. **操作日志** - 记录用户操作
5. **数据字典** - 系统配置管理
6. **文件管理** - 文件上传下载

### 代码示例
所有接口都遵循 RESTful 规范：
- **GET** - 查询
- **POST** - 创建/列表查询
- **PUT** - 更新
- **DELETE** - 删除

---

## 📞 问题排查

### 依赖安装失败？
```bash
pnpm clean
pnpm reinstall
```

### 端口被占用？
修改配置文件：
- 前端: `apps/web-antd/vite.config.ts`
- 后端: `apps/backend-mock/nitro.config.ts`

### 登录失败？
检查后端服务是否启动：`pnpm dev:mock`

---

**版本**: 5.7.0  
**最后更新**: 2026-05-02
