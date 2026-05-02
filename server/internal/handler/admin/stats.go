package admin

import (
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetStats 数据概览
func GetStats(c *gin.Context) {
	var totalUsers, totalDevices, activeOrders, todayNew int64

	database.DB.Model(&model.User{}).Count(&totalUsers)
	database.DB.Model(&model.Device{}).Count(&totalDevices)
	database.DB.Model(&model.User{}).
		Where("current_plan_id IS NOT NULL AND plan_expired_at > ?", time.Now()).
		Count(&activeOrders)

	today := time.Now().Truncate(24 * time.Hour)
	database.DB.Model(&model.User{}).Where("created_at >= ?", today).Count(&todayNew)

	handler.OK(c, gin.H{
		"total_users":   totalUsers,
		"total_devices": totalDevices,
		"active_orders": activeOrders,
		"today_new":     todayNew,
	})
}
