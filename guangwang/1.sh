#!/bin/bash

echo "🚀 开始部署新版本..."

# 进入项目目录       sed -i 's/\r$//' 1.sh
cd /www/wwwroot/vpn.wangwei.tech

# 1. 检查关键文件是否已更新
echo "🔍 检查代码更新..."
if grep -q "// import { decryptSiteConfig }" components/DownloadSection.tsx; then
  echo "✅ DownloadSection 已注释 import"
else
  echo "❌ 警告：DownloadSection 的 import 可能未注释"
  echo "当前内容："
  head -10 components/DownloadSection.tsx
fi

# 2. 停掉旧进程
echo "🧹 清理旧 PM2 进程..."
pm2 delete web 2>/dev/null

# 3. 强制删除旧的构建文件和缓存
echo "🗑️ 删除旧的构建文件..."
rm -rf .next
rm -rf node_modules/.cache
echo "✅ 已删除 .next 和缓存"

# 4. 安装依赖
echo "📦 安装依赖..."
npm install

# 5. 重新构建
echo "🏗️ 构建项目..."
npm run build

# 6. 检查构建结果
if [ -d ".next" ]; then
  echo "✅ 构建成功，.next 目录已生成"
  echo "新生成的文件："
  ls -lh .next/static/chunks/app/*.js 2>/dev/null | head -3
else
  echo "❌ 构建失败，.next 目录不存在"
  exit 1
fi

# 7. 启动新版本
echo "🚀 启动服务..."
pm2 start npm --name web -- run start

# 8. 保存 PM2
pm2 save

echo ""
echo "✅ 部署完成！"
echo ""
echo "⚠️  重要提示："
echo "1. 新的 JS 文件已生成，文件名会变化"
echo "2. 必须清除浏览器缓存："
echo "   - 按 Ctrl+Shift+Delete 清除缓存"
echo "   - 或使用无痕模式测试"
echo "   - 或在开发者工具勾选 'Disable cache' 后刷新"
echo ""
pm2 list