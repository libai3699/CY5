package main

import (
	"log"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/router"
	"cy5vpn/server/internal/service"

	"github.com/gin-gonic/gin"
)

func main() {
	// 1. 加载配置
	config.Load()

	// 2. 设置 Gin 模式
	gin.SetMode(config.App.GinMode)

	// 3. 连接数据库
	database.Init()

	// 4. 自动建表 + 初始数据
	database.Migrate()

	// 5. 启动长期未登录用户自动清理（默认 45 天）
	service.StartInactiveUserCleanup(database.DB, service.InactiveUserDaysFromEnv(config.GetEnv))

	// 6. 注册路由
	r := gin.New()
	r.SetTrustedProxies([]string{"127.0.0.1"})
	router.Setup(r)

	// 7. 启动服务
	addr := ":" + config.App.ServerPort
	log.Printf("[server] 启动在 http://localhost%s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("[server] 启动失败: %v", err)
	}
}
