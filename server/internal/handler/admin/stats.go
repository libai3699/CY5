package admin

import (
	"time"

	"cy5vpn/server/internal/database"
	"cy5vpn/server/internal/handler"
	"cy5vpn/server/internal/model"

	"github.com/gin-gonic/gin"
)

const statsOnlineWindow = 2 * time.Minute

// GetStats 仪表盘数据概览
func GetStats(c *gin.Context) {
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	threeDaysAgo := now.AddDate(0, 0, -3)
	onlineCutoff := now.Add(-statsOnlineWindow)

	var todayNew, totalMembers, onlineMembers, loginWithin3Days int64
	var todayIncomeCents int64

	database.DB.Model(&model.User{}).Where("created_at >= ?", todayStart).Count(&todayNew)
	database.DB.Model(&model.User{}).Count(&totalMembers)
	database.DB.Model(&model.Device{}).
		Where("last_seen_at > ?", onlineCutoff).
		Distinct("user_id").
		Count(&onlineMembers)
	database.DB.Model(&model.User{}).
		Where("last_login_at >= ?", threeDaysAgo).
		Count(&loginWithin3Days)
	database.DB.Model(&model.PaymentOrder{}).
		Where("status = ? AND paid_at >= ?", "paid", todayStart).
		Select("COALESCE(SUM(amount_cents), 0)").
		Scan(&todayIncomeCents)

	handler.OK(c, gin.H{
		"today_new":           todayNew,
		"today_income_cents":  todayIncomeCents,
		"total_members":       totalMembers,
		"online_members":      onlineMembers,
		"login_within_3_days": loginWithin3Days,
	})
}
