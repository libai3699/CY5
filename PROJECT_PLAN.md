# CY VPN 完整项目技术方案 v2.0

> 版本：v2.1 | 日期：2026-05-01 | 状态：待审核

---

## 一、项目概述

构建一套完整的 VPN 服务系统：
- **Flutter 客户端**（Android APK）：用户 VPN App
- **Go 后端服务**：API 服务、用户管理、设备管理、订阅配置
- **Vue Admin 后台**：已有框架，接入业务管理功能

---

## 二、目录结构

```
/（根目录）
├── .git/                    ← 根 Git 仓库（统一管理三个项目）
├── .gitignore               ← 根 .gitignore（合并三个子项目规则）
├── admin/                   ← Vue 后台管理（已有）
├── flutter/                 ← Flutter 客户端（删除 flutter/.git）
├── server/                  ← Go 后端服务（新建）
└── PROJECT_PLAN.md
```

---

## 三、Git 管理方案

1. 根目录执行 `git init`
2. 删除 `flutter/.git`（历史提交不迁移，从现在开始统一管理）
3. `admin/` 已初始化，内容直接纳入根仓库
4. `server/` 新建后直接在根仓库管理
5. 根目录创建统一 `.gitignore`

---

## 四、前后端传输加解密方案

### 4.1 整体策略（四层防护）

| 层级 | 方案 | 覆盖范围 | 说明 |
|------|------|---------|------|
| 第一层：传输层 | HTTPS TLS 1.3 | 所有请求 | 链路加密，抓包看不到内容 |
| 第二层：Body 加密 | AES-256-GCM | 所有请求/响应 body | 即使 HTTPS 被中间人，body 仍是密文 |
| 第三层：认证层 | JWT HS256 | 需登录接口 | 身份验证，7天有效期 |
| 第四层：签名防重放 | HMAC-SHA256 | 设备/心跳接口 | 防刷接口，时间戳+nonce 防重放 |

---

### 4.2 AES-256-GCM 请求体加密（核心）

**所有接口的请求 body 和响应 body 都经过 AES-256-GCM 加密。**

#### 密钥派生方案

不直接使用固定 AES 密钥，而是用 **HKDF** 从主密钥派生，增加破解难度：

```
主密钥（APP_SECRET）：32字节随机字符串，写死在 Flutter + server/.env
派生密钥：HKDF-SHA256(APP_SECRET, salt="cy5vpn-aes-key-v1", length=32)
IV（每次请求随机）：12字节随机数，附在密文头部
```

#### 加密格式

```
加密后的 body（Base64）= Base64( IV[12字节] + CipherText + AuthTag[16字节] )
```

#### 请求流程

```
Flutter 发请求：
  1. 构造原始 JSON body
  2. 生成随机 12 字节 IV
  3. AES-256-GCM 加密 body → 得到密文+AuthTag
  4. Base64(IV + 密文 + AuthTag) 作为新 body
  5. 设置 Content-Type: application/octet-stream
  6. 发送

后端收到请求：
  1. 读取 body（Base64 字符串）
  2. Base64 解码 → 分离 IV（前12字节）+ 密文 + AuthTag（后16字节）
  3. AES-256-GCM 解密 → 得到原始 JSON
  4. 正常处理业务逻辑
  5. 响应 JSON 同样 AES-256-GCM 加密后返回

Flutter 收到响应：
  1. 同样解密响应 body
  2. 解析 JSON
```

#### 实现位置

```
后端：server/internal/middleware/crypto.go  ← Gin 中间件，自动加解密
Flutter：flutter/lib/core/network/crypto_interceptor.dart  ← Dio 拦截器，自动加解密
```

#### 安全性分析

| 攻击方式 | 防护效果 |
|---------|---------|
| 抓包（Charles/Fiddler） | ✅ 看到的是 Base64 密文，无法读取 |
| HTTPS 中间人攻击 | ✅ 即使 TLS 被破，body 仍是密文 |
| 重放攻击 | ✅ 每次 IV 随机，重放密文无效（GCM 认证失败） |
| APK 反编译获取密钥 | ⚠️ 可通过代码混淆（ProGuard/R8）降低风险 |
| 暴力破解 AES-256 | ✅ 理论上不可行（2^256 复杂度） |

---

### 4.3 JWT 认证方案

```
登录成功 → 后端签发 JWT
  payload: { user_id, device_id, exp(7天) }
  secret: 环境变量 JWT_SECRET（32字节以上随机字符串）

Flutter 请求头：
  Authorization: Bearer <token>

后端中间件：验证 token → 注入 user_id/device_id 到 Gin context
```

---

### 4.4 接口签名（防刷/防重放）

针对设备注册、心跳等**无需登录**的高频接口，额外加签名验证：

```
签名规则：
  timestamp = 当前 Unix 时间戳（秒）
  nonce     = 随机 8 位字符串
  sign      = HMAC-SHA256(device_id + ":" + timestamp + ":" + nonce, APP_SECRET)

请求头（在 AES 加密之外，放在 Header 里）：
  X-Device-Id: <androidId>
  X-Timestamp: <timestamp>
  X-Nonce:     <nonce>
  X-Sign:      <sign>

后端验证顺序：
  1. 先验签名（Header 层）
  2. 再解密 body（AES 层）
  3. 最后处理业务
```

---

### 4.5 密码存储

```
传输：密码明文 → AES 加密 body → HTTPS 传输（三重保护）
存储：后端 bcrypt(cost=12) 哈希，不存明文
```

---

### 4.6 Flutter 端密钥保护

```
1. APP_SECRET 字符串拆分存储（不连续存放，增加反编译难度）
2. 启用 ProGuard/R8 混淆（android/app/build.gradle 配置）
3. 密钥不打印日志，不存本地文件
4. 可选：使用 Flutter 的 --obfuscate 编译选项
```

---

## 五、设备唯一 ID 方案

### 获取方式

```dart
import 'package:device_info_plus/device_info_plus.dart';

final deviceInfo = DeviceInfoPlugin();
final androidInfo = await deviceInfo.androidInfo;
String deviceId = androidInfo.id; // ANDROID_ID
```

### 业务规则

- 用户下载 APK → 首次打开 → **必须注册账号** → 注册成功自动登录
- 注册时上报 `device_id`，绑定到该账号
- 一个 `device_id` 对应一个免费额度（45分钟），与账号无关
- 同一设备换账号登录，免费时长不重置
- 免费时长用完 → 必须购买套餐

---

## 六、数据库设计（MySQL：cy5_vpn @ 127.0.0.1）

### 设计原则

- 用户表和设备表**分开**：用户是账号维度，设备是硬件维度
- 订阅历史**保留**，users 表加冗余字段方便快速查询当前状态
- 管理员**不建表**，直接在数据库写死 1-2 条记录（用 users 表或单独 SQL 插入）
- 配置表专注于：订阅链接 + 联系方式

---

### 6.1 用户表 `users`

```sql
CREATE TABLE users (
  id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username            VARCHAR(64) NOT NULL UNIQUE COMMENT '用户名',
  password            VARCHAR(255) NOT NULL COMMENT 'bcrypt 哈希',
  phone               VARCHAR(20) COMMENT '手机号（可选）',
  status              TINYINT DEFAULT 1 COMMENT '1正常 0禁用',

  -- 设备关联
  device_id           VARCHAR(128) COMMENT '注册时绑定的 ANDROID_ID',
  free_used_seconds   INT DEFAULT 0 COMMENT '已用免费时长（秒）',
  free_limit_seconds  INT DEFAULT 2700 COMMENT '免费上限 45分钟=2700秒',

  -- 当前套餐冗余字段（方便快速查询，不用 JOIN）
  current_plan_id     INT UNSIGNED COMMENT '当前套餐 ID，NULL=无套餐',
  plan_expired_at     DATETIME COMMENT '套餐到期时间',
  traffic_used_bytes  BIGINT DEFAULT 0 COMMENT '当前套餐已用流量（字节）',
  traffic_limit_bytes BIGINT COMMENT '当前套餐流量上限，NULL=无限',

  last_login_at       DATETIME COMMENT '最后登录时间',
  created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_device_id (device_id),
  INDEX idx_plan_expired (plan_expired_at)
) COMMENT='用户表';
```

### 6.2 设备表 `devices`

设备表独立存在，记录每台设备的基本信息和登录历史，与用户表通过 `device_id` 关联。

```sql
CREATE TABLE devices (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(128) NOT NULL UNIQUE COMMENT 'ANDROID_ID',
  user_id       BIGINT UNSIGNED COMMENT '当前/最后登录的用户 ID',
  brand         VARCHAR(64) COMMENT '设备品牌，如 Xiaomi',
  model         VARCHAR(128) COMMENT '设备型号，如 Redmi Note 12',
  os_version    VARCHAR(32) COMMENT 'Android 版本，如 13',
  app_version   VARCHAR(32) COMMENT 'App 版本，如 1.0.0',
  last_ip       VARCHAR(64) COMMENT '最后登录 IP',
  last_seen_at  DATETIME COMMENT '最后活跃时间',
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_user_id (user_id)
) COMMENT='设备表';
```

> **为什么分开？**
> - 一个用户可能换手机（新设备），需要独立记录
> - 后台设备管理需要看到设备型号、IP、活跃时间等
> - 免费时长在 `users.free_used_seconds`（按账号），设备表只记录硬件信息

### 6.3 套餐表 `plans`

```sql
CREATE TABLE plans (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(64) NOT NULL COMMENT '套餐名称',
  price         DECIMAL(10,2) NOT NULL COMMENT '价格',
  traffic_gb    INT COMMENT '流量 GB，NULL=无限',
  duration_days INT DEFAULT 30 COMMENT '有效期（天）',
  sort_order    INT DEFAULT 0 COMMENT '排序',
  is_active     TINYINT DEFAULT 1 COMMENT '1上架 0下架',
  created_at    DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='套餐表';

-- 初始套餐数据
INSERT INTO plans (name, price, traffic_gb, duration_days, sort_order) VALUES
  ('基础版',  9.9,  15,   30, 1),
  ('标准版',  19.9, 50,   30, 2),
  ('高级版',  29.9, 100,  30, 3),
  ('无限版',  69.9, NULL, 30, 4);
```

### 6.4 订阅购买历史表 `order_records`

不叫 subscriptions，改叫订单记录，职责更清晰：记录每次购买历史。
当前套餐状态直接读 `users` 表的冗余字段，不需要每次 JOIN。

```sql
CREATE TABLE order_records (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL COMMENT '用户 ID',
  plan_id         INT UNSIGNED NOT NULL COMMENT '套餐 ID',
  plan_name       VARCHAR(64) NOT NULL COMMENT '套餐名称快照',
  plan_price      DECIMAL(10,2) NOT NULL COMMENT '购买时价格快照',
  traffic_gb      INT COMMENT '流量快照',
  duration_days   INT NOT NULL COMMENT '有效期快照',
  started_at      DATETIME NOT NULL COMMENT '生效时间',
  expired_at      DATETIME NOT NULL COMMENT '到期时间',
  pay_method      VARCHAR(32) COMMENT '支付方式（预留）',
  pay_trade_no    VARCHAR(128) COMMENT '第三方支付单号（预留）',
  remark          VARCHAR(255) COMMENT '备注（如：后台手动开通）',
  created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_user_id (user_id),
  INDEX idx_expired_at (expired_at)
) COMMENT='订单购买历史';
```

### 6.5 联系方式 & 配置表 `app_configs`

专注于：订阅链接 + 联系方式 + 下载链接 + App 配置。

```sql
CREATE TABLE app_configs (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  key_name    VARCHAR(128) NOT NULL UNIQUE COMMENT '配置键',
  value       TEXT NOT NULL DEFAULT '' COMMENT '配置值',
  label       VARCHAR(128) COMMENT '后台显示名称',
  sort_order  INT DEFAULT 0,
  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='App 配置表（订阅链接、联系方式、下载链接等）';

-- 初始数据
INSERT INTO app_configs (key_name, value, label, sort_order) VALUES
  -- VPN 订阅
  ('subscription_url',        '', 'VPN 订阅链接',           1),
  -- 联系方式
  ('contact_wechat',          '', '微信号',                 10),
  ('contact_telegram',        '', 'Telegram 链接',          11),
  ('contact_email',           '', '邮箱',                   12),
  ('contact_qq',              '', 'QQ 号',                  13),
  -- 下载链接（存云存储 URL）
  ('download_vpn_apk',        '', '9点9 VPN APK 下载链接',   20),
  ('download_acc_apk',        '', '9点9 加速器 APK 下载链接', 21),
  ('download_vpn_exe',        '', '9点9 VPN EXE 下载链接',   22),
  ('download_acc_exe',        '', '9点9 加速器 EXE 下载链接', 23),
  -- App 版本
  ('app_vpn_version',         '1.0.0', '9点9 VPN 最新版本',  30),
  ('app_acc_version',         '1.0.0', '9点9 加速器最新版本', 31);
```

### 6.6 公共通知表 `notices`

```sql
CREATE TABLE notices (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content     TEXT NOT NULL COMMENT '通知内容',
  type        TINYINT DEFAULT 1 COMMENT '1普通 2重要',
  is_active   TINYINT DEFAULT 1 COMMENT '1显示 0隐藏',
  sort_order  INT DEFAULT 0,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT='公共通知';
```

### 6.7 前台登录日志 `user_login_logs`

```sql
CREATE TABLE user_login_logs (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  device_id   VARCHAR(128),
  ip          VARCHAR(64),
  app_version VARCHAR(32),
  status      TINYINT DEFAULT 1 COMMENT '1成功 0失败',
  fail_reason VARCHAR(255),
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_user_id (user_id),
  INDEX idx_created_at (created_at)
) COMMENT='前台登录日志';
```

### 6.8 后台登录日志 `admin_login_logs`

```sql
CREATE TABLE admin_login_logs (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username    VARCHAR(64) NOT NULL COMMENT '登录的管理员用户名',
  ip          VARCHAR(64),
  user_agent  VARCHAR(512),
  status      TINYINT DEFAULT 1 COMMENT '1成功 0失败',
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_created_at (created_at)
) COMMENT='后台登录日志';
```

### 6.9 管理员（不建表，写死 SQL）

```sql
-- 后台管理员直接在应用启动时检查，不建表
-- server/internal/config/admin.go 中写死：
-- username: admin
-- password: bcrypt("your_password")
-- 或者在 server/.env 中配置：
-- ADMIN_USERNAME=admin
-- ADMIN_PASSWORD_HASH=$2a$12$xxxxx（bcrypt 哈希）
```

---

## 七、数据库表总览

| 表名 | 说明 | 是否必须 |
|------|------|---------|
| `users` | 用户账号 + 设备绑定 + 当前套餐冗余 | ✅ |
| `devices` | 设备硬件信息记录 | ✅ |
| `plans` | 套餐配置 | ✅ |
| `order_records` | 购买历史 | ✅ |
| `app_configs` | 订阅链接 + 联系方式 + App 配置 | ✅ |
| `notices` | 公共通知 | ✅ |
| `user_login_logs` | 前台登录日志 | ✅ |
| `admin_login_logs` | 后台登录日志 | ✅ |

共 **8 张表**，无管理员表（写死配置）。

---

## 七、安装包文件管理方案

### 7.1 文件清单

| 文件名 | 类型 | 说明 |
|--------|------|------|
| `9点9VPN.apk` | Android | VPN 客户端 |
| `9点9加速器.apk` | Android | 加速器客户端 |
| `9点9VPN.exe` | Windows | VPN 客户端 |
| `9点9加速器.exe` | Windows | 加速器客户端 |

### 7.2 存储方案：云对象存储（待定厂商）

云存储厂商**待定**，代码层面用统一接口封装，切换厂商只改配置：

```
支持的厂商（任选其一）：
  - 阿里云 OSS（推荐，国内速度快）
  - 腾讯云 COS
  - MinIO（自建，完全控制）

封装接口：
  server/internal/storage/storage.go  ← 统一 interface
  server/internal/storage/oss.go      ← 阿里云实现
  server/internal/storage/cos.go      ← 腾讯云实现
  server/internal/storage/minio.go    ← MinIO 实现
```

### 7.3 上传流程（后台操作）

```
后台管理员选择文件（APK/EXE）
  ↓
POST /api/admin/files/upload（multipart/form-data）
  ↓
后端接收文件 → 校验文件类型（只允许 .apk / .exe）
  ↓
上传到云存储 → 得到公开访问 URL
  ↓
自动更新 app_configs 对应的 key（如 download_vpn_apk）
  ↓
返回下载 URL 给后台展示
```

### 7.4 下载流程（用户/网页访问）

```
用户访问下载页（网页）
  ↓
GET /api/app/config → 获取 download_vpn_apk 等下载链接
  ↓
前端展示下载按钮，点击直接跳转云存储 URL 下载
  （云存储 URL 是公开的，不需要后端中转，节省带宽）
```

### 7.5 后台文件管理 API

```
POST   /api/admin/files/upload          上传安装包（替换对应配置）
GET    /api/admin/files                 查看当前4个文件的上传状态和链接
DELETE /api/admin/files/:key            删除某个文件（清空链接）
```

### 7.6 文件安全控制

```
1. 文件类型白名单：只允许 .apk / .exe，其他类型拒绝
2. 文件大小限制：单文件最大 500MB
3. 文件名重命名：上传时统一重命名为固定名称（防止路径遍历）
   如：cy5vpn_android_v1.0.0.apk
4. 下载链接：云存储公开 URL，不经过后端（节省服务器带宽）
5. 上传接口：需要后台 JWT 认证
```

### 7.7 后台管理菜单新增

```
├── 下载管理（新增）
│   ├── 安装包管理（上传/查看/删除 4个文件）
│   └── 下载统计（预留，云存储自带）
```

---

## 八、后端 Go 服务设计

### 8.1 技术栈

| 组件 | 选型 | 版本 |
|------|------|------|
| 语言 | Go | 1.22+ |
| Web 框架 | Gin | v1.9+ |
| ORM | GORM | v2 |
| 数据库驱动 | go-sql-driver/mysql | v1.7+ |
| JWT | golang-jwt/jwt | v5 |
| 密码哈希 | golang.org/x/crypto/bcrypt | - |
| **Body 加密** | **AES-256-GCM（标准库）** | - |
| **签名** | **HMAC-SHA256（标准库）** | - |
| 配置管理 | godotenv | v1.5+ |
| 日志 | uber-go/zap | v1.27+ |
| 跨域 | gin-contrib/cors | - |
| **云存储（阿里云）** | **aliyun-oss-go-sdk** | v3+ |
| **云存储（腾讯云）** | **tencentcloud-sdk-go** | - |
| **云存储（MinIO）** | **minio-go** | v7+ |

### 8.2 目录结构

```
server/
├── cmd/
│   └── main.go                  ← 入口，启动 HTTP 服务
├── internal/
│   ├── config/
│   │   ├── config.go            ← 读取 .env 配置
│   │   └── admin.go             ← 管理员账号（写死）
│   ├── database/
│   │   ├── db.go                ← GORM 连接初始化
│   │   └── migrate.go           ← 自动建表/迁移
│   ├── middleware/
│   │   ├── auth.go              ← JWT 验证中间件
│   │   ├── admin_auth.go        ← 后台 JWT 验证
│   │   ├── crypto.go            ← AES-256-GCM 请求/响应加解密（新增）
│   │   ├── cors.go              ← 跨域
│   │   ├── sign.go              ← 接口签名验证（设备接口）
│   │   └── logger.go            ← 请求日志
│   ├── model/
│   │   ├── user.go
│   │   ├── device.go
│   │   ├── plan.go
│   │   ├── order_record.go
│   │   ├── app_config.go
│   │   ├── notice.go
│   │   └── login_log.go
│   ├── storage/                 ← 云存储封装（新增）
│   │   ├── storage.go           ← 统一 interface
│   │   ├── oss.go               ← 阿里云 OSS 实现
│   │   ├── cos.go               ← 腾讯云 COS 实现
│   │   └── minio.go             ← MinIO 实现
│   ├── handler/
│   │   ├── app/                 ← Flutter 调用的接口
│   │   │   ├── auth.go          ← 注册、登录
│   │   │   ├── device.go        ← 设备注册、心跳
│   │   │   ├── config.go        ← 获取配置（订阅链接、联系方式、下载链接）
│   │   │   ├── notice.go        ← 获取通知
│   │   │   ├── plan.go          ← 获取套餐列表
│   │   │   └── user.go          ← 用户信息、订阅状态
│   │   └── admin/               ← 后台管理接口
│   │       ├── auth.go          ← 后台登录
│   │       ├── user.go          ← 用户管理
│   │       ├── device.go        ← 设备管理
│   │       ├── plan.go          ← 套餐管理
│   │       ├── order.go         ← 订单管理（手动开通）
│   │       ├── config.go        ← 配置管理
│   │       ├── notice.go        ← 通知管理
│   │       ├── file.go          ← 安装包上传/管理（新增）
│   │       ├── log.go           ← 日志查看
│   │       └── stats.go         ← 统计数据
│   └── router/
│       └── router.go            ← 路由注册
├── .env                         ← 环境变量
├── go.mod
└── go.sum
```

### 8.3 API 接口清单

#### 前台 API（Flutter 调用，前缀 `/api/app`）

```
# 无需登录
POST  /api/app/auth/register        注册（同时绑定 device_id）
POST  /api/app/auth/login           登录
GET   /api/app/config               获取配置（订阅链接、联系方式）
GET   /api/app/notices              获取通知列表
GET   /api/app/plans                获取套餐列表

# 需要签名（X-Sign 头）
POST  /api/app/device/register      设备注册/更新（上报设备信息）
POST  /api/app/device/heartbeat     VPN 使用心跳（累计免费时长）

# 需要 JWT
GET   /api/app/user/profile         用户信息 + 当前套餐状态
GET   /api/app/user/orders          购买历史
```

#### 后台 API（Admin 调用，前缀 `/api/admin`）

```
# 无需登录
POST  /api/admin/auth/login         后台登录

# 需要后台 JWT
GET   /api/admin/stats              数据概览

GET   /api/admin/users              用户列表（分页、搜索）
GET   /api/admin/users/:id          用户详情
PUT   /api/admin/users/:id          编辑用户（禁用/启用、重置免费时长）

GET   /api/admin/devices            设备列表
GET   /api/admin/devices/:id        设备详情

GET   /api/admin/plans              套餐列表
POST  /api/admin/plans              新增套餐
PUT   /api/admin/plans/:id          编辑套餐
DELETE /api/admin/plans/:id         删除套餐

GET   /api/admin/orders             订单列表
POST  /api/admin/orders             手动开通套餐（给用户）

GET   /api/admin/configs            配置列表
PUT   /api/admin/configs/:key       更新配置（订阅链接、联系方式等）

GET   /api/admin/notices            通知列表
POST  /api/admin/notices            新增通知
PUT   /api/admin/notices/:id        编辑通知
DELETE /api/admin/notices/:id       删除通知

GET   /api/admin/logs/user          前台登录日志
GET   /api/admin/logs/admin         后台登录日志
```

#### 文件管理 API（后台，需要后台 JWT）

```
POST   /api/admin/files/upload      上传安装包（multipart，替换对应配置链接）
GET    /api/admin/files             查看4个安装包当前状态和下载链接
DELETE /api/admin/files/:key        删除某个文件（清空对应配置链接）
```

---

## 九、Flutter 客户端改造

### 9.1 新增依赖

```yaml
dependencies:
  device_info_plus: ^10.1.0        # ANDROID_ID
  dio: ^5.4.0                      # HTTP 客户端
  shared_preferences: ^2.2.3       # 本地缓存（token、deviceId）
  flutter_secure_storage: ^9.0.0   # 安全存储 token
  provider: ^6.1.2                 # 状态管理
  crypto: ^3.0.3                   # HMAC-SHA256 签名
  pointycastle: ^3.7.4             # AES-256-GCM 加解密
```

### 9.2 新增目录结构

```
flutter/lib/
├── core/
│   ├── platform/            ← 已有（VPN 通道）
│   ├── network/
│   │   ├── api_client.dart          ← Dio 封装
│   │   ├── crypto_interceptor.dart  ← AES-256-GCM 自动加解密拦截器（新增）
│   │   └── auth_interceptor.dart    ← 自动加 JWT + 签名头
│   ├── storage/             ← token/deviceId 本地存储
│   └── device/              ← ANDROID_ID 获取 + 签名生成
├── features/
│   ├── auth/                ← 注册/登录页面 + 逻辑
│   ├── subscription/        ← 套餐页面 + 订阅状态
│   └── config/              ← 远程配置拉取（订阅链接、联系方式、下载链接）
└── pages/
    ├── vpn_home/            ← 已有，改造（接入远程配置）
    ├── login/               ← 新增
    ├── register/            ← 新增
    └── plans/               ← 新增：套餐购买页
```

### 9.3 启动流程

```
App 启动
  ↓
获取 ANDROID_ID
  ↓
POST /api/app/device/register（带签名）→ 上报设备信息
  ↓
检查本地 token → 有效则自动登录，无效则跳转注册/登录页
  ↓
登录成功后：
  GET /api/app/config → 获取订阅链接
  GET /api/app/notices → 获取通知
  GET /api/app/user/profile → 获取用户信息 + 套餐状态
  ↓
进入主页
  ↓
Flutter 用订阅链接直接请求订阅源 → 本地解析节点 → 展示
```

### 9.4 节点名称解析（前端处理）

```dart
// 原始：🇭🇰 香港01 | 高速专线 | 剩余流量...
// 目标：🇭🇰 香港01

String parseNodeDisplayName(String rawName) {
  final parts = rawName.split('|');
  return parts.first.trim();
}
```

### 9.5 免费时长控制

```
连接 VPN → 开始本地计时
  ↓
每 60 秒 POST /api/app/device/heartbeat（带签名 + JWT）
  ↓
后端累加 users.free_used_seconds
  ↓
后端返回 { remaining_seconds: xxx }
  ↓
remaining_seconds <= 0 → 前端断开 VPN + 弹出套餐购买页
```

---

## 十、后台管理功能（Admin Vue）

基于现有 `admin/` 框架新增菜单：

```
├── 仪表盘（用户数、设备数、活跃套餐数、今日新增）
├── 用户管理（列表、详情、禁用、重置免费时长）
├── 设备管理（列表、详情、关联用户）
├── 套餐管理（增删改查、上下架）
├── 订单管理（列表、手动开通）
├── 内容管理
│   ├── 公共通知（增删改查、显示/隐藏）
│   └── 系统配置（订阅链接、联系方式、APK 下载地址）
└── 日志管理
    ├── 前台登录日志
    └── 后台登录日志
```

---

## 十一、实施阶段

### Phase 1：基础设施（1-2天）
- [ ] 根目录 Git 初始化，删除 flutter/.git
- [ ] Go 项目初始化（server/）
- [ ] 数据库建表（8张表）
- [ ] Go 基础框架（Gin + GORM + JWT + 签名中间件）

### Phase 2：核心 API（3-4天）
- [ ] 用户注册/登录
- [ ] 设备注册/心跳
- [ ] 配置/通知/套餐接口
- [ ] 用户信息/订单接口
- [ ] 后台登录 + 管理接口

### Phase 3：Flutter 改造（3-4天）
- [ ] 接入 device_info_plus
- [ ] 网络层封装（Dio + 签名 + JWT）
- [ ] 注册/登录页面
- [ ] 主页接入远程配置（订阅链接）
- [ ] 免费时长心跳 + UI 展示
- [ ] 套餐页面

### Phase 4：后台管理（3-4天）
- [ ] Admin 接入后端 API
- [ ] 各管理页面开发

### Phase 5：联调测试（2天）
- [ ] 前后端联调
- [ ] 签名验证测试
- [ ] 免费时长边界测试

---

## 十二、环境配置

### server/.env

```env
# 数据库
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root
DB_NAME=cy5_vpn

# JWT
JWT_SECRET=（32字节以上随机字符串，自行生成）
ADMIN_JWT_SECRET=（32字节以上随机字符串，自行生成）

# 管理员（不建表，写死）
ADMIN_USERNAME=admin
ADMIN_PASSWORD_HASH=（用 bcrypt 工具生成，对应你的管理员密码）

# AES + 签名共用密钥
APP_SECRET=（32字节随机字符串，Flutter 和 server 保持一致）

# 服务
SERVER_PORT=8080
GIN_MODE=release

# 云存储（三选一，未决定前留空）
STORAGE_PROVIDER=oss          # oss / cos / minio

# 阿里云 OSS（选 oss 时填）
OSS_ENDPOINT=
OSS_ACCESS_KEY_ID=
OSS_ACCESS_KEY_SECRET=
OSS_BUCKET=

# 腾讯云 COS（选 cos 时填）
COS_REGION=
COS_SECRET_ID=
COS_SECRET_KEY=
COS_BUCKET=

# MinIO（选 minio 时填）
MINIO_ENDPOINT=
MINIO_ACCESS_KEY=
MINIO_SECRET_KEY=
MINIO_BUCKET=
MINIO_USE_SSL=false
```

---

*v2.1 已更新：AES-256-GCM 全量加密、文件管理方案、MySQL 账号配置。请确认后开始实施。*
