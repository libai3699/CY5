package router

import (
	"cy5vpn/server/internal/handler/admin"
	"cy5vpn/server/internal/handler/app"
	"cy5vpn/server/internal/middleware"
	"cy5vpn/server/internal/ws"

	"github.com/gin-gonic/gin"
)

func Setup(r *gin.Engine) {
	// 全局中间件
	r.Use(middleware.CORS())
	r.Use(middleware.Logger())
	r.Static("/uploads", "./uploads")

	publicGroup := r.Group("/api/public")
	{
		publicGroup.GET("/config", app.GetPublicConfig)
		publicGroup.GET("/status", app.GetPublicAppStatus)
		publicGroup.GET("/lines/default", app.GetDefaultLine)
		publicGroup.GET("/notices", app.GetNotices)
		publicGroup.GET("/plans", app.GetPlans)
		publicGroup.GET("/quote", app.GetRandomQuote)
		publicGroup.GET("/payment-configs", app.GetPaymentConfigs)
		publicGroup.GET("/contact", app.GetContactConfig)
		publicGroup.GET("/user/notices", middleware.AuthRequired(), app.GetUserNotices)
		publicGroup.GET("/user/status", middleware.AuthRequired(), app.GetUserStatus)
		publicGroup.POST("/user/heartbeat", middleware.AuthRequired(), app.UserHeartbeat)
		publicGroup.GET("/user/devices", middleware.AuthRequired(), app.ListLoginDevices)
		publicGroup.DELETE("/user/devices/:id", middleware.AuthRequired(), app.RemoveLoginDevice)
		publicGroup.POST("/user/logout", middleware.AuthRequired(), app.LogoutCurrentDevice)
		publicGroup.GET("/ws/notices", ws.Notices.ServeNoticeSocket)
		publicGroup.POST("/device/register", app.DeviceRegister)
		publicGroup.POST("/auth/register", app.Register)
		publicGroup.POST("/auth/login", app.Login)
	}

	// ── 前台 API（Flutter 调用）──────────────────────────────────
	appGroup := r.Group("/api/app")
	appGroup.Use(middleware.CryptoMiddleware()) // 所有前台接口加解密
	{
		// 无需登录
		appGroup.POST("/auth/register", app.Register)
		appGroup.POST("/auth/login", app.Login)
		appGroup.GET("/config", app.GetConfig)
		appGroup.GET("/notices", app.GetNotices)
		appGroup.GET("/plans", app.GetPlans)
		appGroup.GET("/quote", app.GetRandomQuote)
		appGroup.GET("/payment-configs", app.GetPaymentConfigs)

		// 需要签名（设备接口）
		deviceGroup := appGroup.Group("/device")
		deviceGroup.Use(middleware.SignRequired())
		{
			deviceGroup.POST("/register", app.DeviceRegister)
			deviceGroup.POST("/heartbeat", middleware.AuthRequired(), app.DeviceHeartbeat)
		}

		// 需要 JWT
		userGroup := appGroup.Group("/user")
		userGroup.Use(middleware.AuthRequired())
		{
			userGroup.GET("/profile", app.GetProfile)
			userGroup.GET("/orders", app.GetOrders)
			userGroup.GET("/line", app.GetUserLine)
			userGroup.GET("/notices", app.GetUserNotices)
			userGroup.POST("/notices/:id/read", app.MarkNoticeRead)
			userGroup.POST("/notices/read-all", app.MarkAllNoticesRead)
		}
	}

	// ── 后台 API（Admin 调用）────────────────────────────────────
	adminGroup := r.Group("/api/admin")
	{
		// 登录不加密（Admin 用 HTTPS 即可）
		adminGroup.POST("/auth/login", admin.Login)
		adminGroup.POST("/auth/logout", admin.Logout)

		// 需要后台 JWT 的接口
		authGroup := adminGroup.Group("")
		authGroup.Use(middleware.AdminAuthRequired())
		{
			authGroup.GET("/auth/codes", admin.AccessCodes)
			authGroup.GET("/user/info", admin.UserInfo)
			authGroup.GET("/stats", admin.GetStats)

			// 用户管理
			authGroup.GET("/users", admin.ListUsers)
			authGroup.POST("/users", admin.CreateUser)
			authGroup.GET("/users/:id", admin.GetUser)
			authGroup.PUT("/users/:id", admin.UpdateUser)
			authGroup.DELETE("/users/:id", admin.DeleteUser)
			authGroup.POST("/users/:id/add-duration", admin.AddUserDuration)
			authGroup.GET("/duration-logs", admin.ListDurationLogs)

			// 设备管理
			authGroup.GET("/devices", admin.ListDevices)
			authGroup.GET("/devices/:id", admin.GetDevice)

			// 套餐管理
			authGroup.GET("/plans", admin.ListPlans)
			authGroup.POST("/plans", admin.CreatePlan)
			authGroup.PUT("/plans/:id", admin.UpdatePlan)
			authGroup.DELETE("/plans/:id", admin.DeletePlan)

			// 订单管理
			authGroup.GET("/orders", admin.ListOrders)
			authGroup.POST("/orders", admin.CreateOrder)

			// 配置管理
			authGroup.GET("/configs", admin.ListConfigs)
			authGroup.POST("/configs", admin.CreateConfig)
			authGroup.PUT("/configs/:key", admin.UpdateConfig)

			// 线路管理
			authGroup.GET("/lines", admin.ListLines)
			authGroup.POST("/lines", admin.CreateLine)
			authGroup.PUT("/lines/:id", admin.UpdateLine)
			authGroup.DELETE("/lines/:id", admin.DeleteLine)
			authGroup.POST("/users/assign-line", admin.AssignUserLine)

			// 通知管理
			authGroup.GET("/notices", admin.ListNotices)
			authGroup.POST("/notices", admin.CreateNotice)
			authGroup.PUT("/notices/:id", admin.UpdateNotice)
			authGroup.DELETE("/notices/:id", admin.DeleteNotice)

			// 文件管理
			authGroup.GET("/files", admin.ListFiles)
			authGroup.POST("/files/upload", admin.UploadFile)
			authGroup.DELETE("/files/:key", admin.DeleteFile)

			// 日志
			authGroup.GET("/logs/user", admin.ListUserLogs)
			authGroup.GET("/logs/admin", admin.ListAdminLogs)

			// 精选语录管理
			authGroup.GET("/quotes", admin.ListQuotes)
			authGroup.POST("/quotes", admin.CreateQuote)
			authGroup.PUT("/quotes/:id", admin.UpdateQuote)
			authGroup.DELETE("/quotes/:id", admin.DeleteQuote)

			// 支付配置管理
			authGroup.GET("/payment-configs", admin.ListPaymentConfigs)
			authGroup.POST("/payment-configs", admin.CreatePaymentConfig)
			authGroup.PUT("/payment-configs/:id", admin.UpdatePaymentConfig)
			authGroup.DELETE("/payment-configs/:id", admin.DeletePaymentConfig)
		}
	}
}
