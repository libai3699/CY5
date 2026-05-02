package app

import (
	"strconv"
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
		"user":           safeUser(user),
		"has_plan":       hasPlan,
		"free_remaining": remaining,
	})
}

func GetUserStatus(c *gin.Context) {
	userID := c.GetUint64("user_id")

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	hasPlan := user.CurrentPlanID != nil &&
		user.PlanExpiredAt != nil &&
		user.PlanExpiredAt.After(time.Now())

	remaining := user.FreeLimitSeconds - user.FreeUsedSeconds
	if remaining < 0 {
		remaining = 0
	}

	planLevel := "免费体验"
	remainingSeconds := remaining
	if hasPlan {
		planLevel = "付费套餐"
		remainingSeconds = int(time.Until(*user.PlanExpiredAt).Seconds())
	}

	trafficRemaining := "不限流量"
	if user.TrafficLimitBytes != nil {
		left := *user.TrafficLimitBytes - user.TrafficUsedBytes
		if left < 0 {
			left = 0
		}
		trafficRemaining = formatGB(left)
	}

	handler.OK(c, gin.H{
		"plan_level":          planLevel,
		"remaining_seconds":   remainingSeconds,
		"remaining_time_text": formatRemainingTime(remainingSeconds),
		"traffic_remaining":   trafficRemaining,
		"server_time":         time.Now().Unix(),
	})
}

type userHeartbeatReq struct {
	Seconds int `json:"seconds"`
}

func UserHeartbeat(c *gin.Context) {
	userID := c.GetUint64("user_id")
	var req userHeartbeatReq
	_ = c.ShouldBindJSON(&req)

	seconds := req.Seconds
	if seconds <= 0 {
		seconds = 60
	}
	if seconds > 65 {
		seconds = 65
	}

	var user model.User
	if err := database.DB.First(&user, userID).Error; err != nil {
		handler.Fail(c, 404, "用户不存在")
		return
	}

	hasPlan := user.CurrentPlanID != nil &&
		user.PlanExpiredAt != nil &&
		user.PlanExpiredAt.After(time.Now())
	if !hasPlan {
		used := user.FreeUsedSeconds + seconds
		if used > user.FreeLimitSeconds {
			used = user.FreeLimitSeconds
		}
		database.DB.Model(&user).Update("free_used_seconds", used)
		user.FreeUsedSeconds = used
	}

	remaining := user.FreeLimitSeconds - user.FreeUsedSeconds
	if remaining < 0 {
		remaining = 0
	}
	if hasPlan {
		remaining = int(time.Until(*user.PlanExpiredAt).Seconds())
	}

	handler.OK(c, gin.H{
		"has_plan":            hasPlan,
		"remaining_seconds":   remaining,
		"remaining_time_text": formatRemainingTime(remaining),
	})
}

func formatGB(bytes int64) string {
	gb := float64(bytes) / 1024 / 1024 / 1024
	return strconv.FormatFloat(gb, 'f', 2, 64) + " GB"
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
