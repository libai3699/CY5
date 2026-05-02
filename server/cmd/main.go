package main

import (
	"log"

	"cy5vpn/server/internal/config"
	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/router"

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

	// 5. 注册路由
	r := gin.New()
	router.Setup(r)

	// 6. 启动服务
	addr := ":" + config.App.ServerPort
	log.Printf("[server] 启动在 http://localhost%s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatalf("[server] 启动失败: %v", err)
	}
}
