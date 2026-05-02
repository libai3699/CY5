package app

import (
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

// GetProfile 获取用户信息 + 当前套餐状态
func GetProfile(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	// 检查套餐是否过期
	hasPlan := user.CurrentPlanID != nil &&
		user.PlanExpiredAt != nil &&
		user.PlanExpiredAt.After(time.Now())

	remaining := user.FreeLimitSeconds - user.FreeUsedSeconds
	if remaining < 0 {
		remaining = 0
	}

	handler.OK(c, gin.H{
		"user":               safeUser(user),
		"has_plan":           hasPlan,
		"free_remaining":     remaining,
	})
}

// GetOrders 获取购买历史
func GetOrders(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var orders []model.OrderRecord
	database.DB.Where("user_id = ?", userID).
		Order("created_at desc").
		Limit(50).
		Find(&orders)

	handler.OK(c, orders)
}
