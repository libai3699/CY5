package router

import (
	"cy5vpn/server/internal/handler/admin"
	"cy5vpn/server/internal/handler/app"
	"cy5vpn/server/internal/middleware"
	"cy5vpn/server/internal/ws"
	"time"

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
		publicGroup.GET("/lines/default", app.GetPublicDefaultLine)
		publicGroup.GET("/notices", app.GetNotices)
		publicGroup.GET("/plans", app.GetPlans)
		publicGroup.GET("/quote", app.GetRandomQuote)
		publicGroup.GET("/payment-configs", app.GetPaymentConfigs)
		publicGroup.POST("/payment/orders", middleware.IPRateLimit("payment_order_create", 10, time.Minute), middleware.AuthRequired(), app.CreatePaymentOrder)
		publicGroup.GET("/payment/orders/:order_no", middleware.AuthRequired(), app.GetPaymentOrder)
		publicGroup.GET("/payment/checkout/:order_no", app.EPayCheckout)
		publicGroup.GET("/payment/notify", app.EPayNotify)
		publicGroup.POST("/payment/notify", app.EPayNotify)
		publicGroup.GET("/payment/return", app.EPayReturn)
		publicGroup.GET("/contact", app.GetContactConfig)
		publicGroup.GET("/user/notices", middleware.AuthRequired(), app.GetUserNotices)
		publicGroup.GET("/user/status", middleware.AuthRequired(), app.GetUserStatus)
		publicGroup.POST("/user/heartbeat", middleware.IPRateLimit("public_user_heartbeat", 30, time.Minute), middleware.AuthRequired(), app.UserHeartbeat)
		publicGroup.GET("/user/devices", middleware.AuthRequired(), app.ListLoginDevices)
		publicGroup.DELETE("/user/devices/:id", middleware.AuthRequired(), app.RemoveLoginDevice)
		publicGroup.POST("/user/logout", middleware.AuthRequired(), app.LogoutCurrentDevice)
		publicGroup.GET("/ws/notices", ws.Notices.ServeNoticeSocket)
		publicGroup.POST("/device/register", middleware.IPRateLimit("public_device_register", 20, time.Minute), app.DeviceRegister)
		publicGroup.POST("/auth/register", middleware.IPRateLimit("public_auth_register", 10, time.Minute), app.Register)
		publicGroup.POST("/auth/login", middleware.IPRateLimit("public_auth_login", 10, time.Minute), app.Login)
		publicGroup.POST("/track", middleware.IPRateLimit("public_track", 60, time.Minute), app.TrackEvent)
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
		adminGroup.GET("/auth/captcha", admin.Captcha)
		adminGroup.POST("/auth/login", middleware.IPRateLimit("admin_auth_login", 5, time.Minute), admin.Login)
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
			authGroup.POST("/users", middleware.AdminRequireRole("super_admin"), admin.CreateUser)
			authGroup.GET("/users/:id", admin.GetUser)
			authGroup.PUT("/users/:id", middleware.AdminRequireRole("super_admin"), admin.UpdateUser)
			authGroup.DELETE("/users/:id", middleware.AdminRequireRole("super_admin"), admin.DeleteUser)
			authGroup.POST("/users/:id/add-duration", middleware.AdminRequireRole("super_admin"), admin.AddUserDuration)
			authGroup.GET("/duration-logs", admin.ListDurationLogs)

			// 设备管理
			authGroup.GET("/devices", admin.ListDevices)
			authGroup.GET("/devices/:id", admin.GetDevice)

			// 套餐管理
			authGroup.GET("/plans", admin.ListPlans)
			authGroup.POST("/plans", middleware.AdminRequireRole("super_admin"), admin.CreatePlan)
			authGroup.PUT("/plans/:id", middleware.AdminRequireRole("super_admin"), admin.UpdatePlan)
			authGroup.DELETE("/plans/:id", middleware.AdminRequireRole("super_admin"), admin.DeletePlan)

			// 订单管理
			authGroup.GET("/orders", admin.ListOrders)
			authGroup.POST("/orders", middleware.AdminRequireRole("super_admin"), admin.CreateOrder)

			// 配置管理
			authGroup.GET("/configs", admin.ListConfigs)
			authGroup.POST("/configs", middleware.AdminRequireRole("super_admin"), admin.CreateConfig)
			authGroup.PUT("/configs/:key", middleware.AdminRequireRole("super_admin"), admin.UpdateConfig)

			// 线路管理
			authGroup.GET("/lines", admin.ListLines)
			authGroup.POST("/lines", middleware.AdminRequireRole("super_admin"), admin.CreateLine)
			authGroup.PUT("/lines/:id", middleware.AdminRequireRole("super_admin"), admin.UpdateLine)
			authGroup.DELETE("/lines/:id", middleware.AdminRequireRole("super_admin"), admin.DeleteLine)
			authGroup.POST("/users/assign-line", middleware.AdminRequireRole("super_admin"), admin.AssignUserLine)

			// 通知管理
			authGroup.GET("/notices", admin.ListNotices)
			authGroup.POST("/notices", middleware.AdminRequireRole("super_admin"), admin.CreateNotice)
			authGroup.PUT("/notices/:id", middleware.AdminRequireRole("super_admin"), admin.UpdateNotice)
			authGroup.DELETE("/notices/:id", middleware.AdminRequireRole("super_admin"), admin.DeleteNotice)

			// 文件管理
			authGroup.GET("/files", admin.ListFiles)
			authGroup.POST("/files/upload", middleware.AdminRequireRole("super_admin"), admin.UploadFile)
			authGroup.POST("/files/payment-image", middleware.AdminRequireRole("super_admin"), admin.UploadPaymentImage)
			authGroup.DELETE("/files/:key", middleware.AdminRequireRole("super_admin"), admin.DeleteFile)

			// 埋点统计
			authGroup.GET("/events", admin.ListPageEvents)
			authGroup.GET("/events/stats", admin.PageEventStats)
			authGroup.GET("/logs/user", admin.ListUserLogs)
			authGroup.GET("/logs/admin", admin.ListAdminLogs)

			// 精选语录管理
			authGroup.GET("/quotes", admin.ListQuotes)
			authGroup.POST("/quotes", middleware.AdminRequireRole("super_admin"), admin.CreateQuote)
			authGroup.PUT("/quotes/:id", middleware.AdminRequireRole("super_admin"), admin.UpdateQuote)
			authGroup.DELETE("/quotes/:id", middleware.AdminRequireRole("super_admin"), admin.DeleteQuote)

			// 支付配置管理
			authGroup.GET("/payment-configs", admin.ListPaymentConfigs)
			authGroup.POST("/payment-configs", middleware.AdminRequireRole("super_admin"), admin.CreatePaymentConfig)
			authGroup.PUT("/payment-configs/:id", middleware.AdminRequireRole("super_admin"), admin.UpdatePaymentConfig)
			authGroup.DELETE("/payment-configs/:id", middleware.AdminRequireRole("super_admin"), admin.DeletePaymentConfig)
		}
	}
}
