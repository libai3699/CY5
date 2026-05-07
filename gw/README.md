# 9.9 VPN React 官网

这是一个新的独立 React 官网目录，没有修改旧的 `guangwang` 目录。

## 结构

- `src/`: React 前端界面、动画、解密逻辑
- `server/index.mjs`: 线上服务端，拉取后端配置并加密返回 `/api/site-config`
- `1.sh`: 宝塔服务器部署脚本

## 环境变量

服务端：

```bash
APP_SECRET=<same-random-secret-as-backend>
PORT=3000
```

前端构建时：

```bash
VITE_APP_SECRET=<same-random-secret-as-backend>
VITE_SITE_CONFIG_ENDPOINT=/api/site-config
```

`APP_SECRET` 和 `VITE_APP_SECRET` 必须一致，否则前端无法解密。

## 部署

把本目录内容上传到宝塔站点目录后执行：

```bash
bash 1.sh
```
